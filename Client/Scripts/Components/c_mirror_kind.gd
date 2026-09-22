extends Component
class_name C_MirrorKind

@export var kind: int = 1                # 1=ship, 2=projectile
@export var is_projectile: bool = false
@export var owner_net_id: int = 0
@export var target_net_id: int = 0
@export var alive_mask: PackedByteArray = PackedByteArray()

func _init(_kind: int = 1, _owner: int = 0, _target: int = 0) -> void:
	kind = _kind
	owner_net_id = _owner
	target_net_id = _target
	is_projectile = (_kind == 2)
