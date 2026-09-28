class_name PlayerInputAction
extends RefCounted

enum State {
	PRESSED,
	RELEASED,
}

var action_id: int = 0
var state: State = State.PRESSED
var value: float = 0.0
var position: Vector2 = Vector2.ZERO

func _init(
	_action_id: int,
	_pressed: bool,
	_value: float = 1.0,
	_position: Vector2 = Vector2.ZERO
) -> void:
	action_id = _action_id
	state = State.PRESSED if _pressed else State.RELEASED
	value = _value
	position = _position
