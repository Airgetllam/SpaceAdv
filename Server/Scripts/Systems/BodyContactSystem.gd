extends System
class_name BodyContactSystem

func query() -> QueryBuilder:
	return q.with_all([C_Contact])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var contact: C_Contact = entity.get_component(C_Contact)
		var entity_type: C_EntityType = entity.get_component(C_EntityType)
		if contact.active:
			if entity_type.value == 'projectile':
				pass
			if entity_type.value == 'user':
				pass


func point_to_local(entity: Entity, global_point: Vector2) -> Vector2:
	var rigid: C_RigidBody = entity.get_component(C_RigidBody)
	if not rigid:
		return global_point
	return rigid.node[0].to_local(global_point)
