extends System
class_name NetworkPeerRegistrationSystem

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var server: C_ServerIP = entity.get_component(C_ServerIP)

		for peer in server.peers.keys():
			if not peer.has_meta("entity"):
				var player_entity = Entity.new()
				player_entity.name = "Player_%s_%s" % [peer.get_packet_ip(), server.peers[peer].nick]

				var spawn_comp = C_SpawnPoint.new(Vector2(server.peers[peer].position[0], server.peers[peer].position[1]))
				player_entity.add_component(spawn_comp)

				var entity_name = C_EntityName.new(server.peers[peer].nick)
				player_entity.add_component(entity_name)

				var entity_type = C_EntityType.new('user')
				player_entity.add_component(entity_type)

				var peer_comp = C_PeerID.new()
				peer_comp.value = _generate_peer_id(peer)
				player_entity.add_component(peer_comp)

				ECS.world.add_entity(player_entity)

				peer.set_meta("entity", player_entity)
				peer.set_meta('server_entity', entity)
				player_entity.set_meta('peer', peer)

				print("Создана сущность для пира %s:%s" % [peer.get_packet_ip(), peer.get_packet_port()])

func _generate_peer_id(peer: PacketPeerUDP) -> int:
	# Генерируем уникальный ID на основе IP и порта
	return hash(peer.get_packet_ip() + str(peer.get_packet_port()))
