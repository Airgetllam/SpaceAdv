extends System
class_name CursorInteractionSystem

# Для каждого курсора хранит цель, над которой он находится в данный момент (наведение)
var hover_map: Dictionary = {}  # Entity (курсор) -> Entity (цель) или null

# Для отслеживания нажатия мыши
var mouse_was_pressed: bool = false

func query() -> QueryBuilder:
	return q.with_all([C_CursorPosition, C_Targets])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var root = Engine.get_main_loop().root
	if not root:
		return

	var space_state = root.get_world_2d().direct_space_state
	if not space_state:
		return

	var mouse_pressed_now = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var click_just_pressed = mouse_pressed_now and not mouse_was_pressed
	mouse_was_pressed = mouse_pressed_now

	for entity in entities:
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		var targets: C_Targets = entity.get_component(C_Targets)
		if not cursor or not targets:
			continue

		# --- Определяем, что находится под курсором ---
		var params = PhysicsPointQueryParameters2D.new()
		params.position = cursor.position
		params.collide_with_areas = true
		params.collide_with_bodies = true
		var results = space_state.intersect_point(params)

		var new_hover_entity: Entity = null
		if results:
			var collider = results[0].collider
			if collider.has_meta("entity"):
				var possible_target = collider.get_meta("entity")
				if possible_target is Entity and possible_target != entity:
					new_hover_entity = possible_target

		# --- Получаем предыдущую цель наведения ---
		var old_hover_entity: Entity = hover_map.get(entity, null)

		# --- Если наведение изменилось, обновляем список наведений (state=0) ---
		if old_hover_entity != new_hover_entity:
			# Удаляем старую запись наведения (state=0), если она существует и не является выбранной
			if old_hover_entity != null:
				var idx = _find_target_index(targets, old_hover_entity)
				if idx >= 0:
					var dict = targets.list[idx]
					if dict['state'] == 0:
						targets.list.remove_at(idx)
						# Если компонент C_Target остался с state=0 и цель не выбрана, удаляем его
						if old_hover_entity.has_component(C_Target):
							var comp = old_hover_entity.get_component(C_Target)
							if comp.get_state() == 0:
								cmd.remove_component(old_hover_entity, comp)
					# Если dict['state'] == 1, запись остаётся (выбранная цель не удаляется)

			# Добавляем новую запись наведения, если цель не выбрана
			if new_hover_entity != null:
				var idx_new = _find_target_index(targets, new_hover_entity)
				if idx_new == -1:
					# Нет записи вообще — добавляем как наведение (state=0)
					var new_dict = {'state': 0, 'entity': new_hover_entity}
					targets.list.append(new_dict)
				else:
					# Запись есть, проверяем её состояние
					var existing_dict = targets.list[idx_new]
					if existing_dict['state'] == 1:
						# Цель уже выбрана, не добавляем отдельную запись наведения
						pass
					elif existing_dict['state'] == 0:
						# Уже есть наведение, ничего не меняем
						pass
			# Обновляем hover_map
			hover_map[entity] = new_hover_entity

		# --- Обработка клика ---
		if click_just_pressed:
			if new_hover_entity != null:
				# Клик по цели
				var idx = _find_target_index(targets, new_hover_entity)
				if idx >= 0:
					var dict = targets.list[idx]
					if dict['state'] == 1:
						# Отменяем выбор: state 1 -> 0 (наведение), так как курсор над целью
						dict['state'] = 0
						if new_hover_entity.has_component(C_Target):
							new_hover_entity.get_component(C_Target).set_state(0)
					else:  # state == 0
						# Выбираем: state 0 -> 1
						dict['state'] = 1
						if new_hover_entity.has_component(C_Target):
							new_hover_entity.get_component(C_Target).set_state(1)
				else:
					# Записи не было — создаём выбранную цель (state=1)
					var new_dict = {'state': 1, 'entity': new_hover_entity}
					targets.list.append(new_dict)
			else:
				# Клик в пустоту — отменяем все выбранные цели (state=1)
				for i in range(targets.list.size() - 1, -1, -1):
					var dict = targets.list[i]
					if dict['state'] == 1:
						var target_entity = dict['entity']
						# Удаляем запись
						targets.list.remove_at(i)
						# Удаляем компонент C_Target
						if target_entity.has_component(C_Target):
							cmd.remove_component(target_entity, target_entity.get_component(C_Target))
			# После клика может потребоваться синхронизировать hover_map? Нет, hover_map не меняется

# Вспомогательная функция: поиск индекса записи по entity в списке целей
func _find_target_index(targets: C_Targets, entity: Entity) -> int:
	for i in range(targets.list.size()):
		if targets.list[i]['entity'] == entity:
			return i
	return -1
