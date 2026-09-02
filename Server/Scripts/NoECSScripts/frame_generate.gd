class_name FrameGenerator

static func generate_corner_points(corner_pos: Vector2, rotation_rad: float, size: float = 20.0) -> PackedVector2Array:
	var local_points := PackedVector2Array([
		Vector2(0, size),
		Vector2(0, 0),
		Vector2(size, 0)
	])
	var world_points := PackedVector2Array()
	for point in local_points:
		world_points.append(corner_pos + point.rotated(rotation_rad))
	return world_points

static func frame_generate(center: Vector2, _size: Vector2) -> Array:
	var max_dim: float = max(_size.x, _size.y)
	var half: Vector2 = Vector2(max_dim, max_dim) * 0.6
	var corner_size: float = 150.0

	var corners: Array = [
		generate_corner_points(center - half, 0.0, corner_size),
		generate_corner_points(center + Vector2(half.x, -half.y), PI/2.0, corner_size),
		generate_corner_points(center + half, PI, corner_size),
		generate_corner_points(center + Vector2(-half.x, half.y), 3*PI/2.0, corner_size)
	]
	return corners
