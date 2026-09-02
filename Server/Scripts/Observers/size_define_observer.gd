extends Observer
class_name SizeDefineObserver

func query() -> QueryBuilder:
	return q.with_all([C_Collider]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var collider: C_Collider = entity.get_component(C_Collider)
	if collider == null or collider.polygon.is_empty():
		return
	
	# Вычисление ограничивающего прямоугольника (bounding box)
	var min_x: float = collider.polygon[0].x
	var max_x: float = collider.polygon[0].x
	var min_y: float = collider.polygon[0].y
	var max_y: float = collider.polygon[0].y
	
	for point in collider.polygon:
		if point.x < min_x:
			min_x = point.x
		if point.x > max_x:
			max_x = point.x
		if point.y < min_y:
			min_y = point.y
		if point.y > max_y:
			max_y = point.y
	
	var size := Vector2(max_x - min_x, max_y - min_y)
	
	var size_comp := C_Size.new()
	size_comp.value = size
	cmd.add_component(entity, size_comp)
