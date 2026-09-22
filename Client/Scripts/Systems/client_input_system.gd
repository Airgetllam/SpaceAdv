class_name ClientInputSystem
extends System

const INPUT_RATE := 30.0
const INPUT_INTERVAL := 1.0 / INPUT_RATE
const PING_INTERVAL := 1.0
const FIXED_DT: float = MovementModel.FIXED_DT

var _input_accum: float = 0.0
var _ping_accum: float = 0.0

func query() -> QueryBuilder:
	return q.with_all([C_IsLocalPlayer, C_PredictedState, C_InputHistory, C_Position])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	_input_accum += delta
	while _input_accum >= INPUT_INTERVAL:
		_input_accum -= INPUT_INTERVAL
		for e in entities:
			_tick(e)

	_ping_accum += delta
	if _ping_accum >= PING_INTERVAL:
		_ping_accum = 0.0
		_send_ping()

func _tick(entity: Entity) -> void:
	var pred: C_PredictedState = entity.get_component(C_PredictedState)
	if not pred.initialized:
		return
	var hist: C_InputHistory = entity.get_component(C_InputHistory)
	var pos: C_Position = entity.get_component(C_Position)

	var throttle_raw := Input.get_axis("thrust_down", "thrust_up")
	var turn_raw := Input.get_axis("rotate_minus", "rotate_plus")
	var brake := Input.is_action_pressed("inertia_break")
	var fire_1 := Input.is_action_pressed("fire")
	var fire_2 := Input.is_action_pressed("fire_alt")
	var fire := fire_1 or fire_2
	var fire_mode := 2 if fire_2 else 1

	var throttle_q: int = NetProtocol.quant_axis(throttle_raw)
	var turn_q: int = NetProtocol.quant_axis(turn_raw)
	var throttle: float = NetProtocol.dequant_axis(throttle_q)
	var turn: float = NetProtocol.dequant_axis(turn_q)

	var seq := ClientSession.next_input_seq
	ClientSession.next_input_seq = (seq + 1) & 0xFFFF
	if ClientSession.next_input_seq == 0:
		ClientSession.next_input_seq = 1

	var out: Dictionary = MovementModel.step({
		"pos": pred.pos,
		"rot": pred.rot,
		"vel": pred.vel,
		"throttle": pred.throttle,
	}, {
		"throttle": throttle,
		"turn": turn,
		"brake": brake,
		"dt": FIXED_DT,
	})
	pred.pos = out.pos
	pred.rot = out.rot
	pred.vel = out.vel
	pred.throttle = out.throttle

	# Синхронизация в C_Position / C_Direction для рендера и камеры
	pos.value = pred.pos
	var dir: C_Direction = entity.get_component(C_Direction)
	if dir:
		dir.value = rad_to_deg(pred.rot)

	hist.entries.append({
		"seq": seq,
		"throttle": throttle,
		"turn": turn,
		"brake": brake,
		"dt": FIXED_DT,
	})
	if hist.entries.size() > 256:
		hist.entries.pop_front()

	# Формируем MSG_INPUT
	var vp := ClientSession.game_node.get_viewport()
	var mouse_pos := vp.get_mouse_position()
	var camera := vp.get_camera_2d()
	var world_pos := mouse_pos
	if camera:
		world_pos = camera.get_screen_center_position() + (mouse_pos - vp.get_visible_rect().size * 0.5)

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
	ClientSession.udp.put_packet(buf.data_array)

func _send_ping() -> void:
	var seq := ClientSession.next_ping_seq
	ClientSession.next_ping_seq = (seq + 1) & 0xFFFF
	if ClientSession.next_ping_seq == 0:
		ClientSession.next_ping_seq = 1
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_PING, seq)
	buf.put_u32(Time.get_ticks_msec())
	ClientSession.udp.put_packet(buf.data_array)
