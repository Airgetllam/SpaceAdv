extends Node

func _ready():
	var args = OS.get_cmdline_args()
	var is_server = "--server" in args
	var is_client = "--client" in args

	# Определяем сцену по аргументу
	var scene_path = "res://Client/Scenes/UI/spawn.tscn"
	if is_server:
		scene_path = "res://Server/Scenes/server.tscn"

	# Откладываем загрузку сцены до следующего кадра
	call_deferred("_deferred_load_scene", scene_path)

func _deferred_load_scene(path: String):
	var scene = load(path)
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		print("Ошибка загрузки сцены: ", path)
