extends Observer
class_name ParamsGenerateObserver

func query() -> QueryBuilder:
	return q.with_all([C_Blocks]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var blocks_data: C_Blocks = entity.get_component(C_Blocks)
	var blocks_map = blocks_data.blocks_map
	var hp: int = 0
	var hp_max: int = 0
	var ammo: int = 0
	var ammo_full: int = 0
	for block in blocks_map:
		var block_params = blocks_map[block]
		hp += block_params.block_hp
		hp_max += block_params.block_hp_max
		if block_params.block_id == 5:
			ammo += 1
			ammo_full += 1
	cmd.add_component(entity, C_Ammo.new(ammo, ammo_full))
	cmd.add_component(entity, C_HP.new(hp, hp_max))
