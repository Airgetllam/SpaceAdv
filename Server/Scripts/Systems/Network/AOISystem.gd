class_name AOISystem
extends System
## Раз в серверный тик (20 Гц) считает для каждого пира множество видимых
## сущностей (в радиусе AOI_RADIUS от его корабля) и формирует
## MSG_SPAWN / MSG_DESPAWN в надёжную очередь пира.

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	var server := C_ServerIP.instance
	if server == null or server.peers.is_empty():
		return

	server.aoi_tick += 1
	var cur_tick: int = server.aoi_tick
	var aoi_sq: float = NetConfig.AOI_RADIUS * NetConfig.AOI_RADIUS

	# Собираем готовые сущности один раз за тик.
	# ВАЖНО: `e` — без типа (Entity), иначе assign из Dictionary
	# на освобождённом объекте кидает "Trying to assign invalid …".
	var _ready: Array = []   # [ { net_id:int, pos:Vector2 } ]
	for nid in server.net_id_to_entity.keys():
		var e = server.net_id_to_entity.get(nid)
		if not _is_ready(e):
			continue
		var pc = e.get_component(C_Position)
		if pc == null:
			continue
		_ready.append({ "net_id": nid, "pos": pc.value })

	for ps in server.peers.values():
		if ps.net_id == 0:
			continue

		# Кэш видимости: обновляем не каждый тик, а раз в AOI_REFRESH_TICKS.
		# Между обновлениями ps.visible_net_ids остаётся прежним — MSG_STATE
		# продолжает слать тех же сущностей, SPAWN/DESPAWN не генерируются.
		if cur_tick - ps.last_aoi_tick < NetConfig.AOI_REFRESH_TICKS:
			continue
		ps.last_aoi_tick = cur_tick

		var mine = server.get_entity(ps.net_id)
		if not _is_ready(mine):
			continue
		var my_pc = mine.get_component(C_Position)
		if my_pc == null:
			continue
		var my_pos: Vector2 = my_pc.value

		var current_visible: Dictionary = {}
		for rec in _ready:
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


## Реплицируем всё, что имеет C_NetId + C_Position и живо.
## Проверка "полной сборки" сущности — дело payload-маски, а не этого метода.
func _is_ready(entity) -> bool:
	if not is_instance_valid(entity):
		return false
	if not entity.has_component(C_NetId):
		return false
	if not entity.has_component(C_Position):
		return false
	var es = entity.get_component(C_ExistenceState)
	if es != null and es.value == 0:
		return false
	return true


func _queue_despawn(ps: PeerState, net_id: int) -> void:
	if ps.despawned_net_ids.has(net_id):
		return
	ps.despawned_net_ids[net_id] = true
	var body := StreamPeerBuffer.new()
	body.put_u16(net_id)
	ps.queue_reliable(NetProtocol.MSG_DESPAWN, body.data_array)
	NetLog.d("aoi", "DESPAWN net_id=%d → peer %d" % [net_id, ps.net_id])


func _queue_spawn(server: C_ServerIP, ps: PeerState, net_id: int) -> void:
	var entity = server.get_entity(net_id)
	if not is_instance_valid(entity):
		return
	var payload := build_spawn_payload(server, ps.net_id, entity)
	if payload.is_empty():
		return
	ps.spawn_batch.append(payload)
	NetLog.d("aoi", "QUEUE SPAWN net_id=%d → peer %d (owner=%s) blocks=%d" % [
		net_id, ps.net_id, str(net_id == ps.net_id), _block_count(entity)
	])


func _block_count(entity) -> int:
	var b = entity.get_component(C_Blocks)
	return b.blocks_map.size() if b else 0


## Универсальная сборка MSG_SPAWN-тела. Вызывается:
##   - из AOISystem._queue_spawn (обычный путь),
##   - из ProjectileSpawnObserver (ускоренный спавн снарядов).
## Static: не зависит от экземпляра системы.
static func build_spawn_payload(server: C_ServerIP, viewer_net_id: int,
		entity: Entity) -> PackedByteArray:
	var nid_c = entity.get_component(C_NetId)
	if nid_c == null:
		return PackedByteArray()
	var net_id: int = nid_c.value

	var pos_c: C_Position  = entity.get_component(C_Position)
	var dir_c: C_Direction = entity.get_component(C_Direction)
	var hp_c:  C_HP        = entity.get_component(C_HP)
	var vel_c: C_Velocity  = entity.get_component(C_Velocity)
	var blk_c: C_Blocks    = entity.get_component(C_Blocks)
	var own_c: C_Owner     = entity.get_component(C_Owner)
	var siz_c: C_Size      = entity.get_component(C_Size)

	var mask := 0
	if pos_c: mask |= 1
	if dir_c: mask |= 2
	if hp_c:  mask |= 4
	if vel_c: mask |= 8
	if blk_c: mask |= 16
	if own_c: mask |= 32
	if siz_c: mask |= 64

	var body := StreamPeerBuffer.new()
	body.put_u16(net_id)
	body.put_u16(mask)

	if pos_c:
		body.put_float(pos_c.value.x)
		body.put_float(pos_c.value.y)
	if dir_c:
		body.put_u16(NetProtocol.quant_rot(deg_to_rad(dir_c.value)))
	if hp_c:
		body.put_u16(hp_c.value)
		body.put_u16(hp_c.value_max)
	if vel_c:
		body.put_16(clampi(int(vel_c.value.x), -32768, 32767))
		body.put_16(clampi(int(vel_c.value.y), -32768, 32767))
	if blk_c:
		_write_blocks_payload(body, blk_c, net_id, viewer_net_id)
	if own_c:
		var owner_net_id := 0
		if not own_c.value.is_empty():
			owner_net_id = server.entity_to_net_id.get(own_c.value[0], 0)
		body.put_u16(owner_net_id)
	if siz_c:
		body.put_u16(int(siz_c.value.x))
		body.put_u16(int(siz_c.value.y))

	return body.data_array


static func _write_blocks_payload(body: StreamPeerBuffer, blk_c: C_Blocks,
		net_id: int, viewer_net_id: int) -> void:
	var block_count := blk_c.blocks_map.size()
	body.put_u16(block_count)
	if block_count == 0:
		return

	var is_owner := (net_id == viewer_net_id)
	if is_owner:
		for key in blk_c.blocks_map.keys():
			var b: Dictionary = blk_c.blocks_map[key]
			var kv: Vector2 = key
			body.put_float(kv.x)
			body.put_float(kv.y)
			body.put_u8(int(b.get("block_id", 0)))
			body.put_u16(int(b.get("block_hp", 0)))
			body.put_u16(int(b.get("block_hp_max", 0)))
	else:
		var mask_bytes := int(ceil(float(block_count) / 8.0))
		var bmask := PackedByteArray()
		bmask.resize(mask_bytes)
		var idx := 0
		for key in blk_c.blocks_map.keys():
			var b: Dictionary = blk_c.blocks_map[key]
			if not bool(b.get("destroy", false)):
				bmask[idx >> 3] |= (1 << (idx & 7))
			idx += 1
		body.put_data(bmask)

		for key in blk_c.blocks_map.keys():
			var b: Dictionary = blk_c.blocks_map[key]
			var kv: Vector2 = key
			var qx := clampi(int(round(kv.x * 2.0)), -128, 127)
			var qy := clampi(int(round(kv.y * 2.0)), -128, 127)
			body.put_8(qx)
			body.put_8(qy)
			body.put_u16(int(b.get("block_hp", 0)))
			body.put_u16(int(b.get("block_hp_max", 0)))
