class_name NetIdAssignObserver
extends Observer
## Реагирует на появление C_EntityType и выдаёт сущности net_id.
## Идемпотентен: если C_NetId уже есть (например, у игрока),
## просто регистрирует его в реестре C_ServerIP.

func query() -> QueryBuilder:
	return q.with_all([C_EntityType]).on_added()

func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var server := C_ServerIP.instance
	if server == null:
		NetLog.d("warn", "NetIdAssignObserver: no server instance")
		return

	if entity.has_component(C_NetId):
		# Уже назначен (игрок получает net_id из PeerState)
		var _nid: int = entity.get_component(C_NetId).value
		server.register_entity(_nid, entity)
		NetLog.d("netid", "register existing net_id=%d" % _nid)
		return

	var nid := server.allocate_net_id()
	cmd.add_component(entity, C_NetId.new(nid))
	server.register_entity(nid, entity)
	NetLog.d("netid", "assigned net_id=%d to %s" % [nid, entity.name])
