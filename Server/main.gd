extends Node
class_name Server

@onready var _world = $World
var _net_accum: float = 0.0

func _ready() -> void:
	ECS.world = _world

	var systems := {
		"cleanup": CleanupSystem.new(),
		"life_timer": LifeTimerSystem.new(),
		"net_control": NetworkControlSystem.new(),
		"net_registration": NetworkPeerRegistrationSystem.new(),

		"admin_cursor_sync": AdminCursorSyncSystem.new(),
		"admin_cursor_interaction": AdminCursorInteractionSystem.new(),
		"admin_atack": AdminAtackSystem.new(),
		"debug": AdminDebugVisualSystem.new(),
		"debug_cleanup": AdminDebugCleanupSystem.new(),
		"test": TestSystem.new(),

		"aoi": AOISystem.new(),
		"net_send": NetworkSendSystem.new(),

		"movement": MovementSystem.new(),
		"player_ability": PlayerAbilitySystem.new(),
		"player_heal": PlayerHealSystem.new(),
		"target_selection": PlayerTargetSelectionSystem.new(),
		"player_fire": PlayerFireSystem.new(),
		"transform_sync": TransformSyncSystem.new(),
		"velocity_apply": VelocityApplySystem.new(),
		"damage_control": DamageControlSystem.new(),
		"params_sync": ParamsSyncSystem.new(),
		"frame_create": FrameGenerateSystem.new(),
		"target_aiming": TargetAimingSystem.new(),
		"hit": HitSystem.new(),
		"explosion": ExplosionSystem.new(),
		"contact_system": BodyContactSystem.new()
	}

	var observers := [
		NetIdAssignObserver.new(),
		ProjectileSpawnObserver.new(),
		UserSpawnRequestObserver.new(),
		SpawnPositionSyncObserver.new(),
		MultimeshCreationObserver.new(),
		RigidbodyInitObserver.new(),
		ColliderCreationObserver.new(),
		SizeDefineObserver.new(),
		ParamsGenerateObserver.new(),
		RenderInitObserver.new(),
		AmmoControlInitObserver.new(),
	]

	systems["transform_sync"].group = "physics"

	systems["frame_create"].group = "UI"

	systems["admin_cursor_sync"].group = "admin"
	systems["admin_cursor_interaction"].group = "admin"
	systems["admin_atack"].group = "admin"
	systems["debug"].group = "admin"
	systems["debug_cleanup"].group = "admin"

	systems["aoi"].group = "network"
	systems["net_send"].group = "network"

	systems["movement"].group = "physics"
	systems["player_ability"].group = "physics"
	systems["player_heal"].group = "physics"
	systems["target_selection"].group = "physics"
	systems["player_fire"].group = "physics"

	for system_name in systems.keys():
		var system = systems[system_name]
		system.name = system_name
		_world.add_system(system)
	_world.add_observers(observers)



	_create_entity('server', [
		C_ServerIP.new(),
		C_Position.new(),
		C_CursorPosition.new(),
		C_Targets.new()
	], _world)
	
	_create_entity('test', [
		C_EntityType.new("test"),
		C_Position.new(Vector2(500, 500)),
		C_Direction.new(45.0),
		C_Blocks.new({Vector2(0,0): {"block_id": 1, "block_hp": 100, "block_hp_max": 100, "destroy": false}})
	], _world)


func _process(delta: float) -> void:
	ECS.process(delta)
	ECS.process(delta, "admin")
	ECS.process(delta, "UI")
	_net_accum += delta
	if _net_accum >= NetConfig.SERVER_TICK_DT:
		_net_accum -= NetConfig.SERVER_TICK_DT
		ECS.process(NetConfig.SERVER_TICK_DT, "network")


func _physics_process(delta: float) -> void:
	ECS.process(delta, "physics")


func _create_entity(_name: String, components: Array, _world_: World) -> void:
	var _entity = Entity.new()
	_entity.name = _name
	_entity.set_meta('entity_id', _entity.id)
	_world_.add_entity(_entity)
	for component in components:
		_entity.add_component(component)
