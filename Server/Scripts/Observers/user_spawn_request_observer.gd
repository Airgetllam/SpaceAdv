extends Observer
class_name UserSpawnRequestObserver

func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_SpawnPoint]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var peer: C_PeerID = entity.get_component(C_PeerID)
	var comps = [
		C_ExistenceState.new(),
		C_RigidBody.new(),
		C_Force.new(),
		C_AngularVelocity.new(),
		C_ControlInput.new(),
		C_CursorPosition.new(),
		C_Modules.new()
	]
	print('[UserSpawnRequestSystem] C_RigidBody, C_Position, C_Force, C_AngularVelocity, C_PhysicsPoint, C_ControlInput, C_Modules были присвоены peer ID: ', peer.value, '. ID сущности: ', entity.id)
	cmd.add_components(entity, comps)
	print('[UserSpawnRequestSystem] Игрок с peer ID ', peer.value, ' был добавлен на сервер')
