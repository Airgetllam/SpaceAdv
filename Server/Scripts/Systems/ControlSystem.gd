extends System
class_name ControlSystem

func query() -> QueryBuilder:
	return q.with_all([C_PeerID])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	const THROTTLE_INCREASE_SPEED := 0.01
	const THROTTLE_DECREASE_SPEED := 0.01
	const MAX_THROTTLE := 100
	const TURN_SPEED := 2.5

	for entity in entities:
		var force: C_Force = entity.get_component(C_Force)
		var angular_velocity: C_AngularVelocity = entity.get_component(C_AngularVelocity)
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		var input: C_ControlInput = entity.get_component(C_ControlInput)
		if not force or not angular_velocity or not body or not input:
			continue

		# --- Тяга ---
		var throttle = input.throttle
		if throttle > 0:
			force.value += delta / THROTTLE_INCREASE_SPEED * throttle
		elif throttle < 0:
			force.value += delta / THROTTLE_DECREASE_SPEED * throttle
		force.value = clamp(force.value, -MAX_THROTTLE, MAX_THROTTLE)

		# --- Поворот ---
		angular_velocity.value = input.turn * TURN_SPEED

		# --- Торможение ---
		if input.brake:
			body.node[0].linear_damp = 1.0
			force.value = 0
		else:
			body.node[0].linear_damp = 0.0

		# --- Кулдаун стрельбы ---
		var cd = entity.get_meta("fire_cd", 0.0)
		if cd > 0.0:
			entity.set_meta("fire_cd", max(0.0, cd - delta))

		# --- Стрельба ---
		if input.fire:
			_handle_fire(entity, input)

func _handle_fire(entity: Entity, input: C_ControlInput) -> void:
	var sockets_comp: C_AtackSocket = entity.get_component(C_AtackSocket)
	var rigid: C_RigidBody = entity.get_component(C_RigidBody)
	var ammo: C_Ammo = entity.get_component(C_Ammo)
	if not sockets_comp or not rigid or not rigid.node or not ammo:
		return

	var socks: Array = sockets_comp.value
	if socks.is_empty():
		return

	# Нет патронов — не стреляем
	if ammo.value_ammo_count <= 0:
		return

	# Кулдаун не прошёл — не стреляем
	if entity.get_meta("fire_cd", 0.0) > 0.0:
		return

	var body_node = rigid.node[0]
	var cell_size = ServerConfig.CELL_SIZE

	if input.fire_mode == 1:
		# Одновременно из всех сокетов, но не больше, чем есть патронов
		var shots = min(socks.size(), ammo.value_ammo_count)
		for i in range(shots):
			_spawn_projectile(entity, socks[i], body_node, cell_size)
		ammo.value_ammo_count -= shots
		entity.set_meta("fire_cd", ammo.value_cd)

	elif input.fire_mode == 2:
		# По очереди — один выстрел за раз
		var idx: int = entity.get_meta("fire_index", 0) % socks.size()
		_spawn_projectile(entity, socks[idx], body_node, cell_size)
		entity.set_meta("fire_index", idx + 1)
		ammo.value_ammo_count -= 1
		entity.set_meta("fire_cd", ammo.value_cd)

func _spawn_projectile(shooter: Entity, sock: Vector2, body_node: Node2D, cell_size: float) -> void:
	var local_pos = sock * cell_size
	var world_pos = body_node.to_global(local_pos)

	# Берём реальный угол тела в градусах
	var ship_deg = rad_to_deg(body_node.rotation)

	var target_comp: C_Target = shooter.get_component(C_Target)
	var target_entity: Entity = null
	if target_comp and not target_comp.value.is_empty():
		target_entity = target_comp.value[0]

	var _name = "proj_%d" % randi()
	var proj = Entity.new()
	proj.name = _name

	cmd.add_components(proj, [
		C_Debug.new(),
		C_ExistenceState.new(),
		C_EntityName.new(_name),
		C_EntityType.new('projectile'),
		C_SpawnPoint.new(world_pos, ship_deg),
		C_Velocity.new(),
		C_Damage.new(100, 1.5),
		C_Target.new(target_entity),
		C_HomingParams.new(1000, 4),
		C_LifeTimer.new(5.0),
	])
	ECS.world.add_entity(proj)
