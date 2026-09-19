extends System
class_name AdminInteractSystem

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var root = Engine.get_main_loop().root
	if not root:
		return

	var mouse_pos = root.get_mouse_position()
	var camera = root.get_camera_2d()
	if camera:
		mouse_pos = camera.get_global_mouse_position()

	var space = root.get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collide_with_bodies = true
	params.collide_with_areas = true

	var results = space.intersect_point(params)
	if results.is_empty():
		return

	var collider = results[0].collider
	if not (collider is Node2D):
		return

	var local_point = collider.to_local(mouse_pos)
	var cell_size = ServerConfig.CELL_SIZE
	var cell = Vector2(
		floor(local_point.x / cell_size) + 0.5,
		floor(local_point.y / cell_size) + 0.5
	)
	print("Коллайдер: ", collider.name, " | локальная точка: ", local_point, " | ячейка: ", cell)
