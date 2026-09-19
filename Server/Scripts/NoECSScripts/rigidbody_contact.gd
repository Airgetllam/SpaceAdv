extends RigidBody2D

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var entity = get_meta("entity", null)
	if not entity or not (entity is Entity) or not is_instance_valid(entity):
		return

	var contact_comp = entity.get_component(C_Contact)
	if not contact_comp:
		contact_comp = C_Contact.new()
		entity.add_component(contact_comp)

	var count = state.get_contact_count()
	contact_comp.contact_count = count
	contact_comp.other_entity.clear()

	if count > 0:
		contact_comp.active = true
		for i in range(count):
			var point = state.get_contact_local_position(i)
			var normal = state.get_contact_local_normal(i)
			var collider = state.get_contact_collider_object(i)
			var global_point = to_global(point)

			# Проверяем, что коллайдер существует и валиден
			if collider != null and is_instance_valid(collider) and collider.has_meta("entity"):
				var other_entity = collider.get_meta("entity")
				if other_entity != null and is_instance_valid(other_entity) and other_entity is Entity:
					contact_comp.other_entity.append(other_entity)

			if i == 0:
				contact_comp.point = global_point
				contact_comp.normal = normal
	else:
		contact_comp.active = false
