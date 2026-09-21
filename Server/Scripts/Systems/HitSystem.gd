extends System
class_name HitSystem

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
		if exist.value == 0:
			continue

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

			# Пропускаем, если цель принадлежит нам
			if _is_owned_by(target, entity):
				continue

			var blocks: C_Blocks = target.get_component(C_Blocks)
			var rigid: C_RigidBody = target.get_component(C_RigidBody)
			if not blocks or not rigid or not rigid.node:
				continue

			var local_pos = rigid.node[0].to_local(pos.value)
			var key = _local_to_block_key(local_pos)

			if not blocks.blocks_map.has(key):
				continue
			if blocks.blocks_map[key].destroy:
				continue

			exist.value = 0
			break

func _local_to_block_key(local_pos: Vector2) -> Vector2:
	var cell_size = ServerConfig.CELL_SIZE
	return Vector2(
		floor(local_pos.x / cell_size - 0.5) + 0.5,
		floor(local_pos.y / cell_size - 0.5) + 0.5
	)

# Возвращает true, если target имеет C_Owner и entity входит в список владельцев
# Возвращает true, если цель принадлежит владельцу снаряда
func _is_owned_by(target: Entity, projectile: Entity) -> bool:
	var owner_comp: C_Owner = projectile.get_component(C_Owner)
	if not owner_comp:
		return false
	for _owner in owner_comp.value:
		if _owner == target:
			return true
	return false
