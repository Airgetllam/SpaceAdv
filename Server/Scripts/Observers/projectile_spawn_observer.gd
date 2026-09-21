extends Observer
class_name ProjectileSpawnObserver
## Ловит момент, когда NetIdAssignObserver выдал снаряду net_id,
## и надёжно рассылает MSG_FIRE пирам, в чьём AOI оказался спавн.
## Регистрировать ПОСЛЕ NetIdAssignObserver.

func query() -> QueryBuilder:
	return q.with_all([C_EntityType, C_NetId]).on_added()

func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	if entity.has_meta("_fire_sent"):
		return
	entity.set_meta("_fire_sent", true)
	var et: C_EntityType = entity.get_component(C_EntityType)
	if et == null or et.value != "projectile":
		return

	var server: C_ServerIP = C_ServerIP.instance
	if server == null:
		return

	var nid: int = entity.get_component(C_NetId).value

	# Позиция спавна: C_Position (если уже проставлен) или C_SpawnPoint
	var spawn_pos := Vector2.ZERO
	var pos_c: C_Position = entity.get_component(C_Position)
	if pos_c != null:
		spawn_pos = pos_c.value
	else:
		var sp: C_SpawnPoint = entity.get_component(C_SpawnPoint)
		if sp != null:
			spawn_pos = sp.value

	# Угол: C_Direction (градусы) или C_SpawnPoint.angle_value (градусы)
	var ship_deg := 0.0
	var dir_c: C_Direction = entity.get_component(C_Direction)
	if dir_c != null:
		ship_deg = dir_c.value
	else:
		var sp2: C_SpawnPoint = entity.get_component(C_SpawnPoint)
		if sp2 != null:
			ship_deg = sp2.angle_value

	# Владелец
	var shooter_net := 0
	var own: C_Owner = entity.get_component(C_Owner)
	if own != null and not own.value.is_empty():
		var sh = own.value[0]
		if is_instance_valid(sh) and sh.has_component(C_NetId):
			shooter_net = sh.get_component(C_NetId).value

	# Цель (для отображения трассера у клиента)
	var target_net := 0
	var tgt: C_Target = entity.get_component(C_Target)
	if tgt != null and not tgt.value.is_empty():
		var te = tgt.value[0]
		if is_instance_valid(te) and te.has_component(C_NetId):
			target_net = te.get_component(C_NetId).value

	# Тело MSG_FIRE
	var body := StreamPeerBuffer.new()
	body.put_u16(nid)
	body.put_u16(shooter_net)
	body.put_float(spawn_pos.x)
	body.put_float(spawn_pos.y)
	body.put_u16(NetProtocol.quant_rot(deg_to_rad(ship_deg)))
	body.put_u16(target_net)

	var aoi_sq: float = NetConfig.AOI_RADIUS * NetConfig.AOI_RADIUS
	for peer_key in server.peers.keys():
		var ps: PeerState = server.peers[peer_key]
		if ps == null:
			continue
		var viewer = server.get_entity(ps.net_id)
		if viewer == null:
			continue
		var vpos: C_Position = viewer.get_component(C_Position)
		if vpos == null:
			continue
		if vpos.value.distance_squared_to(spawn_pos) <= aoi_sq:
			ps.queue_reliable(NetProtocol.MSG_FIRE, body.data_array)
			NetLog.d("server", "MSG_FIRE net=%d shooter=%d -> peer=%d" % [
				nid, shooter_net, ps.net_id
			])
