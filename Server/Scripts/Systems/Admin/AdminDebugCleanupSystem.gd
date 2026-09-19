extends System
class_name AdminDebugCleanupSystem

var ui_node: Node2D = null
var outline_node: Node2D = null

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if ui_node == null or not is_instance_valid(ui_node):
		ui_node = _find_ui_node()
		if ui_node == null:
			return

	if outline_node == null or not is_instance_valid(outline_node):
		outline_node = ui_node.find_child("AdminDebugOutlines", false, false)
		if not (outline_node is Node2D):
			outline_node = null

	# --- Очистка осиротевших Label'ов ---
	for child in ui_node.get_children():
		if not is_instance_valid(child):
			continue
		if not (child is Label):
			continue

		if not child.has_meta("entity"):
			child.queue_free()
			continue

		var entity = child.get_meta("entity")
		if not is_instance_valid(entity):
			child.queue_free()

	# --- Очистка отрисовки, если в мире нет активных debug-сущностей ---
	if outline_node:
		var debug_entities = ECS.world.query.with_all([C_Debug, C_Position, C_EntityName]).execute()
		if debug_entities.is_empty():
			var positions = outline_node.get("positions")
			if positions is Array and not positions.is_empty():
				positions.clear()
				outline_node.queue_redraw()

func _find_ui_node() -> Node2D:
	var root = Engine.get_main_loop().root
	if not root:
		return null
	var world = root.find_child("World", true, false)
	if world:
		var ui = world.find_child("UI", true, false)
		if ui is Node2D:
			return ui
	var fallback = root.find_child("UI", true, false)
	if fallback is Node2D:
		return fallback
	return null
