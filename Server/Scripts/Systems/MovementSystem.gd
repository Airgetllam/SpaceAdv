class_name MovementSystem
extends System

const FIXED_DT: float = MovementModel.FIXED_DT
var _accum: float = 0.0

func query() -> QueryBuilder:
	return q.with_all([
		C_PeerID,
		C_ControlInput,
		C_Position,
		C_Direction,
		C_Velocity,
		C_Force
	])

func process(
	entities: Array[Entity],
	_components: Array,
	delta: float
) -> void:
	_accum += delta

	# Обычный authoritative movement остаётся 30 Hz.
	var regular_step := false

	if _accum >= FIXED_DT:
		_accum -= FIXED_DT
		regular_step = true

	for entity in entities:
		var ps: PeerState = entity.get_meta(
			"peer_state",
			null
		)

		var catchup_step := false

		if (
			ps != null
			and ps.input_queue.size()
				> NetConfig.INPUT_CATCHUP_QUEUE_THRESHOLD
		):
			catchup_step = true

		# Нормальный режим:
		# ~30 authoritative steps/sec.
		#
		# При накопившейся очереди:
		# максимум один step на physics frame,
		# то есть до ~60 steps/sec при стандартных
		# Godot physics ticks.
		#
		# Каждый input всё равно проходит через
		# отдельный physics pipeline:
		#
		# Movement
		# -> Ability
		# -> TargetSelection
		# -> PlayerFire
		#
		# Поэтому discrete events не теряются.
		if regular_step or catchup_step:
			_step_one(
				entity,
				FIXED_DT
			)


func _step_one(e: Entity, dt: float) -> void:
	var inp_c: C_ControlInput = e.get_component(C_ControlInput)
	var pos_c: C_Position = e.get_component(C_Position)
	var dir_c: C_Direction = e.get_component(C_Direction)
	var vel_c: C_Velocity = e.get_component(C_Velocity)
	var force_c: C_Force = e.get_component(C_Force)

	var ps: PeerState = e.get_meta("peer_state", null)
	var applied_new_input: bool = false

	var input_state: C_PlayerInputState = (
		e.get_component(C_PlayerInputState)
	)

	if ps:
		# Для network player один authoritative
		# MovementModel.step соответствует одному input_seq.
		#
		# Если frame ещё не пришёл, simulation ждёт его.
		# Redundant MSG_INPUT будет повторять старейший
		# unacked frame до получения.
		if ps.input_queue.is_empty():
			return

		var expected_seq: int

		if ps.last_applied_input_seq == 0:
			expected_seq = 1
		else:
			expected_seq = NetProtocol.seq_next(
				ps.last_applied_input_seq
			)

		var first_packet: Dictionary = (
			ps.input_queue[0]
		)

		var first_seq: int = int(
			first_packet.seq
		)

		# Нельзя перескакивать через потерянный input.
		if first_seq != expected_seq:
			return

		var packet: Dictionary = (
			ps.input_queue.pop_front()
		)

		var frame: PlayerInputFrame = (
			packet.frame
		)

		if input_state:
			input_state.current_frame = frame
			input_state.pending_events.clear()
			input_state.pending_events.append_array(
				frame.events
			)

		inp_c.throttle = frame.throttle
		inp_c.turn = frame.turn
		inp_c.brake = frame.brake

		var cursor_c: C_CursorPosition = (
			e.get_component(C_CursorPosition)
		)

		if cursor_c:
			cursor_c.position = frame.cursor_position

		ps.last_applied_input_seq = int(packet.seq)
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

	var out: Dictionary = MovementModel.step(
		s,
		input
	)

	pos_c.value = out.pos

	pos_c.value = Vector2(
		clamp(
			pos_c.value.x,
			NetConfig.MAP_MIN.x + 64.0,
			NetConfig.MAP_MAX.x - 64.0
		),
		clamp(
			pos_c.value.y,
			NetConfig.MAP_MIN.y + 64.0,
			NetConfig.MAP_MAX.y - 64.0
		)
	)

	dir_c.value = rad_to_deg(out.rot)
	vel_c.value = out.vel
	force_c.value = out.throttle

	# Этот snapshot строго соответствует last_applied_input_seq.
	if ps and applied_new_input:
		ps.acked_pos = pos_c.value
		ps.acked_rot = dir_c.value
		ps.acked_vel = vel_c.value
		ps.acked_throttle = force_c.value
		ps.acked_initialized = true
