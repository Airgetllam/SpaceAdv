extends System
class_name DirectionSyncSystem


func query() -> QueryBuilder:
	return q.with_all([C_Direction, C_RigidBody])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		var dir: C_Direction = entity.get_component(C_Direction)
		
		dir.value = body.node[0].rotation_degrees
