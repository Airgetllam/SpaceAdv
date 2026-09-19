extends System
class_name AdminDebugVisualSystem

# Узел-контейнер для Label'ов и отрисовки (World/UI)
var ui_node: Node2D = null

# Данные для отрисовки квадратов
var debug_positions: Array = []
var square_size: float = 32.0
var outline_color: Color = Color.RED
var outline_width: float = 2.0

# Внутренний узел для отрисовки (чтобы не засорять UI)
var _outline_node: Node2D = null

func query() -> QueryBuilder:
	return q.with_all([C_Debug, C_Position, C_EntityName])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	# Ленивая инициализация UI
	if ui_node == null or not is_instance_valid(ui_node):
		ui_node = _get_ui_node()
		if ui_node == null:
			return

	# Ленивая инициализация узла отрисовки
	if _outline_node == null or not is_instance_valid(_outline_node):
		_outline_node = _get_or_create_outline_node()
		if _outline_node == null:
			return

	# Собираем активные сущности для очистки мёртвых лейблов
	var active_entities: Dictionary = {}
	debug_positions.clear()

	for entity in entities:
		if not is_instance_valid(entity):
			continue

		active_entities[entity] = true

		var pos: C_Position = entity.get_component(C_Position)
		var name_comp: C_EntityName = entity.get_component(C_EntityName)
		if not pos or not name_comp:
			continue

		# Собираем позицию для отрисовки квадрата
		debug_positions.append(pos.value)

		# Получаем или создаём Label
		var label: Label = _get_label_for_entity(entity)
		if label == null:
			label = _create_label_for_entity(entity)
			if label == null:
				continue

		label.text = name_comp.value
		label.global_position = pos.value

	# Обновляем отрисовку квадратов
	_outline_node.set("positions", debug_positions)
	_outline_node.set("square_size", square_size)
	_outline_node.set("outline_color", outline_color)
	_outline_node.set("outline_width", outline_width)
	_outline_node.queue_redraw()

# --- Вспомогательные методы ---

func _get_ui_node() -> Node2D:
	var root = Engine.get_main_loop().root
	if not root:
		return null

	# Ищем узел по пути World/UI
	var world = root.find_child("World", true, false)
	if world:
		var ui = world.find_child("UI", true, false)
		if ui is Node2D:
			return ui

	# Если не нашли — ищем по имени в корне
	var fallback = root.find_child("UI", true, false)
	if fallback is Node2D:
		return fallback

	print("[AdminDebugVisualSystem] Узел World/UI не найден")
	return null

func _get_label_for_entity(entity: Entity) -> Label:
	if not entity.has_meta("debug_label"):
		return null
	var label = entity.get_meta("debug_label")
	if not is_instance_valid(label):
		entity.remove_meta("debug_label")
		return null
	return label

func _create_label_for_entity(entity: Entity) -> Label:
	if ui_node == null:
		return null

	var label = Label.new()
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 24)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("entity", entity)   # ← ключевая строка
	ui_node.add_child(label)

	entity.set_meta("debug_label", label)
	return label



func _get_or_create_outline_node() -> Node2D:
	if ui_node == null:
		return null

	# Ищем существующий узел отрисовки внутри UI
	var existing = ui_node.find_child("AdminDebugOutlines", false, false)
	if existing is Node2D:
		return existing

	var script = GDScript.new()
	script.source_code = """
extends Node2D

var positions: Array = []
var square_size: float = 32.0
var outline_color: Color = Color.RED
var outline_width: float = 2.0

func _draw() -> void:
    for pos in positions:
        var half = square_size * 0.5
        var rect = Rect2(pos - Vector2(half, half), Vector2(square_size, square_size))
        draw_rect(rect, outline_color, false, outline_width)
"""
	script.reload()

	var node = Node2D.new()
	node.name = "AdminDebugOutlines"
	node.set_script(script)
	node.z_index = 99
	ui_node.add_child(node)
	return node
