extends Component
class_name C_SpawnPoint

@export var value: Vector2 = Vector2.ZERO
@export var angle_value: float = 0

func _init(_value: Vector2 = Vector2.ZERO, _ang_value: float = 0) -> void:
	value = _value
	angle_value = _ang_value
