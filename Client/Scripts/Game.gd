extends Node2D
class_name Game

@onready var _world: World = $World
@onready var _camera: Camera2D = $Camera2D
@onready var _projectile_mm: MultiMeshInstance2D = $ProjectileMultiMesh
@onready var _ship_mm: MultiMeshInstance2D = $ShipDebug

func _ready() -> void:
	print("GAME SCENE READY")
	ECS.world = _world

	# Корневая сущность — «якорь» для tick-систем клиента.
	var root := Entity.new()
	ClientSession.game_node = self
	root.name = "client_root"
	root.add_component(C_ClientRoot.new())
	_world.add_entity(root)

	_world.add_system(ClientNetworkReceiveSystem.new())
	_world.add_system(ClientInputSystem.new())
	_world.add_system(ClientPredictionSystem.new())
	_world.add_system(ClientInterpolationSystem.new())
	_world.add_system(ClientRenderSystem.new())

	_setup_projectile_multimesh()
	_setup_ship_multimesh()

	# Autoload-сброс → передача в системы
	# (нет, не сбрасываем — состояние уже лежит в ClientSession)
	NetLog.d("client", "Game scene ready (net_id=%d)" % ClientSession.net_id)

func _process(delta: float) -> void:
	ECS.process(delta)

	# Камера следует за локальным кораблём
	var me = ClientSession.get_entity(ClientSession.net_id)
	if me != null and is_instance_valid(me):
		var p: C_Position = me.get_component(C_Position)
		if p != null:
			_camera.position = p.value

func _setup_projectile_multimesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = 512
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 8)
	mm.mesh = quad
	for i in mm.instance_count:
		mm.set_instance_color(i, Color.YELLOW)
	_projectile_mm.multimesh = mm
	_projectile_mm.z_index = 10

func _setup_ship_multimesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = 64
	var quad := QuadMesh.new()
	quad.size = Vector2(16, 16)
	mm.mesh = quad
	for i in mm.instance_count:
		mm.set_instance_color(i, Color.CYAN)
	_ship_mm.multimesh = mm
	_ship_mm.z_index = 5
