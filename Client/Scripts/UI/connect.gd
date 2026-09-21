extends Control
## Клиент: логин + отправка ввода по бинарному протоколу.

enum State { IDLE, CONNECTING, WAITING_WELCOME, IN_GAME }

@onready var nick_edit: LineEdit       = $VBoxContainer/HBoxContainer/LineEdit
@onready var connect_button: Button    = $VBoxContainer/Button
@onready var status_label: Label       = $VBoxContainer/StatusLabel
@onready var input_label: Label        = $VBoxContainer/Label

var _udp: PacketPeerUDP = PacketPeerUDP.new()
var _state: State = State.IDLE 

# Handshake
var _session_id: int = 0
var _net_id: int = 0
var _tick_rate: int = 20
var _map_min: Vector2 = Vector2.ZERO
var _map_max: Vector2 = Vector2.ZERO

# Seq и надёжная отправка HELLO
var _next_seq: int = 1
var _hello_payload: PackedByteArray = PackedByteArray()
var _hello_seq: int = 0
var _hello_last_send_ms: int = 0
var _hello_retries: int = 0
var _hello_acked: bool = false

# Ввод
var _input_seq: int = 1
var _input_accum: float = 0.0

# Ping
var _ping_accum: float = 0.0
var _rtt_ms: int = 0

const PING_INTERVAL: float = 1.0
const SPAWN_X: float = 200.0
const SPAWN_Y: float = 200.0
var _reliable_recv: ReliableChannel = ReliableChannel.new()

func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)


func _process(delta: float) -> void:
	if _state == State.IDLE:
		return

	# 1. Приём пакетов
	while _udp.get_available_packet_count() > 0:
		var raw: PackedByteArray = _udp.get_packet()
		if raw.is_empty():
			break
		var buf := StreamPeerBuffer.new()
		buf.data_array = raw
		_handle_packet(raw, buf)

	# 2. Ретрансмит HELLO, пока не получили WELCOME или ACK
	if _state == State.WAITING_WELCOME and not _hello_acked:
		var now := Time.get_ticks_msec()
		if now - _hello_last_send_ms >= NetConfig.RELIABLE_TIMEOUT_MS:
			if _hello_retries >= NetConfig.RELIABLE_MAX_RETRIES:
				_set_status("Server not responding")
				_state = State.IDLE
				_udp.close()
				return
			_hello_retries += 1
			_hello_last_send_ms = now
			_udp.put_packet(_hello_payload)
			NetLog.d("client", "HELLO retransmit #%d" % _hello_retries)

	# 3. Отправка ввода (30 Гц)
	if _state == State.IN_GAME:
		_input_accum += delta
		if _input_accum >= NetConfig.CLIENT_INPUT_DT:
			_input_accum -= NetConfig.CLIENT_INPUT_DT
			_send_input()

		# 4. Пинг раз в секунду
		_ping_accum += delta
		if _ping_accum >= PING_INTERVAL:
			_ping_accum = 0.0
			_send_ping()


func _on_connect_pressed() -> void:
	if _state != State.IDLE:
		return
	var nick := nick_edit.text.strip_edges()
	if nick.is_empty():
		_set_status("Enter a nickname")
		return

	var err := _udp.connect_to_host(NetConfig.SERVER_HOST, NetConfig.SERVER_PORT)
	if err != OK:
		_set_status("Connect failed: %d" % err)
		return

	_state = State.CONNECTING
	connect_button.disabled = true
	_set_status("Connecting…")

	# Формируем MSG_HELLO
	var body := StreamPeerBuffer.new()
	NetProtocol.write_string(body, nick)
	body.put_float(SPAWN_X)
	body.put_float(SPAWN_Y)

	var seq := _next_seq
	_next_seq = (_next_seq + 1) & 0xFFFF
	if _next_seq == 0:
		_next_seq = 1

	var full := StreamPeerBuffer.new()
	NetProtocol.write_header(full, NetProtocol.MSG_HELLO, seq)
	full.put_data(body.data_array)
	_hello_payload = full.data_array
	_hello_seq = seq
	_hello_last_send_ms = Time.get_ticks_msec()
	_hello_retries = 0
	_hello_acked = false

	_udp.put_packet(_hello_payload)
	NetLog.d("client", "HELLO seq=%d nick=%s" % [seq, nick])

	_state = State.WAITING_WELCOME
	_set_status("Waiting for welcome…")

func _send_ack(acked_seq: int) -> void:
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_ACK, acked_seq)
	_udp.put_packet(buf.data_array)
	NetLog.d("client", "ACK seq=%d" % acked_seq)

func _handle_packet(raw: PackedByteArray, buf: StreamPeerBuffer) -> void:
	var header := NetProtocol.read_header(buf)
	match header.msg_type:
		NetProtocol.MSG_WELCOME:
			# Дедупликация: обрабатываем только первое получение
			if _reliable_recv.on_receive(header.seq, raw):
				_on_welcome(buf)
			# ACK отправляем ВСЕГДА — даже для дубликатов.
			# Если наш ACK потерялся, а сервер повторил, мы должны ответить снова,
			# иначе сервер будет ретранслировать до give up.
			_send_ack(header.seq)

		NetProtocol.MSG_PONG:
			_on_pong(buf)

		NetProtocol.MSG_ACK:
			_on_ack(header.seq)

		_:
			NetLog.d("client", "unhandled msg_type=%d" % header.msg_type)


func _on_welcome(buf: StreamPeerBuffer) -> void:
	var session_id := buf.get_u32()
	var net_id     := buf.get_u16()
	var tick_rate  := buf.get_u8()
	var map_min    := Vector2(buf.get_float(), buf.get_float())
	var map_max    := Vector2(buf.get_float(), buf.get_float())

	if _state == State.IN_GAME and session_id == _session_id:
		return  # уже обработали

	_session_id = session_id
	_net_id     = net_id
	_tick_rate  = tick_rate
	_map_min    = map_min
	_map_max    = map_max

	NetLog.d("client", "WELCOME session=%d net_id=%d tick=%d" % [_session_id, _net_id, _tick_rate])

	_state = State.IN_GAME
	_set_status("In game (net_id=%d)" % _net_id)

	ClientSession.session_id = _session_id
	ClientSession.net_id = _net_id
	ClientSession.tick_rate = _tick_rate
	ClientSession.map_min = _map_min
	ClientSession.map_max = _map_max
	ClientSession.udp = _udp


func _on_pong(buf: StreamPeerBuffer) -> void:
	var client_time := buf.get_u32()
	_rtt_ms = Time.get_ticks_msec() - int(client_time)
	NetLog.d("client", "PONG rtt=%d ms" % _rtt_ms)
	_set_status("In game (net_id=%d)  RTT=%d ms" % [_net_id, _rtt_ms])


func _on_ack(seq: int) -> void:
	if seq == _hello_seq:
		_hello_acked = true
		NetLog.d("client", "HELLO acked")


func _send_input() -> void:
	var throttle := Input.get_axis("thrust_down", "thrust_up")
	var turn := Input.get_axis("rotate_minus", "rotate_plus")
	var brake := Input.is_action_pressed("inertia_break")
	var fire := Input.is_action_pressed("fire")
	var fire_mode := false  # TODO: вторая кнопка

	var mouse_pos := get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_2d()
	var world_pos := mouse_pos if camera == null else camera.get_screen_center_position() \
		+ (mouse_pos - get_viewport_rect().size * 0.5)

	var flags := 0
	if brake:     flags |= 1
	if fire:      flags |= 2
	if fire_mode: flags |= 4

	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_INPUT, _input_seq)
	_input_seq = (_input_seq + 1) & 0xFFFF
	if _input_seq == 0:
		_input_seq = 1
	buf.put_u16(0)  # acked_tick (пока 0; см. Этап 4)
	buf.put_u8(NetProtocol.quant_axis(throttle))
	buf.put_u8(NetProtocol.quant_axis(turn))
	buf.put_u8(flags)
	buf.put_float(world_pos.x)
	buf.put_float(world_pos.y)
	_udp.put_packet(buf.data_array)


func _send_ping() -> void:
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_PING, _next_seq)
	_next_seq = (_next_seq + 1) & 0xFFFF
	if _next_seq == 0:
		_next_seq = 1
	buf.put_u32(Time.get_ticks_msec())
	_udp.put_packet(buf.data_array)


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
