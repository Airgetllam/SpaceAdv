extends System
class_name PositionSyncSystem


func query() -> QueryBuilder:
	return q.with_all([C_Position, C_RigidBody])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		var pos: C_Position = entity.get_component(C_Position)
		
		pos.value = body.node[0].global_position
