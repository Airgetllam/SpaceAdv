extends Observer
class_name UserSpawnRequestObserver

func query() -> QueryBuilder:
	return q.with_all([C_PeerID]).on_added()

func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var comps = [
		C_ExistenceState.new(),
		C_RigidBody.new(),
		C_Force.new(),
		C_Velocity.new(),
		C_AngularVelocity.new(),
		C_ControlInput.new(),
		C_CursorPosition.new(),
		C_Modules.new(),
		C_Targets.new()
	]
	cmd.add_components(entity, comps)
