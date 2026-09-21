class_name NetworkControlSystem
extends System

const MAX_PACKETS := NetConfig.MAX_PACKETS_PER_PEER_PER_TICK

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var server: C_ServerIP = entity.get_component(C_ServerIP)
		if server.UDP_connection.is_empty():
			continue
		var udp: UDPServer = server.UDP_connection[0]
		udp.poll()

		# ─── 1. Принимаем новых UDP-пиров ──────────────────────────────
		# UDPServer создаёт "pending peer" для каждого нового адреса.
		# take_connection() извлекает его вместе с буферизованным первым
		# пакетом (HELLO). Без этого шага сервер никогда не увидит клиента.
		while udp.is_connection_available():
			var new_peer: PacketPeerUDP = udp.take_connection()
			if new_peer == null:
				break
			var new_ps := PeerState.new()
			new_ps.udp_peer = new_peer
			new_ps.touch()
			server.peers[new_peer] = new_ps
			NetLog.d("server", "accepted UDP peer from %s:%d" % [
				new_peer.get_packet_ip(), new_peer.get_packet_port()
			])

		# ─── 2. Читаем пакеты от известных пиров ───────────────────────
		var dead_peers: Array = []
		for peer in server.peers.keys():
			var ps: PeerState = server.peers[peer]
			var count := 0
			while count < MAX_PACKETS and peer.get_available_packet_count() > 0:
				var raw: PackedByteArray = peer.get_packet()
				if raw.is_empty():
					break
				ps.touch()
				var buf := StreamPeerBuffer.new()
				buf.data_array = raw
				_handle_message(server, ps, raw, buf)
				count += 1
			if ps.is_timed_out(Time.get_ticks_msec()):
				dead_peers.append(peer)

		# ─── 3. Отключаем таймаутных ───────────────────────────────────
		for peer in dead_peers:
			_disconnect_peer(cmd, server, peer)

func _handle_message(server: C_ServerIP, ps: PeerState, raw: PackedByteArray, buf: StreamPeerBuffer) -> void:
	var header := NetProtocol.read_header(buf)
	match header.msg_type:
		NetProtocol.MSG_HELLO:
			if not ps.reliable.on_receive(header.seq, raw):
				NetLog.d("recv", "dup HELLO seq=%d" % header.seq)
				return
			_handle_hello(server, ps, buf)
			_send_ack(ps, header.seq)
		NetProtocol.MSG_INPUT:
			_handle_input(server, ps, buf)
		NetProtocol.MSG_PING:
			_handle_ping(ps, header, buf)
		NetProtocol.MSG_ACK:
			ps.reliable.on_ack(header.seq)
		_:
			NetLog.d("warn", "unknown msg_type=%d" % header.msg_type)

func _handle_hello(server: C_ServerIP, ps: PeerState, buf: StreamPeerBuffer) -> void:
	ps.nick = NetProtocol.read_string(buf)
	ps.spawn_pos = Vector2(buf.get_float(), buf.get_float())
	ps.session_id = randi()
	ps.net_id = server.allocate_net_id()
	ps.touch()

	server.sessions[ps.session_id] = ps
	NetLog.d("server", "HELLO nick=%s session=%d net_id=%d" % [ps.nick, ps.session_id, ps.net_id])

	# Тело WELCOME без заголовка
	var body := StreamPeerBuffer.new()
	body.put_u32(ps.session_id)
	body.put_u16(ps.net_id)
	body.put_u8(NetConfig.SERVER_TICK_RATE)
	body.put_float(NetConfig.MAP_MIN.x)
	body.put_float(NetConfig.MAP_MIN.y)
	body.put_float(NetConfig.MAP_MAX.x)
	body.put_float(NetConfig.MAP_MAX.y)
	ps.queue_reliable(NetProtocol.MSG_WELCOME, body.data_array)

	# Запрос на спавн (обработает NetworkPeerRegistrationSystem)
	ps.needs_spawn = true

func _handle_input(server: C_ServerIP, ps: PeerState, buf: StreamPeerBuffer) -> void:
	var acked_tick := buf.get_u16()
	ps.last_acked_input_seq = acked_tick
	var throttle := NetProtocol.dequant_axis(buf.get_u8())
	var turn := NetProtocol.dequant_axis(buf.get_u8())
	var flags := buf.get_u8()
	var cursor_x := buf.get_float()
	var cursor_y := buf.get_float()

	var e := server.get_entity(ps.net_id)
	if e == null:
		return
	var input: C_ControlInput = e.get_component(C_ControlInput)
	if input:
		input.throttle = throttle
		input.turn = turn
		input.brake = (flags & 1) != 0
	var cursor: C_CursorPosition = e.get_component(C_CursorPosition)
	if cursor:
		cursor.position = Vector2(cursor_x, cursor_y)

func _handle_ping(ps: PeerState, header: Dictionary, buf: StreamPeerBuffer) -> void:
	var client_time := buf.get_u32()
	var pong := StreamPeerBuffer.new()
	NetProtocol.write_header(pong, NetProtocol.MSG_PONG, header.seq)
	pong.put_u32(client_time)
	pong.put_u32(Time.get_ticks_msec())
	ps.udp_peer.put_packet(pong.data_array)

func _send_ack(ps: PeerState, acked_seq: int) -> void:
	var buf := StreamPeerBuffer.new()
	NetProtocol.write_header(buf, NetProtocol.MSG_ACK, acked_seq)
	ps.udp_peer.put_packet(buf.data_array)

func _disconnect_peer(_cmd: CommandBuffer, server: C_ServerIP, peer: PacketPeerUDP) -> void:
	var ps: PeerState = server.peers.get(peer)
	if ps == null:
		return
	NetLog.d("server", "disconnect net_id=%d" % ps.net_id)

	var nid: int = ps.net_id
	if nid != 0:
		var e = server.net_id_to_entity.get(nid)
		if is_instance_valid(e):
			# C_ExistenceState.new() уже value=1; присваивание 0 триггерит сеттер.
			var es := C_ExistenceState.new()
			es.value = 0
			cmd.add_component(e, es)              # ← структурное изменение через cmd
			server.entity_to_net_id.erase(e)
		# Убираем из реестра немедленно, чтобы AOI не увидел мёртвую ссылку.
		server.net_id_to_entity.erase(nid)

	if ps.udp_peer:
		ps.udp_peer.close()
	server.peers.erase(peer)
	server.sessions.erase(ps.session_id)
	peer.close()
