extends System
class_name PlayerFireSystem
## PRIMARY_FIRE — последовательная стрельба.
## SECONDARY_FIRE — одновременный залп.
##
## Состояние кнопок читается напрямую из generic PlayerInputFrame.
## Network/movement layer ничего о механике стрельбы не знает.

func query() -> QueryBuilder:
	return q.with_all([C_PeerID, C_ControlInput, C_Position, C_Direction, C_AttackSocket, C_Ammo])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var cd: float = entity.get_meta("fire_cd", 0.0)
		if cd > 0.0:
			entity.set_meta("fire_cd", max(0.0, cd - delta))

		var input_state: C_PlayerInputState = (
			entity.get_component(C_PlayerInputState)
		)

		if input_state == null:
			continue

		var frame: PlayerInputFrame = (
			input_state.current_frame
		)

		var primary_fire := frame.is_action_pressed(
			InputActions.PRIMARY_FIRE
		)

		var secondary_fire := frame.is_action_pressed(
			InputActions.SECONDARY_FIRE
		)

		if not primary_fire and not secondary_fire:
			continue

		if entity.get_meta("fire_cd", 0.0) > 0.0:
			continue

		var ammo: C_Ammo = entity.get_component(C_Ammo)
		if ammo == null or ammo.value_ammo_count <= 0:
			continue

		var sockets: C_AttackSocket = entity.get_component(C_AttackSocket)
		if sockets == null or sockets.value.is_empty():
			continue

		# SECONDARY_FIRE имеет приоритет,
		# если каким-то образом зажаты обе кнопки.
		if secondary_fire:
			_fire_salvo(
				entity,
				sockets,
				ammo
			)
		else:
			_fire_sequential(
				entity,
				sockets,
				ammo
			)


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

	var targets: C_Targets = shooter.get_component(
		C_Targets
	)

	if targets != null:
		for target_dict in targets.list:
			var state: int = target_dict.get(
				"state",
				0
			)

			if state != 1:
				continue

			var target = target_dict.get(
				"entity",
				null
			)

			if (
				target is Entity
				and is_instance_valid(target)
			):
				target_entity = target
				break

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
