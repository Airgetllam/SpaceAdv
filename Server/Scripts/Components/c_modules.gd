extends Component
class_name C_Modules

@export var list: Array[Dictionary]
@export var available_blocks: Array[BlockDefinition] = []
@export var blocks_textures: Dictionary = {}

# временно
func _init() -> void:
	_load_blocks()
	blocks_textures = _define_textures(available_blocks)
	var ship_def = load("res://Client/Resources/all_blocks_test.tres")
	list = ship_def.modules_data


func _load_blocks():
	var dir = DirAccess.open(ServerConfig.BLOCK_PATH)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != '':
		if file_name.ends_with('.tres'):
			var full_path = ServerConfig.BLOCK_PATH + file_name
			var res = load(full_path)
			available_blocks.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _define_textures(blocks: Array[BlockDefinition]) -> Dictionary:
	var result = {}
	for i in blocks:
		result[i.id] = i.texture
	return result
