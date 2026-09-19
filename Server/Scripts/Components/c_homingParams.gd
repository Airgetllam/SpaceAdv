extends Component
class_name C_HomingParams

@export var speed: float        # пикселей в секунду
@export var turn_rate: float      # радиан в секунду (макс. угловая скорость)

func _init(_speed: float = 0, _turn_rate: float = 0) -> void:
	speed = _speed
	turn_rate = _turn_rate
