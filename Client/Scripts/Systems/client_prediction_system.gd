class_name ClientPredictionSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_IsLocalPlayer, C_PredictedState, C_InputHistory, C_LastServerState, C_Position])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for e in entities:
		var last: C_LastServerState = e.get_component(C_LastServerState)
		if not last.dirty:
			continue
		last.dirty = false
		if last.last_acked_seq <= last.last_reconciled_seq:
			continue
		_reconcile(e, last)

func _reconcile(entity: Entity, last: C_LastServerState) -> void:
	var pred: C_PredictedState = entity.get_component(C_PredictedState)
	var hist: C_InputHistory = entity.get_component(C_InputHistory)
	var pos: C_Position = entity.get_component(C_Position)

	var s: Dictionary = {
		"pos": last.pos,
		"rot": last.rot,
		"vel": last.vel,
		"throttle": pred.throttle,
	}
	for inp in hist.entries:
		if inp.seq <= last.last_acked_seq:
			continue
		s = MovementModel.step(s, {
			"throttle": inp.throttle,
			"turn": inp.turn,
			"brake": inp.brake,
			"dt": inp.dt,
		})
	pred.pos = s.pos
	pred.rot = s.rot
	pred.vel = s.vel
	pred.throttle = s.throttle

	pos.value = pred.pos
	var dir: C_Direction = entity.get_component(C_Direction)
	if dir:
		dir.value = rad_to_deg(pred.rot)

	var before: int = hist.entries.size()
	var nh: Array = []
	for inp in hist.entries:
		if inp.seq > last.last_acked_seq:
			nh.append(inp)
	hist.entries = nh
	last.last_reconciled_seq = last.last_acked_seq
	NetLog.d("reconcile", "acked=%d pending=%d (was %d)" % [last.last_acked_seq, nh.size(), before])
