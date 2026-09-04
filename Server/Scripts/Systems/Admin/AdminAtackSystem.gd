extends System
class_name AdminAtackSystem

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		var targets: C_Targets = entity.get_component(C_Targets)
		if Input.is_action_just_pressed("pkm"):
			var _entity = Entity.new()
			var comps = [
				C_ExistenceState.new(),
				C_SpawnPoint.new(cursor.position)
			]
			cmd.add_components(_entity, comps)
			ECS.world.add_entity(_entity)
			#if !targets.list.is_empty() and targets.list[0].state == 1:
				
