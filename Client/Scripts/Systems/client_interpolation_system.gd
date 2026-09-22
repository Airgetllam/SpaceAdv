class_name ClientInterpolationSystem
extends System

const INTERP_DURATION := 0.1

func query() -> QueryBuilder:
	return q.with_all([C_InterpTarget, C_Position, C_Direction])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var step: float = delta / INTERP_DURATION
	for e in entities:
		var it: C_InterpTarget = e.get_component(C_InterpTarget)
		if not it.has_target:
			continue
		it.t = min(it.t + step, 1.0)
		var pos: Vector2 = it.prev_pos.lerp(it.curr_pos, it.t)
		var rot: float = lerp_angle(it.prev_rot, it.curr_rot, it.t)
		var p: C_Position = e.get_component(C_Position)
		var d: C_Direction = e.get_component(C_Direction)
		if p: p.value = pos
		if d: d.value = rad_to_deg(rot)
