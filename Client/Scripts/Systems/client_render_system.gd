class_name ClientRenderSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_ClientRoot])

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	var game = ClientSession.game_node
	if game == null:
		return
	var proj_mm: MultiMesh = game.get_node("ProjectileMultiMesh").multimesh
	var ship_mm: MultiMesh = game.get_node("ShipDebug").multimesh

	var proj_idx := 0
	var ship_idx := 0

	for nid in ClientSession.net_id_to_entity.keys():
		var e = ClientSession.net_id_to_entity[nid]
		if e == null or not is_instance_valid(e):
			continue
		var mk: C_MirrorKind = e.get_component(C_MirrorKind)
		if mk == null:
			continue
		var p: C_Position = e.get_component(C_Position)
		var d: C_Direction = e.get_component(C_Direction)
		if p == null or d == null:
			continue
		var rot_rad := deg_to_rad(d.value)
		if mk.is_projectile:
			if proj_idx < proj_mm.instance_count:
				proj_mm.set_instance_transform_2d(proj_idx, Transform2D(rot_rad, p.value))
				proj_idx += 1
		else:
			if ship_idx < ship_mm.instance_count:
				ship_mm.set_instance_transform_2d(ship_idx, Transform2D(rot_rad, p.value))
				ship_idx += 1

	proj_mm.visible_instance_count = proj_idx
	ship_mm.visible_instance_count = ship_idx
