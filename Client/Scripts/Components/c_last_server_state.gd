extends Component
class_name C_LastServerState

@export var pos: Vector2 = Vector2.ZERO
@export var rot: float = 0.0
@export var vel: Vector2 = Vector2.ZERO
@export var last_acked_seq: int = 0
@export var last_reconciled_seq: int = 0
@export var dirty: bool = false      # ставится в true при приёме MSG_STATE, сбрасывает Prediction
