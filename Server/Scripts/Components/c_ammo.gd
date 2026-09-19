extends Component
class_name C_Ammo

@export var value: int = 0
@export var value_max: int = 0
@export var value_ammo_count: int =0
@export var value_cd: float = 0.25

func _init(v: int = 0, v_m: int = 0) -> void:
	value = v
	value_max = v_m
	value_ammo_count = v * 100
