extends System
class_name TargetAimingSystem

func query() -> QueryBuilder:
	return q.with_all([C_Target, C_Velocity, C_Position, C_HomingParams])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var pos: C_Position = entity.get_component(C_Position)
		var vel: C_Velocity = entity.get_component(C_Velocity)
		var params: C_HomingParams = entity.get_component(C_HomingParams)

		if vel.value == Vector2.ZERO:
			var dir_comp: C_Direction = entity.get_component(C_Direction)
			var initial_angle = dir_comp.value if dir_comp else 0
			vel.value = Vector2.from_angle(initial_angle - PI/2.0) * params.speed
			continue

		var target_comp: C_Target = entity.get_component(C_Target)
		if not target_comp or target_comp.value.is_empty():
			continue

		var target = target_comp.value[0]
		if not is_instance_valid(target):
			continue

		if not pos or not vel or not params:
			continue

		var target_pos: C_Position = target.get_component(C_Position)
		if not target_pos:
			continue

		# 1. Желаемое направление на цель
		var desired_dir = (target_pos.value - pos.value).normalized()

		# 2. Текущее направление скорости
		var current_dir = vel.value.normalized()

		# 3. Ограниченный поворот текущего направления к желаемому
		var current_angle = current_dir.angle()
		var desired_angle = desired_dir.angle()
		var diff = wrapf(desired_angle - current_angle, -PI, PI)

		var max_turn = params.turn_rate * delta
		var turn = clamp(diff, -max_turn, max_turn)

		var new_dir = Vector2.from_angle(current_angle + turn)

		# 4. Обновляем скорость (сохраняем длину)
		vel.value = new_dir * params.speed
