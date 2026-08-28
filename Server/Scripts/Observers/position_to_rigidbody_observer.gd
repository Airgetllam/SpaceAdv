extends Observer
class_name PositionToRigidbodyObserver

func query() -> QueryBuilder:
	return q.with_all([C_Position, C_RigidBody]).on_changed([&"value"])

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
		if body.node:
			body.node.global_position = payload.new_value
		print('[PositionToRigidbodyObserver] ID', entity.id, ' перемещен на: ', payload.new_value)
