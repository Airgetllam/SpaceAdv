class_name MovementSystem
extends System

const FIXED_DT: float = MovementModel.FIXED_DT
var _accum: float = 0.0

func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_ControlInput, C_Position, C_Direction, C_Velocity, C_Force])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	_accum += delta
	while _accum >= FIXED_DT:
		_accum -= FIXED_DT
		for e in entities:
			_step_one(e, FIXED_DT)


func _step_one(e: Entity, dt: float) -> void:
	var inp_c: C_ControlInput = e.get_component(C_ControlInput)
	var pos_c: C_Position     = e.get_component(C_Position)
	var dir_c: C_Direction    = e.get_component(C_Direction)
	var vel_c: C_Velocity     = e.get_component(C_Velocity)
	var force_c: C_Force      = e.get_component(C_Force)

	var ps: PeerState = e.get_meta("peer_state", null)
	var applied_new_input: bool = false
	var input_state: C_PlayerInputState = e.get_component(C_PlayerInputState)

	# Забираем ровно один generic input frame
	# на каждый шаг симуляции.
	if ps and not ps.input_queue.is_empty():
		var packet: Dictionary = ps.input_queue.pop_front()

		var frame: PlayerInputFrame = packet.frame

		if input_state:
			input_state.current_frame = frame
			input_state.pending_events.clear()
			input_state.pending_events.append_array(frame.events)

		inp_c.throttle = frame.throttle
		inp_c.turn = frame.turn
		inp_c.brake = frame.brake

		inp_c.fire = frame.is_action_pressed(
			InputActions.PRIMARY_FIRE
		) or frame.is_action_pressed(
			InputActions.SECONDARY_FIRE
		)

		if frame.is_action_pressed(InputActions.SECONDARY_FIRE):
			inp_c.fire_mode = 2
		else:
			inp_c.fire_mode = 1

		var cursor_c: C_CursorPosition = e.get_component(C_CursorPosition)

		if cursor_c:
			cursor_c.position = frame.cursor_position

		ps.last_applied_input_seq = packet.seq
		applied_new_input = true

	var s: Dictionary = {
		"pos": pos_c.value,
		"rot": deg_to_rad(dir_c.value),
		"vel": vel_c.value,
		"throttle": force_c.value,
	}
	var input: Dictionary = {
		"throttle": inp_c.throttle,
		"turn": inp_c.turn,
		"brake": inp_c.brake,
		"dt": dt,
	}
	var out: Dictionary = MovementModel.step(s, input)

	pos_c.value = out.pos
	pos_c.value = Vector2(
		clamp(pos_c.value.x, NetConfig.MAP_MIN.x + 64.0, NetConfig.MAP_MAX.x - 64.0),
		clamp(pos_c.value.y, NetConfig.MAP_MIN.y + 64.0, NetConfig.MAP_MAX.y - 64.0))
	dir_c.value = rad_to_deg(out.rot)
	vel_c.value = out.vel
	force_c.value = out.throttle

	# Снапшот состояния НА МОМЕНТ acked_seq
	if ps and applied_new_input:
		ps.acked_pos = pos_c.value
		ps.acked_rot = dir_c.value
		ps.acked_vel = vel_c.value
		ps.acked_initialized = true
