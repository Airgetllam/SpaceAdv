extends Node
class_name Server

@onready var _world = $World


func _ready() -> void:
	ECS.world = _world

	var systems := {
		"cleanup": CleanupSystem.new(),
		"network_control": NetworkControlSystem.new(),
		"peer_reg": NetworkPeerRegistrationSystem.new(),
		"admin_cursor_sync": AdminCursorSyncSystem.new(),
		"admin_atack": AdminAtackSystem.new(),
		"cursor_interaction": CursorInteractionSystem.new(),
		"position_sync": PositionSyncSystem.new(),
		"control": ControlSystem.new(),
		"force_apply": ForceApplySystem.new(),
		"angular_velocity_apply": AngularVelocityApplySystem.new(),
		"damage_control": DamageControlSystem.new(),
		"params_sync": ParamsSyncSystem.new(),
		"frame_create": FrameGenerateSystem.new(),
		"target_aiming": TargetAimingSystem.new(),
		"target_force_apply": TargetForceApplySystem.new()
	}

	var observers := [
		UserSpawnRequestObserver.new(),
		SpawnPositionSyncObserver.new(),
		MultimeshCreationObserver.new(),
		RigidbodyInitObserver.new(),
		ColliderCreationObserver.new(),
		SizeDefineObserver.new(),
		RenderInitObserver.new(),
		PositionToRigidbodyObserver.new()
	]

	for system in systems.values():
		_world.add_system(system)
	_world.add_observers(observers)

	systems["control"].group = "physics"
	systems["force_apply"].group = "physics"
	systems["angular_velocity_apply"].group = "physics"
	systems["frame_create"].group = "UI"
	systems["admin_cursor_sync"].group = "admin"

	_create_entity('server', [
		C_ServerIP.new(),
		C_Position.new(),
		C_CursorPosition.new(),
		C_Targets.new()
	], _world)


func _process(delta: float) -> void:
	ECS.process(delta)


func _physics_process(delta: float) -> void:
	ECS.process(delta, "physics")


func _create_entity(_name: String, components: Array, _world_: World) -> void:
	var _entity = Entity.new()
	_entity.name = _name
	_entity.set_meta('entity_id', _entity.id)
	for component in components:
		_entity.add_component(component)
	_world_.add_entity(_entity)
