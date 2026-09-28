class_name InputActions
extends RefCounted

# Стабильные ID действий.
# Эти значения становятся частью общего input-моделя,
# но пока ещё не являются сетевыми ID сообщений.
const PRIMARY_FIRE: int = 0
const SECONDARY_FIRE: int = 1
const TARGET_SELECT: int = 2

# Соответствие ID -> InputMap action.
const ACTION_NAMES: Array[StringName] = [
	&"fire",
	&"fire_alt",
	&"target_select",
]
