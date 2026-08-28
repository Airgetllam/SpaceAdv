extends Component
class_name C_Position

@export var value: Vector2 = Vector2.ZERO:
	set(new_value):
		if value != new_value:
			var old_value = value
			value = new_value
			property_changed.emit(self, 'value', old_value, new_value)

func _init(pos: Vector2 = Vector2.ZERO) -> void:
	value = pos
