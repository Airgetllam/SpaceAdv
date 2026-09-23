extends Component
class_name C_MirrorKind

@export var kind: int = 1
@export var is_projectile: bool = false
@export var owner_net_id: int = 0
@export var target_net_id: int = 0
@export var alive_mask: PackedByteArray = PackedByteArray()
@export var blocks_layout: Array = []      # Array[Vector2i], qx/qy × 2
@export var blocks_hp: Array = []          # Array[int] — NEW
@export var blocks_hp_max: Array = []      # Array[int] — NEW
@export var hp: int = 0
@export var hp_max: int = 0

func _init(_kind: int = 1, _owner: int = 0, _target: int = 0) -> void:
	kind = _kind
	owner_net_id = _owner
	target_net_id = _target
	is_projectile = (_kind == 2)
