extends System
class_name TargetAimingSystem

func query() -> QueryBuilder:
	return q.with_all([C_Target, C_AngularVelocity, C_RigidBody])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	const TURN_SPEED = 20
	const EPSILON = 0.2  # допуск в радианах (~10°)

	for entity in entities:
		var angle_diff = _calculate_angle_to_target(entity)
		if abs(angle_diff) < EPSILON:
			entity.get_component(C_AngularVelocity).value = 0.0
		else:
			entity.get_component(C_AngularVelocity).value = TURN_SPEED * sign(angle_diff)

func _calculate_angle_to_target(source: Entity) -> float:
	var target_comp = source.get_component(C_Target)
	if not target_comp or target_comp.value[0] == null:
		return 0.0

	var target = target_comp.value[0]
	if not is_instance_valid(target):
		return 0.0

	var source_pos = source.get_component(C_Position)
	var target_pos = target.get_component(C_Position)
	var rigid = source.get_component(C_RigidBody)
	if not source_pos or not target_pos or not rigid or not rigid.node:
		return 0.0

	var dir = target_pos.value - source_pos.value
	var target_angle = dir.angle()
	var current_angle = rigid.node[0].rotation - PI/2
	var diff = fmod(target_angle - current_angle, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff
