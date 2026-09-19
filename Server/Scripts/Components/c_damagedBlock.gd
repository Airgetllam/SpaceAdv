extends Component
class_name C_DamagedBlock

@export var block_pos: Array
@export var value: int

func _init(pos: Array, val: int) -> void:
	block_pos = pos
	value = val
