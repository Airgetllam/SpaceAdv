extends System
class_name ForceApplySystem

func query() -> QueryBuilder:
	return q.with_all([C_RigidBody, C_Force])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		var force: C_Force = entity.get_component(C_Force)
		
		var direction = Vector2.UP.rotated(body.node[0].global_rotation)
		var force_val = force.value
		
		body.node[0].apply_central_force(direction * force_val)
