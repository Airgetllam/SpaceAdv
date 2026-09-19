extends System
class_name DamageControlSystem

func query() -> QueryBuilder:
	return q.with_all([C_Blocks, C_DamagedBlock])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var blocks: C_Blocks = entity.get_component(C_Blocks)
		var damaged_block: C_DamagedBlock = entity.get_component(C_DamagedBlock)
		if not blocks or not damaged_block:
			continue

		# Преобразуем локальные пиксельные координаты в ключи blocks_map
		var keys_to_process: Array[Vector2] = []
		for local_pos in damaged_block.block_pos:
			var key = _local_to_block_key(local_pos)
			if blocks.blocks_map.has(key):
				keys_to_process.append(key)
			else:
				print("Ключ не найден: ", key, " для позиции ", local_pos)

		# Применяем урон к найденным блокам
		for key in keys_to_process:
			var block_params = blocks.blocks_map[key]
			block_params.block_hp -= damaged_block.value
			if block_params.block_hp <= 0:
				block_params.block_hp = 0
				block_params.destroy = true

		# Передаём в C_StateChanged именно ключи ячеек, которые были затронуты
		if not keys_to_process.is_empty():
			cmd.add_component(entity, C_StateChanged.new(keys_to_process))
		# Убираем компонент урона
		cmd.remove_component(entity, C_DamagedBlock)

# Преобразует локальную позицию (в пикселях) в ключ blocks_map.
func _local_to_block_key(local_pos: Vector2) -> Vector2:
	var cell_size = ServerConfig.CELL_SIZE
	return Vector2(
		floor(local_pos.x / cell_size - 0.5) + 0.5,
		floor(local_pos.y / cell_size - 0.5) + 0.5
	)
