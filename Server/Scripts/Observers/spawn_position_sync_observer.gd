extends Observer
class_name SpawnPositionSyncObserver

func query() -> QueryBuilder:
	return q.with_all([C_SpawnPoint]).on_added()


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var spawn_pos: C_SpawnPoint = entity.get_component(C_SpawnPoint)
	var pos: C_Position = entity.get_component(C_Position)
	pos.value = spawn_pos.value
	cmd.remove_component(entity, C_SpawnPoint)
