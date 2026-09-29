extends Component
class_name C_LastServerState

@export var pos: Vector2 = Vector2.ZERO
@export var rot: float = 0.0
@export var vel: Vector2 = Vector2.ZERO

# ACK, которому соответствует pos/rot/vel.
@export var last_acked_seq: int = 0

# Самый новый ACK input, увиденный от сервера.
# Может обновляться даже MSG_STATE с count == 0.
@export var last_input_ack_seq: int = 0

@export var last_reconciled_seq: int = 0

@export var dirty: bool = false
