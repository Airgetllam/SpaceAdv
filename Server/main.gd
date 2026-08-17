extends Node
class_name Server

@onready var _world = $World
@onready var spawner = $MultiplayerSpawner
@onready var ship = load("res://Server/Scenes/ship.tscn")


func _ready() -> void:
	ECS.world = _world
	_world.add_system(SpawnRequestSystem.new())
	_world.add_system(NetworkConnectSystem.new())
	
	var server = Entity.new()
	server.add_component(C_ServerIP.new())
	_world.add_entity(server)
	
	var spawner_entity = Entity.new()
	var ref_comp = C_MultiplayerSpawnerRef.new()
	ref_comp.spawner_path = spawner.get_path()
	spawner_entity.add_component(ref_comp)
	spawner_entity.add_component(C_SpawnRequest.new())
	
	_world.add_entity(spawner_entity)


func _process(delta: float) -> void:
	ECS.process(delta)
