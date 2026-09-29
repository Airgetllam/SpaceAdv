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
		NetProtocol.MSG_STATE:
			_on_state(buf)
		NetProtocol.MSG_PONG:
			_on_pong(buf)
		NetProtocol.MSG_BLOCK_HP:
			if ClientSession.reliable_recv.on_receive(header.seq, raw):
				_on_block_hp(buf)
			_send_ack(header.seq)
		NetProtocol.MSG_SPAWN_BATCH:
			if ClientSession.reliable_recv.on_receive(header.seq, raw):
				_on_spawn_batch(buf)
			_send_ack(header.seq)
		_:
			NetLog.d("client", "unhandled msg_type=%d" % header.msg_type)

func _on_spawn_batch(buf: StreamPeerBuffer) -> void:
	var n := buf.get_u16()
	NetLog.d("client", "SPAWN_BATCH n=%d" % n)
	for _i in n:
		_on_spawn(buf)

func _send_ack(seq: int) -> void:
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_ACK, seq)
	ClientSession.udp.put_packet(buf.data_array)

func _mk_netid(nid: int) -> C_NetId:
	var c := C_NetId.new()
	c.value = nid
	return c

func _on_spawn(buf: StreamPeerBuffer) -> void:
	var net_id    := buf.get_u16()
	var comp_mask := buf.get_u16()
	var is_owner  := (net_id == ClientSession.net_id)

	var entity := Entity.new()
	entity.name = "ent_%d" % net_id
	entity.add_component(_mk_netid(net_id))

	# C_MirrorKind ставим всегда — хранит owner_net_id и hp/hp_max,
	# даже если у сущности нет ни блоков, ни оружия.
	var mk := C_MirrorKind.new()
	entity.add_component(mk)

	var spawn_pos := Vector2.ZERO
	var spawn_rot := 0.0

	if comp_mask & 1:
		spawn_pos = Vector2(buf.get_float(), buf.get_float())
		entity.add_component(C_Position.new(spawn_pos))
	if comp_mask & 2:
		spawn_rot = NetProtocol.dequant_rot(buf.get_u16())
		entity.add_component(C_Direction.new(rad_to_deg(spawn_rot)))
	if comp_mask & 4:
		mk.hp     = buf.get_u16()
		mk.hp_max = buf.get_u16()
	if comp_mask & 8:
		var vx := buf.get_16()
		var vy := buf.get_16()
		entity.add_component(C_Velocity.new(Vector2(vx, vy)))

	if comp_mask & 16:
		var block_count := buf.get_u16()
		if is_owner:
			var blocks: Array = []
			for i in block_count:
				var bx  := buf.get_float()
				var by  := buf.get_float()
				var bid := buf.get_u8()
				var bhp := buf.get_u16()
				var bhm := buf.get_u16()
				blocks.append({
					"pos": Vector2(bx, by), "id": bid,
					"hp": bhp, "hp_max": bhm,
				})
			entity.set_meta("blocks", blocks)
		else:
			var mask_bytes := int(ceil(float(block_count) / 8.0))
			var res = buf.get_data(mask_bytes)
			if res[0] == OK:
				mk.alive_mask = res[1]
			var layout: Array = []
			var hps: Array = []
			var hpmaxes: Array = []
			for i in block_count:
				var qx := buf.get_8()
				var qy := buf.get_8()
				var bhp := buf.get_u16()
				var bhm := buf.get_u16()
				layout.append(Vector2i(qx, qy))
				hps.append(bhp)
				hpmaxes.append(bhm)
			mk.blocks_layout = layout
			mk.blocks_hp = hps
			mk.blocks_hp_max = hpmaxes

	if comp_mask & 32:
		mk.owner_net_id = buf.get_u16()
	if comp_mask & 64:
		var sc := C_Size.new()
		sc.value = Vector2(buf.get_u16(), buf.get_u16())
		entity.add_component(sc)

	# Локальные компоненты — по правилу is_owner и наличию позиции.
	if is_owner:
		entity.add_component(C_IsLocalPlayer.new())
		entity.add_component(C_PlayerInput.new())
		if entity.has_component(C_Position):
			var pred := C_PredictedState.new()
			pred.pos = spawn_pos
			pred.rot = spawn_rot
			pred.initialized = true
			entity.add_component(pred)
			entity.add_component(C_InputHistory.new())
			var last := C_LastServerState.new()
			last.pos = spawn_pos
			last.rot = spawn_rot
			last.vel = Vector2.ZERO
			last.last_acked_seq = 0
			last.last_reconciled_seq = 0
			last.dirty = false
			entity.add_component(last)
	else:
		if entity.has_component(C_Position):
			var it := C_InterpTarget.new()
			it.prev_pos = spawn_pos
			it.curr_pos = spawn_pos
			it.prev_rot = spawn_rot
			it.curr_rot = spawn_rot
			it.t = 1.0
			it.has_target = true
			entity.add_component(it)

	ClientSession.register_entity(net_id, entity)
	ECS.world.add_entity(entity)
	NetLog.d("client", "SPAWN net_id=%d mask=0x%02x owner=%s" % [
		net_id, comp_mask, str(is_owner)
	])

func _on_block_hp(buf: StreamPeerBuffer) -> void:
	var net_id := buf.get_u16()
	var count := buf.get_u16()

	var e = ClientSession.get_entity(net_id)
	if e == null or not is_instance_valid(e):
		return

	if net_id == ClientSession.net_id:
		# Owner: обновляем hp блоков в мете
		var blocks: Array = e.get_meta("blocks", [])
		for _i in count:
			var kx := buf.get_float()
			var ky := buf.get_float()
			var new_hp := buf.get_u16()
			for b in blocks:
				var bp: Vector2 = b["pos"]
				if abs(bp.x - kx) < 0.01 and abs(bp.y - ky) < 0.01:
					b["hp"] = new_hp
					break
		e.set_meta("blocks", blocks)
	else:
		# Remote: обновляем C_MirrorKind.blocks_hp
		var mk: C_MirrorKind = e.get_component(C_MirrorKind)
		if mk == null:
			return
		var layout: Array = mk.blocks_layout
		var hps: Array = mk.blocks_hp
		for _i in count:
			var kx := buf.get_float()
			var ky := buf.get_float()
			var new_hp := buf.get_u16()
			for i in layout.size():
				var bp: Vector2i = layout[i]                # ← явная типизация
				var lx: float = float(bp.x) * 0.5
				var ly: float = float(bp.y) * 0.5
				if abs(lx - kx) < 0.01 and abs(ly - ky) < 0.01:
					if i < hps.size():
						hps[i] = new_hp
					break

func _on_despawn(buf: StreamPeerBuffer) -> void:
	var net_id := buf.get_u16()
	var e = ClientSession.get_entity(net_id)
	if e != null and is_instance_valid(e):
		ECS.world.remove_entity(e)
	ClientSession.unregister_entity(net_id)
	NetLog.d("client", "DESPAWN net_id=%d (mirror size=%d)" % [net_id, ClientSession.net_id_to_entity.size()])


func _on_state(buf: StreamPeerBuffer) -> void:
	var _tick: int = buf.get_u16()
	var acked_seq: int = buf.get_u16()
	var count: int = buf.get_u8()

	# ACK input не требует обязательного owner entity delta.
	#
	# Если сервер уже применил input, его можно удалить
	# из prediction history даже тогда, когда authoritative
	# transform не изменился настолько, чтобы попасть в delta.
	var local_entity = ClientSession.get_entity(
		ClientSession.net_id
	)

	if (
		local_entity != null
		and is_instance_valid(local_entity)
	):
		var history: C_InputHistory = (
			local_entity.get_component(
				C_InputHistory
			)
		)

		if history != null:
			var before_ack: int = (
				history.entries.size()
			)

			var pending_inputs: Array = []

			for inp in history.entries:
				if int(inp.seq) > acked_seq:
					pending_inputs.append(inp)

			history.entries = pending_inputs

			var removed: int = (
				before_ack
				- pending_inputs.size()
			)

			if removed > 4:
				NetLog.d(
					"input",
					"ack=%d removed=%d pending=%d" % [
						acked_seq,
						removed,
						pending_inputs.size(),
					]
				)

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
			if has_pos or has_rot:
				# Promote: текущее РЕНДЕРНОЕ состояние становится prev.
				# Не прыгаем в конец предыдущей интерполяции — так нет снапа.
				var rendered_pos: Vector2 = it.prev_pos.lerp(it.curr_pos, it.t)
				var rendered_rot: float = lerp_angle(it.prev_rot, it.curr_rot, it.t)
				it.prev_pos = rendered_pos
				it.prev_rot = rendered_rot
				if has_pos:
					it.curr_pos = NetProtocol.dequant_pos(Vector2i(qx, qy), ClientSession.map_min, ClientSession.map_max)
				if has_rot:
					it.curr_rot = NetProtocol.dequant_rot(qrot)
				it.t = 0.0
				it.has_target = true
			if has_hp:
				var mk: C_MirrorKind = e.get_component(C_MirrorKind)
				if mk != null:
					mk.hp = hp



func _on_pong(buf: StreamPeerBuffer) -> void:
	var client_time := buf.get_u32()
	var rtt := Time.get_ticks_msec() - int(client_time)
	NetLog.d("client", "PONG rtt=%d ms" % rtt)
