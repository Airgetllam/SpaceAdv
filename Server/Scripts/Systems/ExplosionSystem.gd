extends System
class_name ExplosionSystem

func query() -> QueryBuilder:
	return q.with_all([C_Position, C_Damage, C_ExistenceState])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var root = Engine.get_main_loop().root
	if not root:
		return
	var space = root.get_world_2d().direct_space_state
	if not space:
		return

	for entity in entities:
		var pos: C_Position = entity.get_component(C_Position)
		var damage: C_Damage = entity.get_component(C_Damage)
		var exist: C_ExistenceState = entity.get_component(C_ExistenceState)
		if not pos or not damage or not exist:
			continue
		if exist.value != 0:
			continue
		if damage.exploded:
			continue
		damage.exploded = true

		var params = PhysicsPointQueryParameters2D.new()
		params.position = pos.value
		params.collide_with_bodies = true
		params.collide_with_areas = false

		var results = space.intersect_point(params)
		if results.is_empty():
			continue

		for hit in results:
			var collider = hit.collider
			if not (collider is Node):
				continue
			if not collider.has_meta("entity"):
				continue

			var target = collider.get_meta("entity")
			if not is_instance_valid(target) or target == entity:
				continue

			var blocks: C_Blocks = target.get_component(C_Blocks)
			var rigid: C_RigidBody = target.get_component(C_RigidBody)
			if not blocks or not rigid or not rigid.node:
				continue

			var local_pos = rigid.node[0].to_local(pos.value)
			var center_key = _local_to_block_key(local_pos)

			var affected: Array[Vector2] = []

			if damage.radius > 0.0:
				for key in blocks.blocks_map.keys():
					var block = blocks.blocks_map[key]
					if block.destroy:
						continue
					if Vector2(key).distance_to(center_key) <= damage.radius:
						affected.append(key)
			else:
				if blocks.blocks_map.has(center_key) and not blocks.blocks_map[center_key].destroy:
					affected.append(center_key)

			if affected.is_empty():
				continue

			# Передаём список блоков и урон — ParamsSyncSystem всё сделает
			cmd.add_component(target, C_StateChanged.new(affected, damage.value))
			break

func _local_to_block_key(local_pos: Vector2) -> Vector2:
	var cell_size = ServerConfig.CELL_SIZE
	return Vector2(
		floor(local_pos.x / cell_size - 0.5) + 0.5,
		floor(local_pos.y / cell_size - 0.5) + 0.5
	)
