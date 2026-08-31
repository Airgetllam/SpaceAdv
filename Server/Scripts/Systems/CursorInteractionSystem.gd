extends System
class_name CursorInteractionSystem

# Храним текущую цель для каждой сущности с C_CursorPosition
var current_targets: Dictionary = {}  # key: Entity, value: Entity (цель) или null

func query() -> QueryBuilder:
	return q.with_all([C_CursorPosition])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var root = Engine.get_main_loop().root
	if not root:
		return

	var space_state = root.get_world_2d().direct_space_state
	if not space_state:
		return

	for entity in entities:
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		if not cursor:
			continue

		# Выполняем физический запрос под курсором
		var params = PhysicsPointQueryParameters2D.new()
		params.position = cursor.position
		params.collide_with_areas = true
		params.collide_with_bodies = true
		var results = space_state.intersect_point(params)

		var new_target: Entity = null
		if results:
			var collider = results[0].collider
			# Безопасно получаем сущность из метаданных
			if collider.has_meta("entity"):
				var possible_target = collider.get_meta("entity")
				if possible_target is Entity and possible_target != entity:
					new_target = possible_target

		# Получаем старую цель
		var old_target = current_targets.get(entity, null)

		# Если цель изменилась
		if new_target != old_target:
			# Удаляем старое отношение
			if old_target:
				cmd.remove_relationship(old_target, Relationship.new(C_Target.new(), entity))

			# Добавляем новое отношение
			if new_target:
				cmd.add_relationship(new_target, Relationship.new(C_Target.new(), entity))

			# Обновляем словарь
			current_targets[entity] = new_target
