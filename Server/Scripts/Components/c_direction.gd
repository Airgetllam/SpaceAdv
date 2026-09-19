extends Component
class_name C_Direction

@export var value: float:
	set(new_value):
		if value != new_value:
			var old_value = value
			value = new_value
			property_changed.emit(self, 'value', old_value, new_value)

func _init(_value: float = 0) -> void:
	print("[CDir init] value=", _value)
	value = _value
