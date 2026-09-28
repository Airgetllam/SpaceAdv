extends System
class_name PlayerAbilitySystem

const BOOST_IMPULSE: float = 500.0

func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_PlayerInputState, C_Direction, C_Velocity])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
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

		for i in range(input_state.pending_events.size() - 1, -1, -1):
			var event: PlayerInputAction = input_state.pending_events[i]

			if event.action_id != InputActions.ABILITY_BOOST:
				continue

			if event.state == PlayerInputAction.State.PRESSED:
				var forward := Vector2.UP.rotated(
					deg_to_rad(direction.value)
				)

				velocity.value += forward * BOOST_IMPULSE

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

			input_state.pending_events.remove_at(i)
