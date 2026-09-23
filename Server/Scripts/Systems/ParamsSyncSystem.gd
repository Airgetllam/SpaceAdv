extends System
class_name ParamsSyncSystem

var hp_colors: Dictionary = ServerConfig.HP_COLORS

func query() -> QueryBuilder:
	return q.with_all([C_StateChanged, C_Blocks])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var blocks: C_Blocks = entity.get_component(C_Blocks)
		var block_changed: C_StateChanged = entity.get_component(C_StateChanged)
		var hp: C_HP = entity.get_component(C_HP)
		var ammo: C_Ammo = entity.get_component(C_Ammo)
		if not blocks or not block_changed:
			continue

		var changed_keys: Array = []
		for i in block_changed.list:
			var block = blocks.blocks_map[i]

			var damage_before = block.block_hp
			block.block_hp -= block_changed.damage
			if block.block_hp <= 0:
				block.block_hp = 0
				block.destroy = true

			var color = hp_colors[_get_hp_percent(block.block_hp, block.block_hp_max)]
			block.mmi.multimesh.set_instance_color(block.block_index, color)

			var actual_damage = damage_before - block.block_hp
			hp.value -= actual_damage

			if block.block_id == 2 and block.destroy:
				ammo.value -= 1

			changed_keys.append({ "key": i, "hp": block.block_hp })

		# Рассылаем MSG_BLOCK_HP всем пирам в AOI корабля
		if not changed_keys.is_empty():
			_broadcast_block_hp(entity, changed_keys)

		cmd.remove_component(entity, C_StateChanged)


func _broadcast_block_hp(entity: Entity, changes: Array) -> void:
	var nid_c: C_NetId = entity.get_component(C_NetId)
	if nid_c == null:
		return
	var server := C_ServerIP.instance
	if server == null:
		return

	var body := StreamPeerBuffer.new()
	body.put_u16(nid_c.value)
	body.put_u16(changes.size())
	for c in changes:
		var kv: Vector2 = c["key"]
		body.put_float(kv.x)
		body.put_float(kv.y)
		body.put_u16(c["hp"])

	for ps in server.peers.values():
		if ps.visible_net_ids.has(nid_c.value):
			ps.queue_reliable(NetProtocol.MSG_BLOCK_HP, body.data_array)


func _get_hp_percent(value: int, _max: int) -> int:
	if _max <= 0:
		return 0
	var percent = int(round(float(value) / _max * 10)) * 10
	return clamp(percent, 0, 100)
