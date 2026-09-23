class_name ClientRenderSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_ClientRoot])

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	var game = ClientSession.game_node
	if game == null:
		return

	var proj_mm: MultiMesh  = game.get_node("ProjectileMultiMesh").multimesh
	var remote_mm: MultiMesh = game.get_node("ShipDebug").multimesh

	var proj_idx := 0
	var remote_idx := 0

	game.reset_block_render_counters()

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

		if mk.is_projectile:
			if proj_idx < proj_mm.instance_count:
				var rot_rad := deg_to_rad(d.value)
				proj_mm.set_instance_transform_2d(proj_idx, Transform2D(rot_rad, p.value))
				proj_idx += 1
		elif e.has_component(C_IsLocalPlayer):
			_render_local_ship_blocks(e, p, d, game)
		else:
			if mk.blocks_layout.is_empty():
				if remote_idx < remote_mm.instance_count:
					var rot_rad := deg_to_rad(d.value)
					remote_mm.set_instance_transform_2d(remote_idx, Transform2D(rot_rad, p.value))
					remote_idx += 1
			else:
				_render_remote_ship_blocks(e, p, d, game)

	proj_mm.visible_instance_count = proj_idx
	remote_mm.visible_instance_count = remote_idx


## Свой корабль: white → yellow → red. Без зелёного.
func _local_damage_color(pct: float) -> Color:
	pct = clampf(pct, 0.0, 1.0)
	if pct >= 0.5:
		var t := (1.0 - pct) * 2.0
		return Color(1, 1, 1).lerp(Color(1, 1, 0), t)
	else:
		var t := (0.5 - pct) * 2.0
		return Color(1, 1, 0).lerp(Color(1, 0, 0), t)


## Чужой корабль: green → yellow → red. При hp=0 блок не рисуется (см. alive_mask).
func _remote_damage_color(pct: float) -> Color:
	pct = clampf(pct, 0.0, 1.0)
	if pct >= 0.5:
		var t := (1.0 - pct) * 2.0
		return Color(0, 1, 0).lerp(Color(1, 1, 0), t)
	else:
		var t := (0.5 - pct) * 2.0
		return Color(1, 1, 0).lerp(Color(1, 0, 0), t)


func _render_local_ship_blocks(entity, p: C_Position, d: C_Direction, game) -> void:
	var blocks: Array = entity.get_meta("blocks", [])
	if blocks.is_empty():
		return

	var ship_pos: Vector2 = p.value
	var ship_rot: float = deg_to_rad(d.value)
	var cell: float = float(ServerConfig.CELL_SIZE)

	for b in blocks:
		var hp: int = b["hp"]
		if hp <= 0:
			continue
		var hp_max: int = b.get("hp_max", hp)
		var block_id: int = b["id"]
		var bp: Vector2 = b["pos"]
		var local_px: Vector2 = bp * cell
		var world_pos: Vector2 = ship_pos + local_px.rotated(ship_rot)

		var mmi: MultiMeshInstance2D = game.get_block_mm(block_id)
		if mmi == null:
			continue
		var mm: MultiMesh = mmi.multimesh
		var idx: int = mm.visible_instance_count
		if idx >= mm.instance_count:
			continue
		var pct := float(hp) / float(hp_max) if hp_max > 0 else 1.0
		mm.set_instance_transform_2d(idx, Transform2D(ship_rot, world_pos))
		mm.set_instance_color(idx, _local_damage_color(pct))
		mm.visible_instance_count = idx + 1


func _render_remote_ship_blocks(entity, p: C_Position, d: C_Direction, game) -> void:
	var mk: C_MirrorKind = entity.get_component(C_MirrorKind)
	if mk == null or mk.blocks_layout.is_empty():
		return
	var mmi: MultiMeshInstance2D = game.get_remote_blocks_mm()
	if mmi == null:
		return
	var mm: MultiMesh = mmi.multimesh

	var ship_pos: Vector2 = p.value
	var ship_rot: float = deg_to_rad(d.value)
	var cell: float = float(ServerConfig.CELL_SIZE)

	var layout: Array = mk.blocks_layout
	var mask: PackedByteArray = mk.alive_mask
	var hps: Array = mk.blocks_hp
	var hpmaxes: Array = mk.blocks_hp_max
	var has_per_block := not hps.is_empty() and not hpmaxes.is_empty()

	for i in layout.size():
		var alive_mask_ok := true
		if i >> 3 < mask.size():
			alive_mask_ok = (int(mask[i >> 3]) & (1 << (i & 7))) != 0

		var color := Color(0, 1, 0)
		var hp_alive := true
		if has_per_block and i < hps.size() and i < hpmaxes.size():
			var h: int = hps[i]
			var hm: int = hpmaxes[i]
			if h <= 0:
				hp_alive = false
			else:
				color = _remote_damage_color(float(h) / float(hm) if hm > 0 else 1.0)

		# Блок не рисуется, если он мёртв по mask ИЛИ по per-block hp.
		if not alive_mask_ok or not hp_alive:
			continue

		var bp: Vector2i = layout[i]
		var local_px: Vector2 = Vector2(bp) * (cell * 0.5)
		var world_pos: Vector2 = ship_pos + local_px.rotated(ship_rot)
		var idx: int = mm.visible_instance_count
		if idx >= mm.instance_count:
			break
		mm.set_instance_transform_2d(idx, Transform2D(ship_rot, world_pos))
		mm.set_instance_color(idx, color)
		mm.visible_instance_count = idx + 1
