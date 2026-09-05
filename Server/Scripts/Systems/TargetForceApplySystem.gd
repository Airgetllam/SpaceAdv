extends System
class_name TargetForceApplySystem

func query() -> QueryBuilder:
	return q.with_all([C_Target, C_Force, C_RigidBody])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var force: C_Force = entity.get_component(C_Force)
		force.value = 5000
