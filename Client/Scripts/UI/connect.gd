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
var _mirror_entities: Dictionary = {}   # net_id -> { kind, pos, rot, hp, hp_max, size, blocks/mask }

var _projectile_multimesh: MultiMeshInstance2D = null

# Интерполяция чужих сущностей
const INTERP_DURATION: float = 0.1   # 2 серверных тика

# Для собственного корабля — последнее серверное состояние
var _last_server_pos: Vector2 = Vector2.ZERO
var _last_server_rot: float = 0.0
var _last_server_hp: int = 0
var _last_server_hp_max: int = 0
var _last_acked_input_seq: int = 0

# Счётчик тиков для отладки
var _last_server_tick: int = 0


const FIXED_DT: float = MovementModel.FIXED_DT
const INPUT_RATE: float = 30.0
const INPUT_INTERVAL: float = 1.0 / INPUT_RATE

# История отправленных input (для reconciliation)
# [{ seq, throttle, turn, brake, dt }]
var _input_history: Array = []

# Локальное состояние предсказания (только для себя)
var _pred_pos: Vector2 = Vector2.ZERO
var _pred_rot: float = 0.0
var _pred_vel: Vector2 = Vector2.ZERO
var _pred_throttle: float = 0.0
var _pred_initialized: bool = false

var _last_server_vel: Vector2 = Vector2.ZERO
var _last_reconciled_seq: int = 0

func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)

func _physics_process(_delta: float) -> void:
	if _state != State.IDLE:
		_poll_packets()

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
	_poll_packets()
	_update_interpolation(delta)

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
		while _input_accum >= INPUT_INTERVAL:
			_input_accum -= INPUT_INTERVAL
			_do_input_tick()
		_ping_accum += delta
		if _ping_accum >= PING_INTERVAL:
			_ping_accum = 0.0
			_send_ping()
	_sync_local_mirror()
	if _state == State.IN_GAME:
		_render_projectiles()

func _poll_packets() -> void:
	while _udp.get_available_packet_count() > 0:
		var raw: PackedByteArray = _udp.get_packet()
		if raw.is_empty():
			break
		var buf := StreamPeerBuffer.new()
		buf.data_array = raw
		_handle_packet(raw, buf)

func _render_projectiles() -> void:
	if _projectile_multimesh == null:
		return
	var mm: MultiMesh = _projectile_multimesh.multimesh
	if mm == null:
		return
	var idx := 0
	for nid in _mirror_entities.keys():
		var e: Dictionary = _mirror_entities[nid]
		if not e.get("is_projectile", false):
			continue
		if idx >= mm.instance_count:
			break
		var pos: Vector2 = e.get("pos", Vector2.ZERO)
		var rot: float   = e.get("rot", 0.0)
		mm.set_instance_transform_2d(idx, Transform2D(rot, pos))
		idx += 1
	mm.visible_instance_count = idx

func _sync_local_mirror() -> void:
	if not _pred_initialized:
		return
	var e: Dictionary = _mirror_entities.get(_net_id, {})
	if e.is_empty():
		return
	e["pos"] = _pred_pos
	e["rot"] = _pred_rot
	_mirror_entities[_net_id] = e

func _do_input_tick() -> void:
	if not _pred_initialized:
		return

	var throttle_raw := Input.get_axis("thrust_down", "thrust_up")
	var turn_raw := Input.get_axis("rotate_minus", "rotate_plus")
	var brake := Input.is_action_pressed("inertia_break")
	var fire_mode_1 := Input.is_action_pressed("fire")          # по очереди
	var fire_mode_2 := Input.is_action_pressed("fire_alt")      # залп
	var fire := fire_mode_1 or fire_mode_2
	var fire_mode := 1
	if fire_mode_2:
		fire_mode = 2

	var throttle_q: int = NetProtocol.quant_axis(throttle_raw)
	var turn_q: int = NetProtocol.quant_axis(turn_raw)
	var throttle: float = NetProtocol.dequant_axis(throttle_q)
	var turn: float = NetProtocol.dequant_axis(turn_q)

	var seq := _input_seq
	_input_seq = (_input_seq + 1) & 0xFFFF
	if _input_seq == 0:
		_input_seq = 1

	# Локальное применение input
	var out: Dictionary = MovementModel.step({
		"pos": _pred_pos,
		"rot": _pred_rot,
		"vel": _pred_vel,
		"throttle": _pred_throttle,
	}, {
		"throttle": throttle,
		"turn": turn,
		"brake": brake,
		"dt": FIXED_DT,
	})
	_pred_pos = out.pos
	_pred_rot = out.rot
	_pred_vel = out.vel
	_pred_throttle = out.throttle

	# История — только inputs, без состояния
	_input_history.append({
		"seq": seq,
		"throttle": throttle,
		"turn": turn,
		"brake": brake,
		"dt": FIXED_DT,
	})
	if _input_history.size() > 256:
		_input_history.pop_front()

	# Отправка MSG_INPUT
	var mouse_pos := get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_2d()
	var world_pos := mouse_pos
	if camera:
		world_pos = camera.get_screen_center_position() \
			+ (mouse_pos - get_viewport_rect().size * 0.5)

	var flags := 0
	if brake: flags |= 1
	if fire:  flags |= 2
	flags |= (fire_mode & 3) << 2

	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_INPUT, 0)
	buf.put_u16(seq)
	buf.put_u8(throttle_q)
	buf.put_u8(turn_q)
	buf.put_u8(flags)
	buf.put_float(world_pos.x)
	buf.put_float(world_pos.y)
	_udp.put_packet(buf.data_array)

func _update_interpolation(delta: float) -> void:
	var step: float = delta / INTERP_DURATION
	for net_id in _mirror_entities.keys():
		if net_id == _net_id:
			continue
		var entry: Dictionary = _mirror_entities[net_id]
		if not entry.get("has_target", false):
			continue
		var t: float = min(entry.get("interp_t", 0.0) + step, 1.0)
		entry["interp_t"] = t

		var prev_pos: Vector2 = entry.get("prev_pos", entry.get("curr_pos", Vector2.ZERO))
		var curr_pos: Vector2 = entry.get("curr_pos", prev_pos)
		var prev_rot: float = entry.get("prev_rot", entry.get("curr_rot", 0.0))
		var curr_rot: float = entry.get("curr_rot", prev_rot)

		var pos: Vector2 = prev_pos.lerp(curr_pos, t)
		var rot: float = lerp_angle(prev_rot, curr_rot, t)

		entry["pos"] = pos
		entry["rot"] = rot
		_mirror_entities[net_id] = entry

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
			if _reliable_recv.on_receive(header.seq, raw):
				_on_welcome(buf)
			_send_ack(header.seq)
		NetProtocol.MSG_ACK:
			_on_ack(header.seq)
		NetProtocol.MSG_PONG:
			_on_pong(buf)
		_:
			# Всё остальное (SPAWN/DESPAWN/FIRE/STATE) обрабатывается уже
			# в Game.tscn. Здесь их НЕ подтверждаем — тогда сервер ретранслирует
			# через 200 мс, когда Game-сцена уже загрузится и примет их.
			NetLog.d("client", "ignored pre-game msg_type=%d" % header.msg_type)

func _on_state(buf: StreamPeerBuffer) -> void:
	var tick: int = buf.get_u16()
	var acked_input_seq: int = buf.get_u16()
	var count: int = buf.get_u8()

	_last_server_tick = tick
	_last_acked_input_seq = acked_input_seq

	for _i in count:
		var net_id: int = buf.get_u16()
		var mask: int = buf.get_u8()

		var has_pos: bool = (mask & 1) != 0
		var has_rot: bool = (mask & 2) != 0
		var has_hp: bool  = (mask & 4) != 0
		var has_vel: bool = (mask & 8) != 0

		var entry: Dictionary = _mirror_entities.get(net_id, {})
		if entry.is_empty():
			continue

		# --- Позиция ---
		if has_pos:
			var qx: int = buf.get_u16()
			var qy: int = buf.get_u16()
			entry["pos"] = NetProtocol.dequant_pos(
				Vector2i(qx, qy), ClientSession.map_min, ClientSession.map_max
			)

		# --- Поворот ---
		if has_rot:
			var qrot: int = buf.get_u16()
			entry["rot"] = NetProtocol.dequant_rot(qrot)

		# --- HP ---
		if has_hp:
			entry["hp"] = buf.get_u16()

		# --- Velocity (КЛЮЧЕВОЕ: сохраняем в entry) ---
		if has_vel:
			var vx: int = buf.get_16()
			var vy: int = buf.get_16()
			entry["vel"] = Vector2(vx, vy)

		if net_id == _net_id:
			_on_own_state(entry, acked_input_seq)
		else:
			_on_remote_state(entry)

		_mirror_entities[net_id] = entry


func _on_own_state(entry: Dictionary, acked_input_seq: int) -> void:
	var world_pos: Vector2 = entry.get("pos", _pred_pos)
	var world_rot: float   = entry.get("rot", _pred_rot)
	var server_vel: Vector2 = entry.get("vel", _last_server_vel)

	_last_server_pos = world_pos
	_last_server_rot = world_rot
	_last_server_vel = server_vel
	_last_acked_input_seq = acked_input_seq

	if not _pred_initialized:
		_pred_pos = world_pos
		_pred_rot = world_rot
		_pred_vel = server_vel
		_pred_throttle = 0.0
		_pred_initialized = true
		return

	# КЛЮЧЕВОЕ: не reconcile повторно с тем же acked
	if acked_input_seq > 0 and acked_input_seq > _last_reconciled_seq:
		_reconcile(acked_input_seq, world_pos, world_rot, server_vel)


func _on_remote_state(entry: Dictionary) -> void:
	var world_pos: Vector2 = entry.get("pos", Vector2.ZERO)
	var world_rot: float   = entry.get("rot", 0.0)
	entry["prev_pos"] = entry.get("curr_pos", world_pos)
	entry["prev_rot"] = entry.get("curr_rot", world_rot)
	entry["curr_pos"] = world_pos
	entry["curr_rot"] = world_rot
	entry["interp_t"] = 0.0
	entry["has_target"] = true

func _reconcile(acked_seq: int, server_pos: Vector2, server_rot: float, server_vel: Vector2) -> void:
	# 1. Стартуем с авторитетного серверного состояния на момент ack
	var s: Dictionary = {
		"pos": server_pos,
		"rot": server_rot,
		"vel": server_vel,
		"throttle": _pred_throttle,
	}

	# 2. Replay всех inputs, отправленных ПОСЛЕ ack
	for inp in _input_history:
		if inp.seq <= acked_seq:
			continue
		s = MovementModel.step(s, {
			"throttle": inp.throttle,
			"turn": inp.turn,
			"brake": inp.brake,
			"dt": inp.dt,
		})

	# 3. Результат replay — новая prediction
	_pred_pos = s.pos
	_pred_rot = s.rot
	_pred_vel = s.vel
	_pred_throttle = s.throttle
	_last_reconciled_seq = acked_seq

	# 4. Удаляем inputs с seq <= acked_seq
	var new_history: Array = []
	for inp in _input_history:
		if inp.seq > acked_seq:
			new_history.append(inp)
	_input_history = new_history

	NetLog.d("reconcile", "acked=%d pending=%d" % [acked_seq, _input_history.size()])

func _on_fire(buf: StreamPeerBuffer) -> void:
	var proj_net_id := buf.get_u16()
	var shooter_net_id := buf.get_u16()
	var sx := buf.get_float()
	var sy := buf.get_float()
	var rot := NetProtocol.dequant_rot(buf.get_u16())
	var target_net_id := buf.get_u16()

	var entry: Dictionary = _mirror_entities.get(proj_net_id, {})
	entry["net_id"] = proj_net_id
	entry["kind"] = 2
	entry["is_projectile"] = true
	entry["owner_net_id"] = shooter_net_id
	entry["pos"] = Vector2(sx, sy)
	entry["rot"] = rot
	entry["target_net_id"] = target_net_id
	# Интерполяция снаряда: стартуем «на месте», дальше MSG_STATE (10 Гц)
	# будет двигать prev/curr, а _update_interpolation — плавно тянуть.
	entry["prev_pos"] = Vector2(sx, sy)
	entry["curr_pos"] = Vector2(sx, sy)
	entry["prev_rot"] = rot
	entry["curr_rot"] = rot
	entry["interp_t"] = 1.0
	entry["has_target"] = true
	_mirror_entities[proj_net_id] = entry

	NetLog.d("client", "FIRE net_id=%d shooter=%d pos=(%.1f,%.1f) rot=%.2f" % [
		proj_net_id, shooter_net_id, sx, sy, rot
	])

func _on_spawn(buf: StreamPeerBuffer) -> void:
	var net_id       := buf.get_u16()
	var kind         := buf.get_u8()
	var owner_net_id := buf.get_u16()
	var px           := buf.get_float()
	var py           := buf.get_float()
	var rot          := NetProtocol.dequant_rot(buf.get_u16())
	var hp           := buf.get_u16()
	var hp_max       := buf.get_u16()
	var size_x       := buf.get_u16()
	var size_y       := buf.get_u16()
	var block_count  := buf.get_u16()

	var is_owner := (net_id == _net_id)

	var entry := {
		"net_id": net_id,
		"kind": kind,
		"owner_net_id": owner_net_id,
		"pos": Vector2(px, py),
		"rot": rot,
		"hp": hp,
		"hp_max": hp_max,
		"size": Vector2(size_x, size_y),
		"block_count": block_count,
	}

	if kind == 2:
		entry["is_projectile"] = true

	if block_count > 0 and is_owner:
		# Полный список блоков
		var blocks: Array = []
		for i in block_count:
			var bx := buf.get_float()
			var by := buf.get_float()
			var bid := buf.get_u8()
			var bhp := buf.get_u16()
			blocks.append({ "pos": Vector2(bx, by), "id": bid, "hp": bhp })
		entry["blocks"] = blocks
		NetLog.d("client", "SPAWN own ship net_id=%d hp=%d/%d blocks=%d" % [
			net_id, hp, hp_max, block_count
		])
	elif block_count > 0:
		var mask_bytes := int(ceil(float(block_count) / 8.0))
		var data_res: Array = buf.get_data(mask_bytes)
		if data_res[0] != OK:
			NetLog.d("client", "SPAWN: get_data failed (mask_bytes=%d)" % mask_bytes)
			return
		var mask: PackedByteArray = data_res[1]
		entry["alive_mask"] = mask
		NetLog.d("client", "SPAWN ship net_id=%d hp=%d/%d blocks=%d mask=%s" % [
			net_id, hp, hp_max, block_count, mask.hex_encode()
		])
	else:
		NetLog.d("client", "SPAWN net_id=%d kind=%d (no blocks)" % [net_id, kind])

	_mirror_entities[net_id] = entry


func _on_despawn(buf: StreamPeerBuffer) -> void:
	var net_id := buf.get_u16()
	_mirror_entities.erase(net_id)
	NetLog.d("client", "DESPAWN net_id=%d (mirror size=%d)" % [net_id, _mirror_entities.size()])

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
	ClientSession.session_id = _session_id
	ClientSession.net_id     = _net_id
	ClientSession.tick_rate  = _tick_rate
	ClientSession.map_min    = _map_min
	ClientSession.map_max    = _map_max
	ClientSession.udp        = _udp
	ClientSession.reliable_recv = _reliable_recv
	ClientSession.next_input_seq = 1
	ClientSession.next_ping_seq = 1
	ClientSession.net_id_to_entity.clear()
	ClientSession.entity_to_net_id.clear()

	# Переход в игровую сцену — отложенно, чтобы не менять сцену
	# посреди _process.
	call_deferred("_goto_game")


func _goto_game() -> void:
	NetLog.d("client", "switching to Game.tscn")
	var err := get_tree().change_scene_to_file("res://Client/Scenes/Game.tscn")
	NetLog.d("client", "change_scene result=%d" % err)

func _create_projectile_multimesh() -> void:
	if _projectile_multimesh != null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = 256
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 8)
	mm.mesh = quad
	for i in mm.instance_count:
		mm.set_instance_color(i, Color.YELLOW)
	_projectile_multimesh = MultiMeshInstance2D.new()
	_projectile_multimesh.multimesh = mm
	_projectile_multimesh.z_index = 10
	add_child(_projectile_multimesh)


func _on_pong(buf: StreamPeerBuffer) -> void:
	var client_time := buf.get_u32()
	_rtt_ms = Time.get_ticks_msec() - int(client_time)
	NetLog.d("client", "PONG rtt=%d ms" % _rtt_ms)
	_set_status("In game (net_id=%d)  RTT=%d ms" % [_net_id, _rtt_ms])


func _on_ack(seq: int) -> void:
	if seq == _hello_seq:
		_hello_acked = true
		NetLog.d("client", "HELLO acked")


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
