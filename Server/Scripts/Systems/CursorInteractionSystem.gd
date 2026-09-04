extends System
class_name CursorInteractionSystem

var hover_map: Dictionary = {}
var mouse_was_pressed: bool = false

func query() -> QueryBuilder:
	return q.with_all([C_CursorPosition, C_Targets])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var root = Engine.get_main_loop().root
	if not root:
		return

	var space_state = root.get_world_2d().direct_space_state
	if not space_state:
		return

	var mouse_pressed_now = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var click_just_pressed = mouse_pressed_now and not mouse_was_pressed
	mouse_was_pressed = mouse_pressed_now

	for entity in entities:
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		var targets: C_Targets = entity.get_component(C_Targets)
		if not cursor or not targets:
			continue

		# Очищаем targets.list от мёртвых сущностей
		_clean_dead_targets(targets)

		var params = PhysicsPointQueryParameters2D.new()
		params.position = cursor.position
		params.collide_with_areas = true
		params.collide_with_bodies = true
		var results = space_state.intersect_point(params)

		var new_hover_entity: Entity = null
		if results:
			var collider = results[0].collider
			if collider.has_meta("entity"):
				var possible_target = collider.get_meta("entity")
				if possible_target is Entity and possible_target != entity and _is_entity_valid(possible_target):
					new_hover_entity = possible_target

		var old_hover_entity = hover_map.get(entity, null)
		if old_hover_entity != null and not _is_entity_valid(old_hover_entity):
			hover_map.erase(entity)
			old_hover_entity = null

		if old_hover_entity != new_hover_entity:
			if old_hover_entity != null:
				var idx = _find_target_index(targets, old_hover_entity)
				if idx >= 0:
					var dict = targets.list[idx]
					if dict['state'] == 0:
						targets.list.remove_at(idx)

			if new_hover_entity != null:
				var idx_new = _find_target_index(targets, new_hover_entity)
				if idx_new == -1:
					var new_dict = {'state': 0, 'entity': new_hover_entity}
					targets.list.append(new_dict)

			hover_map[entity] = new_hover_entity

		if click_just_pressed:
			if new_hover_entity != null:
				var idx = _find_target_index(targets, new_hover_entity)
				if idx >= 0:
					var dict = targets.list[idx]
					if dict['state'] == 1:
						dict['state'] = 0
					else:
						dict['state'] = 1
				else:
					var new_dict = {'state': 1, 'entity': new_hover_entity}
					targets.list.append(new_dict)
			else:
				for i in range(targets.list.size() - 1, -1, -1):
					var dict = targets.list[i]
					if dict['state'] == 1:
						targets.list.remove_at(i)

func _is_entity_valid(entity: Entity) -> bool:
	return entity != null and is_instance_valid(entity)

func _clean_dead_targets(targets: C_Targets) -> void:
	for i in range(targets.list.size() - 1, -1, -1):
		var target_entity = targets.list[i]['entity']
		if not _is_entity_valid(target_entity):
			targets.list.remove_at(i)

func _find_target_index(targets: C_Targets, entity: Entity) -> int:
	for i in range(targets.list.size()):
		if targets.list[i]['entity'] == entity:
			return i
	return -1
