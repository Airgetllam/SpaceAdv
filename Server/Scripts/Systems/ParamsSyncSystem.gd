extends System
class_name ParamsSyncSystem

var hp_colors: Dictionary = ServerConfig.HP_COLORS

func query() -> QueryBuilder:
	return q.with_all([C_StateChanged, C_Blocks])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var blocks: C_Blocks = entity.get_component(C_Blocks)
		var block_changed: C_StateChanged = entity.get_component(C_StateChanged)
		
		for i in block_changed.list:
			var block = blocks.blocks_map[i]
			var color = hp_colors[_get_hp_percent(block.block_hp, block.block_hp_max)]
			block.mmi.multimesh.set_instance_color(block.block_index, color)

func _get_hp_percent(value: int, _max: int) -> int:
	var percent = int(round(float(value)/_max * 10)) * 10
	return clamp(percent, 0, 100)
