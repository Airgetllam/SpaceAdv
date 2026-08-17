extends System
class_name NetworkConnectSystem

var peer = ENetMultiplayerPeer.new()

func query() -> QueryBuilder:
	return q.with_all([C_MultiplayerSpawnerRef])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var ref_comp: C_MultiplayerSpawnerRef = entity.get_component(C_MultiplayerSpawnerRef)
		var spawner: MultiplayerSpawner = _get_node_or_null(ref_comp.spawner_path)
		if spawner:
			spawner.spawn_function = spawn_player
			spawner.spawn("res://Server/Scenes/ship.tscn")

func _get_node_or_null(path: NodePath) -> Node:
	return Engine.get_main_loop().get_root().get_node(path)

func spawn_player(ref_ship) -> Node:
	var player_scene = load(ref_ship)
	return player_scene.instantiate()
