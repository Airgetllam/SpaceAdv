extends Component
class_name C_ExistenceState

@export var value: int = 1:
	set(new_value):
		if value != new_value:
			var old_value = value
			value = new_value
			property_changed.emit(self, 'value', old_value, new_value)

func _init() -> void:
	value = 1
