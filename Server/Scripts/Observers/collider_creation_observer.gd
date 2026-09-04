extends Observer
class_name ColliderCreationObserver

func query() -> QueryBuilder:
	return q.with_all([C_Collider]).on_added()


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var collider: C_Collider = entity.get_component(C_Collider)
	var body: C_RigidBody = entity.get_component(C_RigidBody)
	var new_collider = CollisionPolygon2D.new()
	var ship = body.node[0]
	new_collider.polygon = collider.polygon
	ship.add_child(new_collider)
	print('[ColliderCreationObserver] collider был добавлен к сущности с ID ', entity.id)
