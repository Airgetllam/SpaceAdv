extends System
class_name FrameGenerateSystem

func query() -> QueryBuilder:
	return q.with_all([C_Targets])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var ui_node = get_tree().current_scene.get_node_or_null("World/UI")
	if not ui_node:
		return

	var frames: Array = []

	for entity in entities:
		var targets: C_Targets = entity.get_component(C_Targets)
		if not targets:
			continue

		for target_dict in targets.list:
			var state: int = target_dict.get('state', 0)
			var target_entity: Entity = target_dict.get('entity', null)
			if not target_entity:
				continue

			# Проверяем наличие необходимых компонентов
			if not target_entity.has_component(C_Size) or not target_entity.has_component(C_Position):
				continue

			var size: C_Size = target_entity.get_component(C_Size)
			var pos: C_Position = target_entity.get_component(C_Position)

			# Генерируем уголки с учётом позиции цели
			var corners = FrameGenerator.frame_generate(pos.value, size.value)

			var color: Color
			if state == 1:
				color = Color.ORANGE   # выбранная цель
			else:
				color = Color.WHITE    # цель под курсором

			frames.append({
				'points': corners,
				'color': color
			})

	# Всегда передаём актуальный список (пустой, если целей нет)
	ui_node.set_frames(frames)
