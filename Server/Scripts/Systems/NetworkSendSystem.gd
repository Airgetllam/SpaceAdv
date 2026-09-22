class_name NetworkSendSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var server: C_ServerIP = entity.get_component(C_ServerIP)
		if server.UDP_connection.is_empty():
			continue
		var now := Time.get_ticks_msec()
		server.tick += 1
		if server.tick > 65535:
			server.tick = 0

		for ps in server.peers.values():
			# 1. Ретрансмит неподтверждённых надёжных
			ps.reliable.tick(ps.udp_peer, now)

			# 2. Отправка новых надёжных — с rate-limit, чтобы всплеск
			#    (например, залп из 36 MSG_FIRE) растянулся на несколько тиков
			#    и не переполнил приёмный буфер клиента.
			var sent := 0
			while sent < NetConfig.MAX_RELIABLE_PER_TICK and not ps.reliable_outbox.is_empty():
				var entry: Dictionary = ps.reliable_outbox.pop_front()
				var packet: PackedByteArray = ps.reliable.enqueue(entry.msg_type, entry.body)
				ps.udp_peer.put_packet(packet)
				NetLog.d("send", "reliable msg=%d len=%d" % [entry.msg_type, packet.size()])
				sent += 1

			# 3. Unreliable MSG_STATE
			_send_state(server, ps)


func _send_state(server: C_ServerIP, ps: PeerState) -> void:
	if ps.net_id == 0:
		return

	# Позиция наблюдателя — для приоритизации по расстоянию
	var my_e = server.get_entity(ps.net_id)
	var my_pos := Vector2.ZERO
	if is_instance_valid(my_e):
		var my_pc: C_Position = my_e.get_component(C_Position)
		if my_pc:
			my_pos = my_pc.value

	var deltas: Array = []
	for nid in ps.visible_net_ids.keys():
		var e = server.get_entity(nid)
		if not is_instance_valid(e):
			continue

		var pc: C_Position = e.get_component(C_Position)
		var dist_sq: float = INF
		if pc != null:
			dist_sq = my_pos.distance_squared_to(pc.value)

		var interval := _update_interval(e, dist_sq)
		if interval > 1 and (server.tick + nid) % interval != 0:
			continue

		var is_own: bool = (nid == ps.net_id)
		var delta: PackedByteArray = _build_entity_delta(
			e, ps.last_sent_state.get(nid, {}), ps, is_own
		)
		if delta.is_empty():
			continue
		deltas.append({
			"nid": nid,
			"bytes": delta,
			"snap": _snapshot(e, ps, is_own),
		})

	if deltas.is_empty():
		return

	# MTU-aware разбиение: набираем чанки, пока не упрёмся в лимит байт
	# или в MAX_ENTITIES_PER_STATE_PACKET.
	var i := 0
	while i < deltas.size():
		var chunk: Array = []
		var total_bytes := 0
		var j := i
		while j < deltas.size() and chunk.size() < NetConfig.MAX_ENTITIES_PER_STATE_PACKET:
			var d: Dictionary = deltas[j]
			var dbytes: PackedByteArray = d.bytes
			if not chunk.is_empty() and total_bytes + dbytes.size() > NetConfig.MAX_STATE_PACKET_BYTES:
				break
			chunk.append(d)
			total_bytes += dbytes.size()
			j += 1

		var buf := StreamPeerBuffer.new()
		NetProtocol.write_header(buf, NetProtocol.MSG_STATE, 0)
		buf.put_u16(server.tick)
		buf.put_u16(ps.last_applied_input_seq)
		buf.put_u8(chunk.size())
		for d in chunk:
			buf.put_data(d.bytes)
			ps.last_sent_state[d.nid] = d.snap
		ps.udp_peer.put_packet(buf.data_array)
		i = j


## Интервал обновления MSG_STATE для сущности.
## Снаряды — всегда 2 тика (10 Гц), интерполируются на клиенте.
## Остальные — по расстоянию: near (≤800) каждый тик, mid (≤1600) раз в 2,
## far (>1600) раз в 4. Фаза (server.tick + nid) размазывает обновления,
## чтобы не было пиков на одном тике.
func _update_interval(e: Entity, dist_sq: float) -> int:
	var et: C_EntityType = e.get_component(C_EntityType)
	if et != null and et.value == "projectile":
		return NetConfig.PROJECTILE_UPDATE_INTERVAL

	var near_sq: float = NetConfig.NEAR_RADIUS * NetConfig.NEAR_RADIUS
	var mid_sq: float = NetConfig.MID_RADIUS * NetConfig.MID_RADIUS
	if dist_sq <= near_sq:
		return 1
	if dist_sq <= mid_sq:
		return 2
	return 4


func _build_entity_delta(entity, prev: Dictionary, ps: PeerState, use_acked: bool) -> PackedByteArray:
	var nid_c: C_NetId = entity.get_component(C_NetId)
	if nid_c == null:
		return PackedByteArray()

	var pos_c: C_Position = entity.get_component(C_Position)
	var dir_c: C_Direction = entity.get_component(C_Direction)
	var vel_c: C_Velocity = entity.get_component(C_Velocity)
	var hp_c: C_HP = entity.get_component(C_HP)

	var cur_pos: Vector2
	var cur_rot_deg: float
	var cur_vel: Vector2
	if use_acked and ps and ps.acked_initialized:
		cur_pos = ps.acked_pos
		cur_rot_deg = ps.acked_rot
		cur_vel = ps.acked_vel
	else:
		cur_pos = pos_c.value if pos_c else Vector2.ZERO
		cur_rot_deg = dir_c.value if dir_c else 0.0
		cur_vel = vel_c.value if vel_c else Vector2.ZERO

	var mask: int = 0
	var q_pos: Vector2i = Vector2i.ZERO
	var q_rot: int = 0
	var q_vx: int = 0
	var q_vy: int = 0
	var cur_hp: int = 0

	if pos_c:
		q_pos = NetProtocol.quant_pos(cur_pos, NetConfig.MAP_MIN, NetConfig.MAP_MAX)
		if prev.get("pos_q") != q_pos:
			mask |= 1

	if dir_c:
		q_rot = NetProtocol.quant_rot(deg_to_rad(cur_rot_deg))
		if prev.get("rot_q") != q_rot:
			mask |= 2

	if hp_c:
		cur_hp = hp_c.value
		if prev.get("hp") != cur_hp:
			mask |= 4

	if vel_c:
		q_vx = clampi(int(cur_vel.x), -32768, 32767)
		q_vy = clampi(int(cur_vel.y), -32768, 32767)
		if prev.get("vx") != q_vx or prev.get("vy") != q_vy:
			mask |= 8

	if mask == 0:
		return PackedByteArray()

	var body := StreamPeerBuffer.new()
	body.put_u16(nid_c.value)
	body.put_u8(mask)
	if mask & 1:
		body.put_u16(q_pos.x)
		body.put_u16(q_pos.y)
	if mask & 2:
		body.put_u16(q_rot)
	if mask & 4:
		body.put_u16(cur_hp)
	if mask & 8:
		body.put_16(q_vx)
		body.put_16(q_vy)
	return body.data_array


func _snapshot(entity, ps: PeerState, use_acked: bool) -> Dictionary:
	var out: Dictionary = {}
	var pos_c: C_Position = entity.get_component(C_Position)
	var dir_c: C_Direction = entity.get_component(C_Direction)
	var hp_c: C_HP = entity.get_component(C_HP)
	var vel_c: C_Velocity = entity.get_component(C_Velocity)

	var cur_pos: Vector2
	var cur_rot_deg: float
	var cur_vel: Vector2
	if use_acked and ps and ps.acked_initialized:
		cur_pos = ps.acked_pos
		cur_rot_deg = ps.acked_rot
		cur_vel = ps.acked_vel
	else:
		cur_pos = pos_c.value if pos_c else Vector2.ZERO
		cur_rot_deg = dir_c.value if dir_c else 0.0
		cur_vel = vel_c.value if vel_c else Vector2.ZERO

	if pos_c:
		out["pos_q"] = NetProtocol.quant_pos(cur_pos, NetConfig.MAP_MIN, NetConfig.MAP_MAX)
	if dir_c:
		out["rot_q"] = NetProtocol.quant_rot(deg_to_rad(cur_rot_deg))
	if hp_c:
		out["hp"] = hp_c.value
	if vel_c:
		out["vx"] = clampi(int(cur_vel.x), -32768, 32767)
		out["vy"] = clampi(int(cur_vel.y), -32768, 32767)
	return out
