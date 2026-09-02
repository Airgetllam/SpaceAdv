extends Component
class_name C_Target

@export var state: int
@export var object: Array

func  _init(obj: Entity) -> void:
	object.append(obj)

func set_state(_state):
	state = _state

func get_state() -> int:
	return state
