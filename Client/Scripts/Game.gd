extends Node2D
class_name Game

const BLOCK_TEXTURES := {
	0: preload("res://Client/Sprites/0_armor.png"),
	1: preload("res://Client/Sprites/1_barrel.png"),
	2: preload("res://Client/Sprites/2_ammo.png"),
	3: preload("res://Client/Sprites/3_engine.png"),
	4: preload("res://Client/Sprites/4_reactor.png"),
	5: preload("res://Client/Sprites/5_breech.png"),
}

const MAX_BLOCKS_PER_TYPE: int = 64

@onready var _world: World = $World
@onready var _camera: Camera2D = $Camera2D
@onready var _projectile_mm: MultiMeshInstance2D = $ProjectileMultiMesh
@onready var _ship_mm: MultiMeshInstance2D = $ShipDebug

var _block_mm: Dictionary = {}   # block_id:int → MultiMeshInstance2D
var _remote_blocks_mm: MultiMeshInstance2D = null


func _ready() -> void:
	print("GAME SCENE READY")
	ECS.world = _world
	ClientSession.game_node = self

	var root := Entity.new()
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
	_setup_block_multimeshes()
	_setup_remote_blocks_multimesh()

	NetLog.d("client", "Game scene ready (net_id=%d)" % ClientSession.net_id)

func _process(delta: float) -> void:
	ECS.process(delta)

	var me = ClientSession.get_entity(ClientSession.net_id)
	if me != null and is_instance_valid(me):
		var p: C_Position = me.get_component(C_Position)
		if p != null:
			_camera.position = p.value

func get_block_mm(block_id: int) -> MultiMeshInstance2D:
	return _block_mm.get(block_id)

func get_remote_blocks_mm() -> MultiMeshInstance2D:
	return _remote_blocks_mm

func _setup_remote_blocks_multimesh() -> void:
	_remote_blocks_mm = MultiMeshInstance2D.new()
	_remote_blocks_mm.name = "RemoteBlocksMultiMesh"
	_remote_blocks_mm.z_index = 1
	_remote_blocks_mm.texture = preload("res://Client/Sprites/white.png")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = 4096   # 30 кораблей × 75 блоков = 2250, с запасом
	mm.mesh = _make_cell_mesh(ServerConfig.CELL_SIZE)
	mm.visible_instance_count = 0
	_remote_blocks_mm.multimesh = mm
	add_child(_remote_blocks_mm)

func reset_block_render_counters() -> void:
	for id in _block_mm:
		_block_mm[id].multimesh.visible_instance_count = 0
	if _remote_blocks_mm != null:
		_remote_blocks_mm.multimesh.visible_instance_count = 0

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

func _setup_block_multimeshes() -> void:
	for block_id in BLOCK_TEXTURES.keys():
		var mmi := MultiMeshInstance2D.new()
		mmi.name = "BlockMM_%d" % block_id
		mmi.z_index = 0
		mmi.texture = BLOCK_TEXTURES[block_id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.instance_count = MAX_BLOCKS_PER_TYPE
		mm.mesh = _make_cell_mesh(ServerConfig.CELL_SIZE)
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		add_child(mmi)
		_block_mm[block_id] = mmi

func _make_cell_mesh(size: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	var s := float(size)
	arrays[ArrayMesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(0, 0), Vector2(s, 0),
		Vector2(0, s), Vector2(s, 0),
		Vector2(s, s), Vector2(0, s)
	])
	arrays[ArrayMesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),
		Vector2(0, 1), Vector2(1, 0),
		Vector2(1, 1), Vector2(0, 1)
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
