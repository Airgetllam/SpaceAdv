extends Component
class_name C_StateChanged

@export var list: Array = []
@export var damage: int = 0

func _init(_list: Array = [], _damage: int = 0) -> void:
	list = _list
	damage = _damage
