class_name ClientNetworkReceiveSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_ClientRoot])

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	if ClientSession.udp == null:
		return
	var udp: PacketPeerUDP = ClientSession.udp
	while udp.get_available_packet_count() > 0:
		var raw: PackedByteArray = udp.get_packet()
		if raw.is_empty():
			break
		var buf := StreamPeerBuffer.new()
		buf.data_array = raw
		_handle_packet(raw, buf)

func _handle_packet(raw: PackedByteArray, buf: StreamPeerBuffer) -> void:
	var header := NetProtocol.read_header(buf)
	match header.msg_type:
		NetProtocol.MSG_SPAWN:
			if ClientSession.reliable_recv.on_receive(header.seq, raw):
				_on_spawn(buf)
			_send_ack(header.seq)
		NetProtocol.MSG_DESPAWN:
			if ClientSession.reliable_recv.on_receive(header.seq, raw):
				_on_despawn(buf)
			_send_ack(header.seq)
		NetProtocol.MSG_FIRE:
			if ClientSession.reliable_recv.on_receive(header.seq, raw):
				_on_fire(buf)
			_send_ack(header.seq)
		NetProtocol.MSG_STATE:
			_on_state(buf)
		NetProtocol.MSG_PONG:
			_on_pong(buf)
		_:
			NetLog.d("client", "unhandled msg_type=%d" % header.msg_type)

func _send_ack(seq: int) -> void:
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_ACK, seq)
	ClientSession.udp.put_packet(buf.data_array)

func _mk_netid(nid: int) -> C_NetId:
	var c := C_NetId.new()
	c.value = nid
	return c

func _on_spawn(buf: StreamPeerBuffer) -> void:
	var net_id       := buf.get_u16()
	var kind         := buf.get_u8()
	var owner_net_id := buf.get_u16()
	var px           := buf.get_float()
	var py           := buf.get_float()
	var rot_rad      := NetProtocol.dequant_rot(buf.get_u16())
	var hp           := buf.get_u16()
	var hp_max       := buf.get_u16()
	var size_x       := buf.get_u16()
	var size_y       := buf.get_u16()
	var block_count  := buf.get_u16()

	var is_owner := (net_id == ClientSession.net_id)

	var entity := Entity.new()
	entity.name = "ship_%d" % net_id
	entity.add_component(_mk_netid(net_id))
	entity.add_component(C_Position.new(Vector2(px, py)))
	entity.add_component(C_Direction.new(rad_to_deg(rot_rad)))
	entity.add_component(C_MirrorKind.new(kind, owner_net_id, 0))

	var size_c := C_Size.new()
	size_c.value = Vector2(size_x, size_y)
	entity.add_component(size_c)

	if is_owner:
		entity.add_component(C_IsLocalPlayer.new())
		var pred := C_PredictedState.new()
		pred.pos = Vector2(px, py)
		pred.rot = rot_rad
		pred.initialized = true
		entity.add_component(pred)
		entity.add_component(C_InputHistory.new())
		entity.add_component(C_LastServerState.new())

	if block_count > 0:
		if is_owner:
			var blocks: Array = []
			for i in block_count:
				var bx := buf.get_float()
				var by := buf.get_float()
				var bid := buf.get_u8()
				var bhp := buf.get_u16()
				blocks.append({"pos": Vector2(bx, by), "id": bid, "hp": bhp})
			entity.set_meta("blocks", blocks)
		else:
			var mask_bytes := int(ceil(float(block_count) / 8.0))
			var res = buf.get_data(mask_bytes)
			if res[0] == OK:
				var mk: C_MirrorKind = entity.get_component(C_MirrorKind)
				mk.alive_mask = res[1]

	ClientSession.register_entity(net_id, entity)
	ECS.world.add_entity(entity)
	NetLog.d("client", "SPAWN net_id=%d kind=%d owner=%s hp=%d/%d blocks=%d" % [
		net_id, kind, str(is_owner), hp, hp_max, block_count
	])

func _on_despawn(buf: StreamPeerBuffer) -> void:
	var net_id := buf.get_u16()
	var e = ClientSession.get_entity(net_id)
	if e != null and is_instance_valid(e):
		ECS.world.remove_entity(e)
	ClientSession.unregister_entity(net_id)
	NetLog.d("client", "DESPAWN net_id=%d (mirror size=%d)" % [net_id, ClientSession.net_id_to_entity.size()])

func _on_fire(buf: StreamPeerBuffer) -> void:
	var proj_net_id   := buf.get_u16()
	var shooter_net   := buf.get_u16()
	var sx            := buf.get_float()
	var sy            := buf.get_float()
	var rot_rad       := NetProtocol.dequant_rot(buf.get_u16())
	var target_net    := buf.get_u16()

	var entity := Entity.new()
	entity.name = "proj_%d" % proj_net_id
	entity.add_component(_mk_netid(proj_net_id))
	entity.add_component(C_Position.new(Vector2(sx, sy)))
	entity.add_component(C_Direction.new(rad_to_deg(rot_rad)))
	entity.add_component(C_MirrorKind.new(2, shooter_net, target_net))

	var it := C_InterpTarget.new()
	it.prev_pos = Vector2(sx, sy)
	it.curr_pos = Vector2(sx, sy)
	it.prev_rot = rot_rad
	it.curr_rot = rot_rad
	it.t = 1.0
	it.has_target = true
	entity.add_component(it)

	ClientSession.register_entity(proj_net_id, entity)
	ECS.world.add_entity(entity)
	NetLog.d("client", "FIRE net_id=%d shooter=%d pos=(%.1f,%.1f)" % [proj_net_id, shooter_net, sx, sy])

func _on_state(buf: StreamPeerBuffer) -> void:
	var _tick: int = buf.get_u16()
	var acked_seq: int = buf.get_u16()
	var count: int = buf.get_u8()

	for _i in count:
		var net_id: int = buf.get_u16()
		var mask: int = buf.get_u8()

		var has_pos := (mask & 1) != 0
		var has_rot := (mask & 2) != 0
		var has_hp  := (mask & 4) != 0
		var has_vel := (mask & 8) != 0

		var qx: int = buf.get_u16() if has_pos else 0
		var qy: int = buf.get_u16() if has_pos else 0
		var qrot: int = buf.get_u16() if has_rot else 0
		var hp: int = buf.get_u16() if has_hp else 0
		var vx: int = buf.get_16() if has_vel else 0
		var vy: int = buf.get_16() if has_vel else 0

		var e = ClientSession.get_entity(net_id)
		if e == null or not is_instance_valid(e):
			continue

		if net_id == ClientSession.net_id:
			var last: C_LastServerState = e.get_component(C_LastServerState)
			if last == null:
				continue
			if has_pos:
				last.pos = NetProtocol.dequant_pos(Vector2i(qx, qy), ClientSession.map_min, ClientSession.map_max)
			if has_rot:
				last.rot = NetProtocol.dequant_rot(qrot)
			if has_vel:
				last.vel = Vector2(vx, vy)
			last.last_acked_seq = acked_seq
			last.dirty = true
		else:
			var it: C_InterpTarget = e.get_component(C_InterpTarget)
			if it == null:
				continue
			if has_pos:
				it.prev_pos = it.curr_pos
				it.curr_pos = NetProtocol.dequant_pos(Vector2i(qx, qy), ClientSession.map_min, ClientSession.map_max)
				it.t = 0.0
				it.has_target = true
			if has_rot:
				it.prev_rot = it.curr_rot
				it.curr_rot = NetProtocol.dequant_rot(qrot)

func _on_pong(buf: StreamPeerBuffer) -> void:
	var client_time := buf.get_u32()
	var rtt := Time.get_ticks_msec() - int(client_time)
	NetLog.d("client", "PONG rtt=%d ms" % rtt)
