extends Observer
class_name DirectionToRigidbodyObserver

func query() -> QueryBuilder:
	return q.with_all([C_Direction, C_RigidBody]).on_changed([&"value"])

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	if event == Observer.Event.CHANGED:
		# payload:
		# {
		#   "component": компонент C_Position,
		#   "property": "value",
		#   "new_value": новое значение,
		#   "old_value": старое значение
		# }
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		if body.node[0]:
			body.node[0].rotation_degrees = payload.new_value
