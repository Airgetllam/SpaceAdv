extends System
class_name NetworkControlSystem


func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var server: C_ServerIP = entity.get_component(C_ServerIP)
		var UDP = server.UDP_connection[0]
		UDP.poll()
		if UDP.is_connection_available():
			var peer = UDP.take_connection()
			var packet = peer.get_packet()
			print("Accepted peer: %s:%s" % [peer.get_packet_ip(), peer.get_packet_port()])
			print("Received data: %s" % [packet.get_string_from_utf8()])
			peer.put_packet(packet)
			server.add_peer(peer, 'test')
		for peer in server.peers.keys():
			var packets_processed = 0
			const MAX_PACKETS = 10
			while peer.get_available_packet_count() > 0 and packets_processed < MAX_PACKETS:
				var packet = peer.get_packet()
				var data_str = packet.get_string_from_utf8()
				var json = JSON.parse_string(data_str)
				if json == null:
					print("Ошибка парсинга JSON от %s:%s" % [peer.get_packet_ip(), peer.get_packet_port()])
					continue

				# Проверяем, есть ли сущность, связанная с этим пиром
				if not peer.has_meta("entity"):
					print("Пир %s:%s ещё не имеет сущности" % [peer.get_packet_ip(), peer.get_packet_port()])
					continue

				var player_entity: Entity = peer.get_meta("entity")

				# Обновляем управление (throttle, turn, brake)
				var control_input: C_ControlInput = player_entity.get_component(C_ControlInput)
				if control_input:
					if json.has("throttle"):
						control_input.throttle = clamp(json.get("throttle"), -1.0, 1.0)
					if json.has("turn"):
						control_input.turn = clamp(json.get("turn"), -1.0, 1.0)
					if json.has("brake"):
						control_input.brake = bool(json.get("brake"))
					if json.has("cursor_pos"):
						var cursor_comp: C_CursorPosition = player_entity.get_component(C_CursorPosition)
						if cursor_comp:
							var str = json["cursor_pos"]
							var clean = str.trim_prefix("(").trim_suffix(")").split(",")
							var vec = Vector2(float(clean[0]), float(clean[1]))
							cursor_comp.position = vec
