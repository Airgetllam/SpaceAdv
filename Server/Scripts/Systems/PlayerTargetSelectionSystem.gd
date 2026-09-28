extends System
class_name PlayerTargetSelectionSystem

func query() -> QueryBuilder:
	return q.with_all([
		C_PeerID,
		C_PlayerInputState,
		C_Targets,
	])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var input_state: C_PlayerInputState = (
			entity.get_component(C_PlayerInputState)
		)

		var targets: C_Targets = (
			entity.get_component(C_Targets)
		)

		if input_state == null or targets == null:
			continue

		if input_state.pending_events.is_empty():
			continue

		var selected_target: Entity = _get_selected_target(targets)
		var selection_changed := false

		for event in input_state.pending_events:
			if event.action_id != InputActions.TARGET_SELECT:
				continue

			if event.state != PlayerInputAction.State.PRESSED:
				continue

			var target := _find_target_at(
				entity,
				event.position
			)

			if target == selected_target:
				selected_target = null
			else:
				selected_target = target

			selection_changed = true

		if selection_changed:
			_apply_selection(
				entity,
				targets,
				selected_target
			)

		# События являются одноразовыми.
		input_state.pending_events.clear()


func _find_target_at(
	source_entity: Entity,
	position: Vector2
) -> Entity:
	var root = Engine.get_main_loop().root

	if not root:
		return null

	var world_2d = root.get_world_2d()

	if world_2d == null:
		return null

	var space_state = world_2d.direct_space_state

	if space_state == null:
		return null

	var params := PhysicsPointQueryParameters2D.new()

	params.position = position
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var results = space_state.intersect_point(params)

	for result in results:
		var collider = result.get("collider")

		if collider == null:
			continue

		if not (collider is Node2D):
			continue

		if not collider.has_meta("entity"):
			continue

		var possible_target = collider.get_meta("entity")

		if not (possible_target is Entity):
			continue

		var target: Entity = possible_target

		if target == source_entity:
			continue

		if not _is_entity_valid(target):
			continue

		return target

	return null


func _get_selected_target(
	targets: C_Targets
) -> Entity:
	for target_dict in targets.list:
		var state: int = target_dict.get("state", 0)

		if state != 1:
			continue

		var target = target_dict.get("entity", null)

		if target is Entity and _is_entity_valid(target):
			return target

	return null


func _apply_selection(
	entity: Entity,
	targets: C_Targets,
	target: Entity
) -> void:
	# C_Targets хранит текущий selected target
	# как состояние gameplay/UI.
	targets.list.clear()

	if target != null:
		targets.list.append({
			"state": 1,
			"entity": target,
		})

		# PlayerFireSystem уже использует C_Target
		# для наведения создаваемого projectile.
		cmd.add_component(
			entity,
			C_Target.new(target)
		)

		NetLog.d(
			"target",
			"selected source_net_id=%d target=%s" % [
				entity.get_component(C_NetId).value
				if entity.has_component(C_NetId)
				else 0,
				target.name,
			]
		)
	else:
		if entity.has_component(C_Target):
			cmd.remove_component(
				entity,
				C_Target
			)

		NetLog.d(
			"target",
			"cleared source_net_id=%d" % [
				entity.get_component(C_NetId).value
				if entity.has_component(C_NetId)
				else 0,
			]
		)


func _is_entity_valid(target: Entity) -> bool:
	if target == null:
		return false

	if not is_instance_valid(target):
		return false

	if not (target is Entity):
		return false

	return true
