extends System
class_name VelocityApplySystem

func query() -> QueryBuilder:
	return q.with_all([C_Position, C_Velocity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var pos: C_Position = entity.get_component(C_Position)
		var vel: C_Velocity = entity.get_component(C_Velocity)
		if not pos or not vel:
			continue
		pos.value += vel.value * delta
