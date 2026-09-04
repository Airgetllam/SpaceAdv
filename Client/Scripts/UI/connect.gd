extends Control

@onready var nick_line_edit: LineEdit = $VBoxContainer/HBoxContainer/LineEdit
@onready var pos_x_line_edit: LineEdit = $VBoxContainer/HBoxContainer2/LineEdit
@onready var pos_y_line_edit: LineEdit = $VBoxContainer/HBoxContainer3/LineEdit
@onready var connect_button: Button = $VBoxContainer/Button
@onready var status_label: Label = $VBoxContainer/Label
@onready var input_label: Label = $VBoxContainer/StatusLabel

var udp = PacketPeerUDP.new()
var connected = false
var session_id = null
var session_received = false


func _ready():
	connect_button.pressed.connect(_on_connect_pressed)

func _process(delta: float) -> void:
	if udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var data_str = packet.get_string_from_utf8()
		var json = JSON.parse_string(data_str)
		if json:
			if json.has("type") and json.type == "session" and json.has("session_id"):
				session_id = json.session_id
				session_received = true
				status_label.text = "Получен session_id: %d" % session_id
			elif json.has("type") and json.type == "disconnect":
				session_received = false
				connected = false
				status_label.text = "Сервер разорвал соединение"
				input_label.text = ""
				connect_button.disabled = false


	if not session_received:
		return

	var throttle = Input.get_axis("thrust_down", "thrust_up")
	var turn = Input.get_axis("rotate_minus", "rotate_plus")
	var brake = Input.is_action_pressed("inertia_break")
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	var mouse_pos = camera.get_global_mouse_position() if camera else viewport.get_mouse_position()

	# Отображение
	input_label.text = "Тяга: %d\nПоворот: %d\nТормоз: %s\nКурсор: (%d, %d)" % [
		throttle,
		turn,
		"вкл" if brake else "выкл",
		mouse_pos.x,
		mouse_pos.y
	]

	var input_data = {
		"throttle": throttle, 
		"turn": turn, 
		"brake": brake, 
		"cursor_pos": mouse_pos, 
		"session_id": session_id
	}

	if session_id != null:
		input_data["session_id"] = session_id

	var json = JSON.stringify(input_data)
	udp.put_packet(json.to_utf8_buffer())

func _on_connect_pressed():
	# Проверяем ник
	var nick = nick_line_edit.text.strip_edges()
	if nick.is_empty():
		status_label.text = "Введите ник"
		return

	# Подключаемся к серверу
	var err = udp.connect_to_host("127.0.0.1", 9999)
	if err != OK:
		status_label.text = "Ошибка подключения"
		return

	connected = true
	connect_button.disabled = true
	status_label.text = "Подключено, отправка данных..."

	# Читаем координаты (с защитой от ошибок)
	var pos_x = float(pos_x_line_edit.text) if pos_x_line_edit.text.is_valid_float() else 0.0
	var pos_y = float(pos_y_line_edit.text) if pos_y_line_edit.text.is_valid_float() else 0.0

	# Формируем пакет с данными подключения
	var connect_data = {
		"type": "connect",
		"nick": nick,
		"spawn_pos": [pos_x, pos_y]   # или отдельными полями
	}
	var json = JSON.stringify(connect_data)
	udp.put_packet(json.to_utf8_buffer())

	status_label.text = "Данные отправлены, ожидаем игровой мир..."
