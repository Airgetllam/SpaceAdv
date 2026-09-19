extends Component
class_name C_Damage

@export var value: int = 0
@export var radius: float = 0.0
@export var exploded: bool = false   # защита от повторного взрыва

func _init(_value: int = 0, _radius: float = 0.0) -> void:
	value = _value
	radius = _radius
