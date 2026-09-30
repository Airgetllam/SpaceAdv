class_name ClientInputSystem
extends System

const INPUT_INTERVAL := NetConfig.CLIENT_INPUT_DT
const PING_INTERVAL := 1.0
const FIXED_DT: float = MovementModel.FIXED_DT

var _input_accum: float = 0.0
var _ping_accum: float = 0.0

var _input_mapper := PlayerInputMapper.new()

func query() -> QueryBuilder:
	return q.with_all([
		C_IsLocalPlayer,
		C_PredictedState,
		C_InputHistory,
		C_PlayerInput,
		C_Position,
		C_LastServerState,
	])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	# Снимаем hardware input отдельно от input tick.
	_input_mapper.capture()

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
	var last: C_LastServerState = (
		entity.get_component(C_LastServerState)
	)
	var player_input: C_PlayerInput = entity.get_component(C_PlayerInput)
	var pos: C_Position = entity.get_component(C_Position)

	# Получаем полностью generic input frame.
	var frame := _input_mapper.consume_frame()
	player_input.frame = frame

	var throttle_raw: float = frame.throttle
	var turn_raw: float = frame.turn
	var brake: bool = frame.brake

	# Пока Stage 2 ещё не меняет сетевой протокол,
	# старое поведение fire сохраняем через generic state.
	var fire_1: bool = frame.is_action_pressed(InputActions.PRIMARY_FIRE)
	var fire_2: bool = frame.is_action_pressed(InputActions.SECONDARY_FIRE)

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

	var out: Dictionary = MovementModel.step(
		{
			"pos": pred.pos,
			"rot": pred.rot,
			"vel": pred.vel,
			"throttle": pred.throttle,
		},
		{
			"throttle": throttle,
			"turn": turn,
			"brake": brake,
			"dt": FIXED_DT,
		}
	)

	pred.pos = out.pos
	pred.rot = out.rot
	pred.vel = out.vel
	pred.throttle = out.throttle

	# Локальное prediction дискретных действий.
	for event in frame.events:
		if event.action_id != InputActions.ABILITY_BOOST:
			continue

		if event.state != PlayerInputAction.State.PRESSED:
			continue

		pred.vel = AbilityModel.apply_boost(
			pred.vel,
			pred.rot
			)

	# Синхронизация в C_Position / C_Direction для рендера и камеры.
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
		"events": frame.events,
		"frame": frame,
	})

	if hist.entries.size() > 256:
		hist.entries.pop_front()

	_send_input_bundle(
		hist,
		last.last_input_ack_seq
	)

	if not frame.events.is_empty():
		for event in frame.events:
			NetLog.d(
				"input",
				"send event_seq=%d action=%d state=%d value=%.2f pos=(%.1f,%.1f)" % [
					event.event_seq,
					event.action_id,
					event.state,
					event.value,
					event.position.x,
					event.position.y,
				]
			)

func _send_input_bundle(
	history: C_InputHistory,
	acked_seq: int
) -> void:
	if ClientSession.udp == null:
		return

	if history.entries.is_empty():
		return

	var bundle: Array = []

	# History хранится до authoritative reconciliation,
	# но transport не должен повторно отправлять frames,
	# которые сервер уже подтвердил.
	for entry in history.entries:
		var entry_seq: int = int(
			entry.get("seq", 0)
		)

		if (
			acked_seq != 0
			and not NetProtocol.seq_is_newer(
				entry_seq,
				acked_seq
			)
		):
			continue

		bundle.append(entry)

		if (
			bundle.size()
			>= NetConfig.MAX_INPUT_FRAMES_PER_PACKET
		):
			break

	if bundle.is_empty():
		return

	var buf := StreamPeerBuffer.new()

	NetProtocol.write_header(
		buf,
		NetProtocol.MSG_INPUT,
		0
	)

	NetProtocol.write_input_bundle(
		buf,
		bundle
	)

	ClientSession.udp.put_packet(
		buf.data_array
	)

func _send_ping() -> void:
	var seq := ClientSession.next_ping_seq

	ClientSession.next_ping_seq = (seq + 1) & 0xFFFF

	if ClientSession.next_ping_seq == 0:
		ClientSession.next_ping_seq = 1

	var buf := StreamPeerBuffer.new()

	NetProtocol.write_header(
		buf,
		NetProtocol.MSG_PING,
		seq
	)

	buf.put_u32(Time.get_ticks_msec())

	ClientSession.udp.put_packet(buf.data_array)
