extends Observer
class_name SpawnPositionSyncObserver

func query() -> QueryBuilder:
	return q.with_all([C_SpawnPoint]).on_added()


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var spawn_pos: C_SpawnPoint = entity.get_component(C_SpawnPoint)
	var pos: C_Position = entity.get_component(C_Position)
	var dir: C_Direction = entity.get_component(C_Direction)
	if pos:
		pos.value = spawn_pos.value
	else:
		cmd.add_component(entity, C_Position.new(spawn_pos.value))
	if dir:
		dir.value = spawn_pos.angle_value
	else:
		cmd.add_component(entity, C_Direction.new(spawn_pos.angle_value))
	cmd.remove_component(entity, C_SpawnPoint)
