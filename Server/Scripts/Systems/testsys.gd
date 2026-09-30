extends System
class_name TestSystem


func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_PlayerInputState])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var input_state: C_PlayerInputState = entity.get_component(C_PlayerInputState)
		if input_state == null:
			continue
		
		for i in range(input_state.pending_events.size() - 1, -1, -1):
			var event: PlayerInputAction = (input_state.pending_events[i])
			if event.action_id != InputActions.TEST:
				continue
			print('test!')
			input_state.pending_events.remove_at(i)
