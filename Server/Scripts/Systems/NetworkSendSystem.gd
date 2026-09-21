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

		for ps in server.peers.values():
			# 1. Ретрансмит неподтверждённых
			ps.reliable.tick(ps.udp_peer, now)

			# 2. Отправка новых надёжных сообщений (WELCOME, SPAWN, DESPAWN и т.д.)
			for entry in ps.reliable_outbox:
				var packet: PackedByteArray = ps.reliable.enqueue(entry.msg_type, entry.body)
				ps.udp_peer.put_packet(packet)
				NetLog.d("send", "reliable msg=%d len=%d" % [entry.msg_type, packet.size()])
			ps.reliable_outbox.clear()

			# 3. Unreliable MSG_STATE — заглушка до Этапа 4
			# _send_state(server, ps)
