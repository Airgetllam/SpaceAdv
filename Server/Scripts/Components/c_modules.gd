extends Component
class_name C_Modules

const BLOCK_RESOURCES: Array[Resource] = [
	preload("res://Server/Resources/Blocks/ammo.tres"),
	preload("res://Server/Resources/Blocks/armor.tres"),
	preload("res://Server/Resources/Blocks/barrel.tres"),
	preload("res://Server/Resources/Blocks/breech.tres"),
	preload("res://Server/Resources/Blocks/engine.tres"),
	preload("res://Server/Resources/Blocks/reactor.tres"),
]


@export var list: Array[Dictionary]
@export var available_blocks: Array[BlockDefinition] = []
@export var blocks_textures: Dictionary = {}

# временно
func _init() -> void:
	_load_blocks()
	blocks_textures = _define_textures(available_blocks)
	var ship_def = load("res://Client/Resources/all_blocks_test.tres")
	list = ship_def.modules_data


func _load_blocks() -> void:
	available_blocks.clear()
	for res in BLOCK_RESOURCES:
		if res is BlockDefinition:
			available_blocks.append(res)
		else:
			push_warning("C_Modules: %s is not a BlockDefinition" % res.resource_path)



func _define_textures(blocks: Array[BlockDefinition]) -> Dictionary:
	var result = {}
	for i in blocks:
		result[i.id] = i.texture
	return result
