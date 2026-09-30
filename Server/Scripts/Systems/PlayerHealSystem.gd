extends System
class_name PlayerHealSystem


func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_PlayerInputState, C_Blocks, C_HP])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var input_state: C_PlayerInputState = entity.get_component(C_PlayerInputState)
		var blocks: C_Blocks = entity.get_component(C_Blocks)
		var hp: C_HP = entity.get_component(C_HP)

		if (input_state == null or blocks == null or hp == null):
			continue

		var heal_requested := false

		# FULL_HEAL — дискретное действие.
		for i in range(input_state.pending_events.size() - 1, -1, -1):
			var event: PlayerInputAction = (input_state.pending_events[i])

			if event.action_id != InputActions.FULL_HEAL:
				continue

			if (event.state == PlayerInputAction.State.PRESSED):
				heal_requested = true

			# Система полностью consume'ит своё действие.
			input_state.pending_events.remove_at(i)

		if not heal_requested:
			continue

		_full_heal(entity, blocks, hp)


func _full_heal(entity: Entity, blocks: C_Blocks, hp: C_HP) -> void:
	var changed_keys: Array = []

	for key in blocks.blocks_map:
		var block = blocks.blocks_map[key]
		if (block.block_hp == block.block_hp_max and not block.destroy):
			continue
		block.block_hp = block.block_hp_max
		block.destroy = false
		changed_keys.append(key)

	# C_HP является агрегированным HP корабля.
	hp.value = hp.value_max
	if not changed_keys.is_empty():
		# ParamsSyncSystem уже умеет:
		# - обновлять server MultiMesh;
		# - рассылать block HP клиентам;
		# - использовать существующий MSG_BLOCK_HP.
		#
		# damage=0, потому что абсолютные значения HP
		# уже восстановлены выше.
		cmd.add_component(entity, C_StateChanged.new(changed_keys, 0))

	var net_id := 0
	var net_id_component: C_NetId = entity.get_component(C_NetId)

	if net_id_component != null:
		net_id = net_id_component.value

	NetLog.d(
		"heal",
		"full heal net_id=%d hp=%d/%d blocks=%d" % [
			net_id,
			hp.value,
			hp.value_max,
			changed_keys.size(),
		]
	)
