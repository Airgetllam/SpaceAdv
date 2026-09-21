class_name AOISystem
extends System
## Раз в серверный тик (20 Гц) считает для каждого пира множество видимых
## сущностей (в радиусе AOI_RADIUS от его корабля) и формирует
## MSG_SPAWN / MSG_DESPAWN в надёжную очередь пира.

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var server := C_ServerIP.instance
	if server == null or server.peers.is_empty():
		return

	var aoi_sq: float = NetConfig.AOI_RADIUS * NetConfig.AOI_RADIUS

	# Собираем готовые сущности один раз за тик.
	# ВАЖНО: `e` — без типа (Entity), иначе assign из Dictionary
	# на освобождённом объекте кидает "Trying to assign invalid …".
	var ready: Array = []   # [ { net_id:int, pos:Vector2 } ]
	for nid in server.net_id_to_entity.keys():
		var e = server.net_id_to_entity.get(nid)
		if not _is_ready(e):
			continue
		var pc = e.get_component(C_Position)
		if pc == null:
			continue
		ready.append({ "net_id": nid, "pos": pc.value })

	for ps in server.peers.values():
		if ps.net_id == 0:
			continue
		var mine = server.get_entity(ps.net_id)
		if not _is_ready(mine):
			continue
		var my_pc = mine.get_component(C_Position)
		if my_pc == null:
			continue
		var my_pos: Vector2 = my_pc.value

		var current_visible: Dictionary = {}
		for rec in ready:
			var other_pos: Vector2 = rec.pos
			if my_pos.distance_squared_to(other_pos) <= aoi_sq:
				current_visible[rec.net_id] = true

		# Вход в AOI → SPAWN
		for nid in current_visible.keys():
			if not ps.visible_net_ids.has(nid):
				_queue_spawn(server, ps, nid)
				ps.last_sent_state.erase(nid)
		# Выход из AOI → DESPAWN
		for nid in ps.visible_net_ids.keys():
			if not current_visible.has(nid):
				_queue_despawn(ps, nid)
				ps.last_sent_state.erase(nid)

		ps.visible_net_ids = current_visible


## Возвращает true только когда сущность полностью собрана
## observer-цепочкой и готова к SPAWN.
func _is_ready(entity) -> bool:
	if not is_instance_valid(entity):
		return false
	if not entity.has_component(C_Position):
		return false
	var et = entity.get_component(C_EntityType)
	if et == null:
		return false
	match et.value:
		"user":
			return entity.has_component(C_Blocks)
		"projectile":
			return entity.has_component(C_Velocity)
	return false


func _queue_despawn(ps: PeerState, net_id: int) -> void:
	var body := StreamPeerBuffer.new()
	body.put_u16(net_id)
	ps.queue_reliable(NetProtocol.MSG_DESPAWN, body.data_array)
	NetLog.d("aoi", "DESPAWN net_id=%d → peer %d" % [net_id, ps.net_id])


func _queue_spawn(server: C_ServerIP, ps: PeerState, net_id: int) -> void:
	var entity = server.get_entity(net_id)
	if not is_instance_valid(entity):
		return
	var payload := _build_spawn_payload(server, ps, entity, net_id)
	if payload.is_empty():
		return
	ps.queue_reliable(NetProtocol.MSG_SPAWN, payload)
	NetLog.d("aoi", "SPAWN net_id=%d → peer %d (owner=%s) blocks=%d" % [
		net_id, ps.net_id, str(net_id == ps.net_id), _block_count(entity)
	])


func _block_count(entity) -> int:
	var b = entity.get_component(C_Blocks)
	return b.blocks_map.size() if b else 0


func _build_spawn_payload(server: C_ServerIP, viewer: PeerState,
		entity: Entity, net_id: int) -> PackedByteArray:
	var etype: C_EntityType = entity.get_component(C_EntityType)
	if etype == null:
		return PackedByteArray()

	var kind: int = 1 if etype.value == "user" else 2

	var body := StreamPeerBuffer.new()
	body.put_u16(net_id)
	body.put_u8(kind)

	# owner_net_id (uint16, отклонение от спеки)
	var owner_net_id := 0
	var owner_c: C_Owner = entity.get_component(C_Owner)
	if owner_c and not owner_c.value.is_empty():
		owner_net_id = server.entity_to_net_id.get(owner_c.value[0], 0)
	body.put_u16(owner_net_id)

	# Позиция / поворот
	var pos_c: C_Position = entity.get_component(C_Position)
	var pos: Vector2 = pos_c.value if pos_c else Vector2.ZERO
	body.put_float(pos.x)
	body.put_float(pos.y)

	var dir_c: C_Direction = entity.get_component(C_Direction)
	var rot_deg: float = dir_c.value if dir_c else 0.0
	body.put_u16(NetProtocol.quant_rot(deg_to_rad(rot_deg)))

	# HP
	var hp_c: C_HP = entity.get_component(C_HP)
	var hp: int = hp_c.value if hp_c else 0
	var hp_max: int = hp_c.value_max if hp_c else 0
	body.put_u16(hp)
	body.put_u16(hp_max)

	# Размер
	var size_c: C_Size = entity.get_component(C_Size)
	var size: Vector2 = size_c.value if size_c else Vector2.ZERO
	body.put_u16(int(size.x))
	body.put_u16(int(size.y))

	# Блоки
	var blocks_c: C_Blocks = entity.get_component(C_Blocks)
	var block_count: int = blocks_c.blocks_map.size() if blocks_c else 0
	body.put_u16(block_count)

	if block_count == 0:
		return body.data_array

	var is_owner := (net_id == viewer.net_id)
	if is_owner:
		# Полный список блоков
		for key in blocks_c.blocks_map.keys():
			var b: Dictionary = blocks_c.blocks_map[key]
			var kv: Vector2 = key
			body.put_float(kv.x)
			body.put_float(kv.y)
			body.put_u8(int(b.get("block_id", 0)))
			body.put_u16(int(b.get("block_hp", 0)))
	else:
		# Битовая маска живых блоков
		var mask_bytes := int(ceil(float(block_count) / 8.0))
		var mask := PackedByteArray()
		mask.resize(mask_bytes)
		var idx := 0
		for key in blocks_c.blocks_map.keys():
			var b: Dictionary = blocks_c.blocks_map[key]
			var alive := not bool(b.get("destroy", false))
			if alive:
				mask[idx >> 3] |= (1 << (idx & 7))
			idx += 1
		body.put_data(mask)

	return body.data_array
