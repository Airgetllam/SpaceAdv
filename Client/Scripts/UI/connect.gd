extends Control

@onready var nick_line_edit: LineEdit = $VBoxContainer/HBoxContainer/LineEdit
@onready var pos_x_line_edit: LineEdit = $VBoxContainer/HBoxContainer2/LineEdit
@onready var pos_y_line_edit: LineEdit = $VBoxContainer/HBoxContainer3/LineEdit
@onready var connect_button: Button = $VBoxContainer/Button
@onready var status_label: Label = $VBoxContainer/Label
@onready var input_label: Label = $VBoxContainer/StatusLabel

var udp = PacketPeerUDP.new()
var connected = false

func _ready():
	connect_button.pressed.connect(_on_connect_pressed)

func _process(delta: float) -> void:
	
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
	
	var input_data = {"throttle": throttle, "turn": turn, "brake": brake, "cursor_pos": mouse_pos}
	var json = JSON.stringify(input_data)
	
	if connected:
		udp.put_packet(json.to_utf8_buffer())
	if udp.get_available_packet_count() > 0:
		pass
		#var packet = udp.get_packet()
		#var data = packet.get_string_from_utf8()
		#var _json = JSON.parse_string(data)

func _on_connect_pressed():
	udp.connect_to_host("127.0.0.1", 9999)
	connected = true
	connect_button.disabled = true
	var nick = nick_line_edit.text.strip_edges()
	if nick.is_empty():
		status_label.text = "Введите ник"
		return

	status_label.text = "Подключение..."




func _on_connected_to_server():
	status_label.text = "Подключено к серверу!"
	var scene = load("res://Client/Scenes/UI/control.tscn")
	var nick = nick_line_edit.text.strip_edges()
	var pos = Vector2(
		float(pos_x_line_edit.text),
		float(pos_y_line_edit.text)
	)




'''# client_node.gd
class_name ClientNode
extends Node

var udp = PacketPeerUDP.new()
var connected = false

func _ready():
	udp.connect_to_host("127.0.0.1", 4242)

func _process(delta):
	if !connected:
		# Попробуйте связаться с сервером
		udp.put_packet("The answer is... 42!".to_utf8_buffer())
	if udp.get_available_packet_count() > 0:
		print("Connected: %s" % udp.get_packet().get_string_from_utf8())
		connected = true'''
