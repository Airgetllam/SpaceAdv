extends System
class_name TargetAimingSystem

func query() -> QueryBuilder:
	return q.with_all([C_Target, C_Velocity, C_Position, C_HomingParams])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var pos: C_Position = entity.get_component(C_Position)
		var vel: C_Velocity = entity.get_component(C_Velocity)
		var params: C_HomingParams = entity.get_component(C_HomingParams)
		if not pos or not vel or not params:
			continue

		# Инициализация начальной скорости
		if vel.value == Vector2.ZERO:
			var dir_comp: C_Direction = entity.get_component(C_Direction)
			var initial_deg = dir_comp.value if dir_comp else 0.0
			var initial_rad = deg_to_rad(initial_deg) - PI / 2.0
			vel.value = Vector2.from_angle(initial_rad) * params.speed
			continue

		var target_comp: C_Target = entity.get_component(C_Target)
		if not target_comp or target_comp.value.is_empty():
			continue

		var target = target_comp.value[0]
		if not is_instance_valid(target):
			continue

		# Ищем ближайший живой блок у цели. Если его нет — наводимся на позицию цели.
		var aim_point = _get_aim_point(target, pos.value)
		if aim_point == null:
			continue

		# Желаемое направление на цель
		var desired_dir = (aim_point - pos.value).normalized()

		var current_dir = vel.value.normalized()
		var current_angle = current_dir.angle()
		var desired_angle = desired_dir.angle()
		var diff = wrapf(desired_angle - current_angle, -PI, PI)

		var max_turn = params.turn_rate * delta
		var turn = clamp(diff, -max_turn, max_turn)

		var new_dir = Vector2.from_angle(current_angle + turn)
		vel.value = new_dir * params.speed

# Возвращает мировую точку для наведения: ближайший живой блок, либо центр цели.
func _get_aim_point(target: Entity, from_pos: Vector2) -> Variant:
	var blocks: C_Blocks = target.get_component(C_Blocks)
	var rigid: C_RigidBody = target.get_component(C_RigidBody)

	# Если у цели нет блоков — наводимся на её позицию
	if not blocks or not rigid or not rigid.node:
		var tpos: C_Position = target.get_component(C_Position)
		@warning_ignore("incompatible_ternary")
		return tpos.value if tpos else null

	var body = rigid.node[0]
	var cell_size = ServerConfig.CELL_SIZE

	var nearest_pos = null
	var nearest_dist = INF

	for key in blocks.blocks_map.keys():
		var block = blocks.blocks_map[key]
		if block.destroy:
			continue
		# Мировая позиция центра блока
		var world_pos = body.to_global(Vector2(key.x * cell_size, key.y * cell_size))
		var dist = from_pos.distance_squared_to(world_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = world_pos

	# Если все блоки уничтожены — наводимся на центр цели
	if nearest_pos == null:
		var tpos: C_Position = target.get_component(C_Position)
		@warning_ignore("incompatible_ternary")
		return tpos.value if tpos else null

	return nearest_pos
