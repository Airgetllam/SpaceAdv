extends System
class_name DamageControlSystem

func query() -> QueryBuilder:
	return q.with_all([C_Blocks, C_DamagedBlock])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var blocks: C_Blocks = entity.get_component(C_Blocks)
		var damaged_block: C_DamagedBlock = entity.get_component(C_DamagedBlock)
		for i in damaged_block.block_pos:
			var block_params = blocks.blocks_map.get(i)
			block_params.block_hp -= damaged_block.value
			if block_params.block_hp <= 0:
				block_params.destroy = true
				block_params.block_hp = 0
		cmd.add_component(entity, C_StateChanged.new(damaged_block.block_pos))
		
		#TODO: C_StateChanged обрабатывать другой системой
		
		cmd.remove_component(entity, C_DamagedBlock)
