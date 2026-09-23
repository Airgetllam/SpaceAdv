extends Control
## Клиент: логин + handshake по бинарному протоколу.
## После получения WELCOME передаёт состояние в ClientSession и
## переключается на Game.tscn, где работает GECS-клиент.

enum State { IDLE, CONNECTING, WAITING_WELCOME, IN_GAME }

@onready var nick_edit: LineEdit       = $VBoxContainer/HBoxContainer/LineEdit
@onready var connect_button: Button    = $VBoxContainer/Button
@onready var status_label: Label       = $VBoxContainer/StatusLabel

var _udp: PacketPeerUDP = PacketPeerUDP.new()
var _state: State = State.IDLE

# Handshake
var _session_id: int = 0
var _net_id: int = 0
var _tick_rate: int = 20
var _map_min: Vector2 = Vector2.ZERO
var _map_max: Vector2 = Vector2.ZERO

# Надёжная отправка HELLO до WELCOME
var _next_seq: int = 1
var _hello_payload: PackedByteArray = PackedByteArray()
var _hello_seq: int = 0
var _hello_last_send_ms: int = 0
var _hello_retries: int = 0
var _hello_acked: bool = false

var _reliable_recv: ReliableChannel = ReliableChannel.new()

const SPAWN_X: float = 200.0
const SPAWN_Y: float = 200.0


func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)


func _process(_delta: float) -> void:
	if _state == State.IDLE:
		return

	# Приём пакетов
	while _udp.get_available_packet_count() > 0:
		var raw: PackedByteArray = _udp.get_packet()
		if raw.is_empty():
			break
		var buf := StreamPeerBuffer.new()
		buf.data_array = raw
		_handle_packet(raw, buf)

	# Ретрансмит HELLO, пока не получили WELCOME (или ACK)
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


func _handle_packet(raw: PackedByteArray, buf: StreamPeerBuffer) -> void:
	var header := NetProtocol.read_header(buf)
	match header.msg_type:
		NetProtocol.MSG_WELCOME:
			if _reliable_recv.on_receive(header.seq, raw):
				_on_welcome(buf)
			_send_ack(header.seq)
		NetProtocol.MSG_ACK:
			_on_ack(header.seq)
		_:
			# SPAWN/DESPAWN/FIRE/STATE/PONG обрабатываются в Game.tscn.
			# Здесь их не ACKаем — сервер ретранслирует через 200 мс,
			# когда Game-сцена загрузится.
			NetLog.d("client", "ignored pre-game msg_type=%d" % header.msg_type)


func _send_ack(acked_seq: int) -> void:
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_ACK, acked_seq)
	_udp.put_packet(buf.data_array)


func _on_welcome(buf: StreamPeerBuffer) -> void:
	var session_id := buf.get_u32()
	var net_id     := buf.get_u16()
	var tick_rate  := buf.get_u8()
	var map_min    := Vector2(buf.get_float(), buf.get_float())
	var map_max    := Vector2(buf.get_float(), buf.get_float())

	if _state == State.IN_GAME and session_id == _session_id:
		return

	_session_id = session_id
	_net_id     = net_id
	_tick_rate  = tick_rate
	_map_min    = map_min
	_map_max    = map_max

	NetLog.d("client", "WELCOME session=%d net_id=%d tick=%d" % [_session_id, _net_id, _tick_rate])

	_state = State.IN_GAME
	_set_status("In game (net_id=%d)" % _net_id)

	# Передача состояния в Game.tscn через autoload
	ClientSession.session_id     = _session_id
	ClientSession.net_id         = _net_id
	ClientSession.tick_rate      = _tick_rate
	ClientSession.map_min        = _map_min
	ClientSession.map_max        = _map_max
	ClientSession.udp            = _udp
	ClientSession.reliable_recv  = _reliable_recv
	ClientSession.next_input_seq = 1
	ClientSession.next_ping_seq  = 1
	ClientSession.net_id_to_entity.clear()
	ClientSession.entity_to_net_id.clear()

	call_deferred("_goto_game")


func _goto_game() -> void:
	NetLog.d("client", "switching to Game.tscn")
	var err := get_tree().change_scene_to_file("res://Client/Scenes/Game.tscn")
	NetLog.d("client", "change_scene result=%d" % err)


func _on_ack(seq: int) -> void:
	if seq == _hello_seq:
		_hello_acked = true
		NetLog.d("client", "HELLO acked")


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
