extends Component
class_name C_InterpTarget

@export var prev_pos: Vector2 = Vector2.ZERO
@export var curr_pos: Vector2 = Vector2.ZERO
@export var prev_rot: float = 0.0
@export var curr_rot: float = 0.0
@export var t: float = 1.0            # 0..1, интерполируется в системе
@export var has_target: bool = false
