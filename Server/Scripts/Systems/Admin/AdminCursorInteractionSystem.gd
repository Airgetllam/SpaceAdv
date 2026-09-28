extends System
class_name AdminCursorInteractionSystem

var hover_map: Dictionary = {}
var mouse_was_pressed: bool = false


func query() -> QueryBuilder:
	return q.with_all([
		C_ServerIP,
		C_CursorPosition,
		C_Targets,
	])


func process(
	entities: Array[Entity],
	_components: Array,
	_delta: float
) -> void:
	var root = Engine.get_main_loop().root

	if not root:
		return

	var world_2d = root.get_world_2d()

	if world_2d == null:
		return

	var space_state = world_2d.direct_space_state

	if space_state == null:
		return

	var mouse_pressed_now := Input.is_mouse_button_pressed(
		MOUSE_BUTTON_LEFT
	)

	var click_just_pressed := (
		mouse_pressed_now
		and not mouse_was_pressed
	)

	mouse_was_pressed = mouse_pressed_now

	for entity in entities:
		var cursor: C_CursorPosition = (
			entity.get_component(C_CursorPosition)
		)

		var targets: C_Targets = (
			entity.get_component(C_Targets)
		)

		if cursor == null or targets == null:
			continue

		_clean_dead_targets(targets)

		var params := PhysicsPointQueryParameters2D.new()

		params.position = cursor.position
		params.collide_with_areas = true
		params.collide_with_bodies = true

		var results = space_state.intersect_point(params)

		var new_hover_entity: Entity = null

		if results:
			var collider = results[0].collider

			if collider.has_meta("entity"):
				var possible_target = (
					collider.get_meta("entity")
				)

				if (
					possible_target is Entity
					and possible_target != entity
					and _is_entity_valid(possible_target)
				):
					new_hover_entity = possible_target

		var old_hover_entity = hover_map.get(
			entity,
			null
		)

		if (
			old_hover_entity != null
			and not _is_entity_valid(old_hover_entity)
		):
			hover_map.erase(entity)
			old_hover_entity = null

		if old_hover_entity != new_hover_entity:
			if old_hover_entity != null:
				var old_index := _find_target_index(
					targets,
					old_hover_entity
				)

				if old_index >= 0:
					var old_dict = targets.list[old_index]

					if old_dict["state"] == 0:
						targets.list.remove_at(old_index)

			if new_hover_entity != null:
				var new_index := _find_target_index(
					targets,
					new_hover_entity
				)

				if new_index == -1:
					targets.list.append({
						"state": 0,
						"entity": new_hover_entity,
					})

			hover_map[entity] = new_hover_entity

		if click_just_pressed:
			if new_hover_entity != null:
				var index := _find_target_index(
					targets,
					new_hover_entity
				)

				if index >= 0:
					var target_dict = targets.list[index]

					if target_dict["state"] == 1:
						target_dict["state"] = 0
					else:
						target_dict["state"] = 1
				else:
					targets.list.append({
						"state": 1,
						"entity": new_hover_entity,
					})
			else:
				for i in range(
					targets.list.size() - 1,
					-1,
					-1
				):
					var target_dict = targets.list[i]

					if target_dict["state"] == 1:
						targets.list.remove_at(i)


func _is_entity_valid(entity) -> bool:
	if entity == null:
		return false

	if not is_instance_valid(entity):
		return false

	if not (entity is Entity):
		return false

	return true


func _clean_dead_targets(
	targets: C_Targets
) -> void:
	for i in range(
		targets.list.size() - 1,
		-1,
		-1
	):
		var target_entity = (
			targets.list[i]["entity"]
		)

		if not _is_entity_valid(target_entity):
			targets.list.remove_at(i)


func _find_target_index(
	targets: C_Targets,
	entity: Entity
) -> int:
	for i in range(targets.list.size()):
		if targets.list[i]["entity"] == entity:
			return i

	return -1
