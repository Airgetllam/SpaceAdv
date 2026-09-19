extends System
class_name ParamsSyncSystem

var hp_colors: Dictionary = ServerConfig.HP_COLORS

func query() -> QueryBuilder:
	return q.with_all([C_StateChanged, C_Blocks])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var blocks: C_Blocks = entity.get_component(C_Blocks)
		var block_changed: C_StateChanged = entity.get_component(C_StateChanged)
		var hp: C_HP = entity.get_component(C_HP)
		var ammo: C_Ammo = entity.get_component(C_Ammo)
		if not blocks or not block_changed:
			continue

		for i in block_changed.list:
			var block = blocks.blocks_map[i]

			# 1. Применяем урон
			var damage_before = block.block_hp
			block.block_hp -= block_changed.damage
			if block.block_hp <= 0:
				block.block_hp = 0
				block.destroy = true

			# 2. Обновляем цвет блока
			var color = hp_colors[_get_hp_percent(block.block_hp, block.block_hp_max)]
			block.mmi.multimesh.set_instance_color(block.block_index, color)

			# 3. Списываем разницу в HP компонент
			var actual_damage = damage_before - block.block_hp
			hp.value -= actual_damage
			
			# 4. Меняем количество снарядов, если нужно
			if block.block_id == 2 and block.destroy:
				ammo.value -= 1
		cmd.remove_component(entity, C_StateChanged)

func _get_hp_percent(value: int, _max: int) -> int:
	var percent = int(round(float(value) / _max * 10)) * 10
	return clamp(percent, 0, 100)
