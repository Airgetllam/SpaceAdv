extends Observer
class_name RenderInitObserver

func query() -> QueryBuilder:
	return q.with_all([C_Multimesh]).on_added()


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var definition: C_Multimesh = entity.get_component(C_Multimesh)
	var polygon = _remove_collinear_points(_get_outline_points(definition.all_blocks))
	var body: C_RigidBody = entity.get_component(C_RigidBody)
	var parent = get_tree().current_scene.get_node('World/Ships')
	var ship = body.node[0]
	for i in definition.multlimesh:
		ship.add_child(definition.multlimesh[i])
	parent.add_child(ship)
	cmd.add_component(entity, C_Blocks.new(definition.blocks_map))
	cmd.add_component(entity, C_Collider.new(polygon))
	
	print('[RenderInitObserver] C_Blocks, C_Collider были добавлены к сущности c ID ', entity.id)
 

func _get_outline_points(all_blocks: Array) -> Array[Vector2]:
	var cell_size = ServerConfig.CELL_SIZE
	var occupied: Dictionary = {}
	for block in all_blocks:
		var pos: Vector2 = Vector2(block["local_pos"])
		occupied[pos] = true
	var edges: Dictionary = {}
	for cell in occupied.keys():
		var x = cell.x
		var y = cell.y
		if not occupied.has(Vector2(x, y - 1)):
			var start = Vector2(x, y)
			var end = Vector2(x + 1, y)
			edges[start] = end
		if not occupied.has(Vector2(x + 1, y)):
			var start = Vector2(x + 1, y)
			var end = Vector2(x + 1, y + 1)
			edges[start] = end
		if not occupied.has(Vector2(x, y + 1)):
			var start = Vector2(x + 1, y + 1)
			var end = Vector2(x, y + 1)
			edges[start] = end
		if not occupied.has(Vector2(x - 1, y)):
			var start = Vector2(x, y + 1)
			var end = Vector2(x, y)
			edges[start] = end
	if edges.is_empty():
		return []
	var start_point: Vector2 = edges.keys()[0]
	for v in edges.keys():
		if v.x < start_point.x or (v.x == start_point.x and v.y < start_point.y):
			start_point = v
	var point: Vector2 = start_point 
	var outline: Array[Vector2] = [point * cell_size]
	while true:
		point = edges[point]
		if point == start_point:
			break
		outline.append(point * cell_size)
	return outline


func _remove_collinear_points(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() < 3:
		return points
	var is_closed := false
	if points[0] == points[-1]:
		is_closed = true
		points = points.slice(0, -1)
		if points.size() < 3:
			points.append(points[0])
			return points
	var filtered: Array[Vector2] = []
	var n = points.size()
	for i in range(n):
		var prev = points[(i - 1 + n) % n]
		var curr = points[i]
		var next = points[(i + 1) % n]
		if not _is_collinear(prev, curr, next):
			filtered.append(curr)
	if is_closed and not filtered.is_empty():
		if filtered[0] != filtered[-1]:
			filtered.append(filtered[0])
		else:
			pass
	return filtered


func _is_collinear(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) == 0
