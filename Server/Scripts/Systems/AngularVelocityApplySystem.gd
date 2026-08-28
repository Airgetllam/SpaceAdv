extends System
class_name AngularVelocityApplySystem

func query() -> QueryBuilder:
	return q.with_all([C_RigidBody, C_AngularVelocity])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		var angular_velocity: C_AngularVelocity = entity.get_component(C_AngularVelocity)

		body.node.angular_velocity = angular_velocity.value
