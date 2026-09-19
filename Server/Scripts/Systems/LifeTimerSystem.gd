extends System
class_name LifeTimerSystem

func query() -> QueryBuilder:
	return q.with_all([C_LifeTimer, C_ExistenceState])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var timer: C_LifeTimer = entity.get_component(C_LifeTimer)
		var exist: C_ExistenceState = entity.get_component(C_ExistenceState)
		if not timer or not exist:
			continue

		if exist.value == 0:
			continue

		timer.value -= delta
		if timer.value <= 0.0:
			timer.value = 0.0
			exist.value = 0
