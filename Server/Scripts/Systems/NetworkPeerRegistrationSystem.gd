class_name NetworkPeerRegistrationSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity in entities:
		var server: C_ServerIP = entity.get_component(C_ServerIP)
		for ps in server.peers.values():
			if ps.needs_spawn and not server.net_id_to_entity.has(ps.net_id):
				_spawn(server, ps)
				ps.needs_spawn = false

func _spawn(server: C_ServerIP, ps: PeerState) -> void:
	var e := Entity.new()
	e.name = "Player_%d" % ps.net_id

	# C_PeerID — через .new() + .value (нет _init с параметром)
	var peer_id := C_PeerID.new()
	peer_id.value = ps.net_id
	
	e.add_component(C_NetId.new(ps.net_id))
	e.add_component(C_SpawnPoint.new(ps.spawn_pos))
	e.add_component(C_EntityType.new("user"))
	e.add_component(C_EntityName.new(ps.nick))
	e.add_component(peer_id)

	ECS.world.add_entity(e)
	server.register_entity(ps.net_id, e)
	e.set_meta("peer_state", ps)   # временная ссылка (разрешено правилами)
	ps.acked_pos = ps.spawn_pos
	ps.acked_rot = 0.0
	ps.acked_vel = Vector2.ZERO
	ps.acked_initialized = true

	NetLog.d("spawn", "player net_id=%d nick=%s" % [ps.net_id, ps.nick])
