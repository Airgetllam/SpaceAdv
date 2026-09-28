class_name PlayerInputFrame
extends RefCounted

# Непрерывный ввод на один input tick.
var throttle: float = 0.0
var turn: float = 0.0
var brake: bool = false

# Мировая позиция курсора.
var cursor_position: Vector2 = Vector2.ZERO

# Текущее состояние зарегистрированных действий.
# bit N == 1 -> action N зажат.
var pressed_actions_mask: int = 0

# Дискретные переходы, накопленные с момента
# предыдущего consume_frame().
var events: Array[PlayerInputAction] = []

func is_action_pressed(action_id: int) -> bool:
	if action_id < 0 or action_id >= 63:
		return false

	return (pressed_actions_mask & (1 << action_id)) != 0
