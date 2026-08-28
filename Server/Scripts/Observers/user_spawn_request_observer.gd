extends Observer
class_name UserSpawnRequestObserver

func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_SpawnPoint]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var peer: C_PeerID = entity.get_component(C_PeerID)
	var spawn_pos: C_SpawnPoint = entity.get_component(C_SpawnPoint)
	var ship = RigidBody2D.new()
	ship.name = 'ship1'
	ship.position = spawn_pos.value
	ship.gravity_scale = 0
	ship.can_sleep = false
	ship.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ship.linear_damp = 0
	ship.set_meta('entity', entity)
	var comps = [
		C_RigidBody.new(ship),
		C_Position.new(spawn_pos.value),
		C_Force.new(),
		C_AngularVelocity.new(),
		C_ControlInput.new(),
		C_CursorPosition.new(),
		C_Modules.new()
	]
	print('[UserSpawnRequestSystem] C_RigidBody, C_Position, C_Force, C_AngularVelocity, C_PhysicsPoint, C_ControlInput, C_Modules были присвоены peer ID: ', peer.value, '. ID сущности: ', entity.id)
	cmd.add_components(entity, comps)
	print('[UserSpawnRequestSystem] Игрок с peer ID ', peer.value, ' был добавлен на сервер')
