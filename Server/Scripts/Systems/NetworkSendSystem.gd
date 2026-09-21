class_name NetworkSendSystem
extends System

const MAX_ENTITIES_PER_PACKET := 200

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

			# 2. Отправка новых надёжных сообщений
			for entry in ps.reliable_outbox:
				var packet: PackedByteArray = ps.reliable.enqueue(entry.msg_type, entry.body)
				ps.udp_peer.put_packet(packet)
				NetLog.d("send", "reliable msg=%d len=%d" % [entry.msg_type, packet.size()])
			ps.reliable_outbox.clear()

			# 3. Unreliable MSG_STATE
			_send_state(server, ps)


func _send_state(server: C_ServerIP, ps: PeerState) -> void:
	if ps.net_id == 0:
		return

	var deltas: Array = []
	for nid in ps.visible_net_ids.keys():
		var e = server.get_entity(nid)
		if not is_instance_valid(e):
			continue
		var delta: PackedByteArray = _build_entity_delta(e, ps.last_sent_state.get(nid, {}))
		if delta.is_empty():
			continue
		deltas.append({ "nid": nid, "bytes": delta, "snap": _snapshot(e) })

	if deltas.is_empty():
		return

	# Разбиваем на пакеты, если превысили лимит entity_count (uint8)
	var i := 0
	while i < deltas.size():
		var chunk_end: int = min(i + MAX_ENTITIES_PER_PACKET, deltas.size())
		var buf := StreamPeerBuffer.new()
		NetProtocol.write_header(buf, NetProtocol.MSG_STATE, 0)
		buf.put_u16(server.tick)
		buf.put_u16(ps.last_acked_input_seq)
		buf.put_u8(chunk_end - i)
		for j in range(i, chunk_end):
			buf.put_data(deltas[j].bytes)
			ps.last_sent_state[deltas[j].nid] = deltas[j].snap
		ps.udp_peer.put_packet(buf.data_array)
		NetLog.d("send", "STATE tick=%d count=%d len=%d" % [
			server.tick, chunk_end - i, buf.data_array.size()
		])
		i = chunk_end


func _build_entity_delta(entity, prev: Dictionary) -> PackedByteArray:
	var nid_c: C_NetId = entity.get_component(C_NetId)
	if nid_c == null:
		return PackedByteArray()

	var pos_c: C_Position = entity.get_component(C_Position)
	var dir_c: C_Direction = entity.get_component(C_Direction)
	var hp_c: C_HP = entity.get_component(C_HP)
	var vel_c: C_Velocity = entity.get_component(C_Velocity)

	var mask: int = 0
	var q_pos: Vector2i = Vector2i.ZERO
	var q_rot: int = 0
	var cur_hp: int = 0
	var q_vx: int = 0
	var q_vy: int = 0

	if pos_c:
		q_pos = NetProtocol.quant_pos(pos_c.value, NetConfig.MAP_MIN, NetConfig.MAP_MAX)
		if prev.get("pos_q") != q_pos:
			mask |= 1

	if dir_c:
		q_rot = NetProtocol.quant_rot(deg_to_rad(dir_c.value))
		if prev.get("rot_q") != q_rot:
			mask |= 2

	if hp_c:
		cur_hp = hp_c.value
		if prev.get("hp") != cur_hp:
			mask |= 4

	if vel_c:
		q_vx = clampi(int(vel_c.value.x), -32768, 32767)
		q_vy = clampi(int(vel_c.value.y), -32768, 32767)
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


func _snapshot(entity) -> Dictionary:
	var out: Dictionary = {}
	var pos_c: C_Position = entity.get_component(C_Position)
	if pos_c:
		out["pos_q"] = NetProtocol.quant_pos(pos_c.value, NetConfig.MAP_MIN, NetConfig.MAP_MAX)
	var dir_c: C_Direction = entity.get_component(C_Direction)
	if dir_c:
		out["rot_q"] = NetProtocol.quant_rot(deg_to_rad(dir_c.value))
	var hp_c: C_HP = entity.get_component(C_HP)
	if hp_c:
		out["hp"] = hp_c.value
	var vel_c: C_Velocity = entity.get_component(C_Velocity)
	if vel_c:
		out["vx"] = clampi(int(vel_c.value.x), -32768, 32767)
		out["vy"] = clampi(int(vel_c.value.y), -32768, 32767)
	return out
