class_name PlayerInputMapper
extends RefCounted

var _throttle: float = 0.0
var _turn: float = 0.0
var _brake: bool = false
var _cursor_position: Vector2 = Vector2.ZERO

var _pressed_actions_mask: int = 0
var _pending_events: Array[PlayerInputAction] = []

func capture() -> void:
	# Continuous input.
	_throttle = Input.get_axis(&"thrust_down", &"thrust_up")
	_turn = Input.get_axis(&"rotate_minus", &"rotate_plus")
	_brake = Input.is_action_pressed(&"inertia_break")

	# Cursor.
	if is_instance_valid(ClientSession.game_node):
		_cursor_position = ClientSession.game_node.get_global_mouse_position()

	# Registered discrete actions.
	_pressed_actions_mask = 0

	for action_id in InputActions.ACTION_NAMES.size():
		var action_name: StringName = InputActions.ACTION_NAMES[action_id]

		if Input.is_action_pressed(action_name):
			_pressed_actions_mask |= 1 << action_id

		if Input.is_action_just_pressed(action_name):
			_pending_events.append(
				PlayerInputAction.new(
					action_id,
					true,
					1.0,
					_cursor_position
				)
			)

		if Input.is_action_just_released(action_name):
			_pending_events.append(
				PlayerInputAction.new(
					action_id,
					false,
					0.0,
					_cursor_position
				)
			)

func consume_frame() -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()

	frame.throttle = _throttle
	frame.turn = _turn
	frame.brake = _brake
	frame.cursor_position = _cursor_position
	frame.pressed_actions_mask = _pressed_actions_mask
	frame.events = _pending_events

	_pending_events = []

	return frame
