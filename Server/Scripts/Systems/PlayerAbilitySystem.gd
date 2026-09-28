extends System
class_name PlayerAbilitySystem


func query() -> QueryBuilder:
	return q.with_all([
		C_PeerID,
		C_PlayerInputState,
		C_Direction,
		C_Velocity,
	])


func process(
	entities: Array[Entity],
	_components: Array,
	_delta: float
) -> void:
	for entity in entities:
		var input_state: C_PlayerInputState = (
			entity.get_component(C_PlayerInputState)
		)

		var direction: C_Direction = (
			entity.get_component(C_Direction)
		)

		var velocity: C_Velocity = (
			entity.get_component(C_Velocity)
		)

		if (
			input_state == null
			or direction == null
			or velocity == null
		):
			continue

		var ability_applied := false

		for i in range(input_state.pending_events.size() - 1, -1, -1):
			var event: PlayerInputAction = (
				input_state.pending_events[i]
			)

			if event.action_id != InputActions.ABILITY_BOOST:
				continue

			if event.state == PlayerInputAction.State.PRESSED:
				velocity.value = AbilityModel.apply_boost(
					velocity.value,
					deg_to_rad(direction.value)
				)

				ability_applied = true

				var net_id := 0

				var net_id_component: C_NetId = (
					entity.get_component(C_NetId)
				)

				if net_id_component:
					net_id = net_id_component.value

				NetLog.d(
					"ability",
					"boost net_id=%d velocity=(%.1f,%.1f)" % [
						net_id,
						velocity.value.x,
						velocity.value.y,
					]
				)

			# Событие считается consumed независимо от состояния.
			input_state.pending_events.remove_at(i)

		# MovementSystem формирует ack snapshot до ability.
		# После boost обновляем его, чтобы MSG_STATE отражал
		# authoritative velocity после применения события.
		if ability_applied:
			var ps: PeerState = (
				entity.get_meta("peer_state", null)
			)

			var position: C_Position = (
				entity.get_component(C_Position)
			)

			if ps != null and position != null:
				ps.acked_pos = position.value
				ps.acked_rot = direction.value
				ps.acked_vel = velocity.value
				ps.acked_initialized = true
