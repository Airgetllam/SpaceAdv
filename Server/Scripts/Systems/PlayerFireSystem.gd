extends System
class_name PlayerFireSystem
## Режимы (по ТЗ):
##   fire_mode == 1 — по очереди, один ствол за тик, КД между выстрелами.
##   fire_mode == 2 — одновременный залп, КД между залпами.
## ammo.value_ammo_count уменьшается на КАЖДЫЙ выпущенный снаряд.
## ammo.value_cd применяется одинаково в обоих режимах.

func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_ControlInput, C_Position, C_Direction,
		C_AttackSocket, C_Ammo])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var cd: float = entity.get_meta("fire_cd", 0.0)
		if cd > 0.0:
			entity.set_meta("fire_cd", max(0.0, cd - delta))

		var input: C_ControlInput = entity.get_component(C_ControlInput)
		if input == null or not input.fire:
			continue
		if entity.get_meta("fire_cd", 0.0) > 0.0:
			continue

		var ammo: C_Ammo = entity.get_component(C_Ammo)
		if ammo == null or ammo.value_ammo_count <= 0:
			continue

		var sockets: C_AttackSocket = entity.get_component(C_AttackSocket)
		if sockets == null or sockets.value.is_empty():
			continue

		match input.fire_mode:
			1:
				_fire_sequential(entity, sockets, ammo)
			2:
				_fire_salvo(entity, sockets, ammo)
			_:
				pass


func _fire_sequential(entity: Entity, sockets: C_AttackSocket, ammo: C_Ammo) -> void:
	var count: int = sockets.value.size()
	var idx: int = entity.get_meta("fire_index", 0) % count
	_spawn_one(entity, sockets.value[idx])
	entity.set_meta("fire_index", (idx + 1) % count)
	ammo.value_ammo_count -= 1
	entity.set_meta("fire_cd", ammo.value_cd)


func _fire_salvo(entity: Entity, sockets: C_AttackSocket, ammo: C_Ammo) -> void:
	# Сколько стволов реально можем выстрелить (ограничено патронами)
	var count: int = min(sockets.value.size(), ammo.value_ammo_count)
	for i in range(count):
		_spawn_one(entity, sockets.value[i])
	ammo.value_ammo_count -= count
	# КД — между залпами, не зависит от числа стволов
	entity.set_meta("fire_cd", ammo.value_cd)


func _spawn_one(shooter: Entity, sock_local: Vector2) -> void:
	var pos_c: C_Position = shooter.get_component(C_Position)
	var dir_c: C_Direction = shooter.get_component(C_Direction)
	if pos_c == null or dir_c == null:
		return

	var cell: float = ServerConfig.CELL_SIZE
	var ship_rot_rad: float = deg_to_rad(dir_c.value)
	var local_px: Vector2 = sock_local * cell
	var world_pos: Vector2 = pos_c.value + local_px.rotated(ship_rot_rad)
	var ship_deg: float = dir_c.value

	var target_entity: Entity = null
	var tgt: C_Target = shooter.get_component(C_Target)
	if tgt != null and not tgt.value.is_empty():
		target_entity = tgt.value[0]

	var pname := "proj_%d" % randi()
	var proj := Entity.new()
	proj.name = pname
	cmd.add_components(proj, [
		C_Debug.new(),
		C_ExistenceState.new(),
		C_EntityName.new(pname),
		C_EntityType.new("projectile"),
		C_SpawnPoint.new(world_pos, ship_deg),
		C_Velocity.new(),
		C_Damage.new(100, 1.5),
		C_Target.new(target_entity),
		C_HomingParams.new(1000, 4),
		C_LifeTimer.new(5.0),
		C_Owner.new([shooter]),
	])
	ECS.world.add_entity(proj)

	var shooter_net := 0
	if shooter.has_component(C_NetId):
		shooter_net = shooter.get_component(C_NetId).value
	NetLog.d("server", "FIRE spawn proj=%s shooter_net=%d pos=(%.1f,%.1f)" % [
		pname, shooter_net, world_pos.x, world_pos.y
	])
