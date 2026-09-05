extends Observer
class_name ColliderCreationObserver

func query() -> QueryBuilder:
	return q.with_all([C_Collider]).on_added()


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var entity_type: C_EntityType = entity.get_component(C_EntityType)
	var collider: C_Collider = entity.get_component(C_Collider)
	var body: C_RigidBody = entity.get_component(C_RigidBody)
	var rig = body.node[0]
	var new_collider: Node2D
	if entity_type.value == 'user':
		new_collider = CollisionPolygon2D.new()
		new_collider.polygon = collider.polygon
		rig.add_child(new_collider)
	elif entity_type.value == 'projectile':
		new_collider = CollisionShape2D.new()
		new_collider.shape = CapsuleShape2D.new()
		new_collider.shape.radius = collider.polygon[0].x
		new_collider.shape.height = collider.polygon[0].y
		rig.add_child(new_collider)
	print('[ColliderCreationObserver] collider был добавлен к сущности с ID ', entity.id)
