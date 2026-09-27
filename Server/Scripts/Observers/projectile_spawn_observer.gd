extends Observer
class_name ProjectileSpawnObserver
## Ускоренный спавн снарядов: как только снаряду выдан net_id,
## сразу шлём MSG_SPAWN пирам, в чьём AOI он появился.
## Не ждём тика AOISystem — иначе снаряд на клиенте появится через 50–100 мс.
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
	var pos_c: C_Position = entity.get_component(C_Position)
	if pos_c == null:
		# Снаряд ещё не получил позицию — AOISystem подхватит позже.
		return
	var spawn_pos: Vector2 = pos_c.value

	# viewer_net_id = -1 → никогда не owner, блоки пойдут по observer-ветке.
	var payload := AOISystem.build_spawn_payload(server, -1, entity)
	if payload.is_empty():
		return

	var aoi_sq: float = NetConfig.AOI_RADIUS * NetConfig.AOI_RADIUS
	for peer_key in server.peers.keys():
		var ps: PeerState = server.peers[peer_key]
		if ps == null:
			continue
		if ps.visible_net_ids.has(nid):
			continue
		var viewer = server.get_entity(ps.net_id)
		if viewer == null:
			continue
		var vpos: C_Position = viewer.get_component(C_Position)
		if vpos == null:
			continue
		if vpos.value.distance_squared_to(spawn_pos) <= aoi_sq:
			ps.spawn_batch.append(payload)
			ps.visible_net_ids[nid] = true
			ps.last_sent_state.erase(nid)
			NetLog.d("spawn", "FAST QUEUE net=%d -> peer=%d" % [nid, ps.net_id])
