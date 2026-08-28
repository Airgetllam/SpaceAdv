extends System
class_name AdminCursorSyncSystem

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var mouse_pos: Vector2 = get_viewport().get_camera_2d().get_global_mouse_position()
	for entity in entities:
		var pos: C_Position = entity.get_component(C_Position)
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		cursor.position = mouse_pos
