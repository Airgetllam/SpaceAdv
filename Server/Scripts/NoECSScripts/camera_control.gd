extends Camera2D

@export var move_speed: float = 500.0        # скорость перемещения (пикселей/сек)
@export var zoom_speed: float = 0.1          # шаг зума за одно деление колесика
@export var zoom_min: float = 0.2            # минимальный зум (отдаление)
@export var zoom_max: float = 3.0            # максимальный зум (приближение)
@export var smooth_zoom: bool = true         # плавный зум
@export var zoom_lerp_speed: float = 10.0    # скорость сглаживания зума

var _target_zoom: Vector2

func _ready() -> void:
	_target_zoom = zoom

func _process(delta: float) -> void:
	# 1. Перемещение камеры на WASD
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		# Двигаем в мировых координатах с учётом зума, чтобы скорость была одинаковой
		global_position += input_dir * move_speed * delta / zoom

	# 2. Плавное приближение к целевому зуму
	if smooth_zoom:
		zoom = zoom.lerp(_target_zoom, zoom_lerp_speed * delta)
	else:
		zoom = _target_zoom

func _unhandled_input(event: InputEvent) -> void:
	# Зум колёсиком мыши
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom *= 1.0 + zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom *= 1.0 - zoom_speed
		_target_zoom.x = clamp(_target_zoom.x, zoom_min, zoom_max)
		_target_zoom.y = clamp(_target_zoom.y, zoom_min, zoom_max)
		if not smooth_zoom:
			zoom = _target_zoom
