extends System
class_name CleanupSystem

func query() -> QueryBuilder:
	# Находим все сущности с C_ExistenceState
	return q.with_all([C_ExistenceState])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var state = entity.get_component(C_ExistenceState)
		if state.value == 0:
			var metas = entity.get_meta_list()
			for meta in metas:
				if meta == 'peer':
					var peer = entity.get_meta('peer')
					var server_entity = peer.get_meta('server_entity')
					var UDP = server_entity.get_component(C_ServerIP)
					UDP.remove_peer(peer)
				if meta == 'rigidbody':
					var body = entity.get_meta('rigidbody')
					body.queue_free()
			cmd.remove_entity(entity)
