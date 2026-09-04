extends System
class_name ControlSystem

func query() -> QueryBuilder:
	return q.with_all([C_PeerID])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	const THROTTLE_INCREASE_SPEED := 0.01   # скорость роста тяги при положительном throttle
	const THROTTLE_DECREASE_SPEED := 0.01   # скорость падения тяги при отрицательном throttle
	const MAX_THROTTLE := 100               # максимальная сила
	const TURN_SPEED := 2.5                 # угловая скорость поворота (рад/сек)

	for entity in entities:
		var force: C_Force = entity.get_component(C_Force)
		var angular_velocity: C_AngularVelocity = entity.get_component(C_AngularVelocity)
		var body: C_RigidBody = entity.get_component(C_RigidBody)
		var input: C_ControlInput = entity.get_component(C_ControlInput)

		# --- Тяга ---
		var throttle = input.throttle
		if throttle > 0:
			force.value += delta / THROTTLE_INCREASE_SPEED * throttle
		elif throttle < 0:
			force.value += delta / THROTTLE_DECREASE_SPEED * throttle

		force.value = clamp(force.value, -MAX_THROTTLE, MAX_THROTTLE)

		# --- Поворот ---
		angular_velocity.value = input.turn * TURN_SPEED

		# --- Сброс инерции (торможение) ---
		if input.brake:
			body.node[0].linear_damp = 1.0
			force.value = 0
		else:
			body.node[0].linear_damp = 0.0
		
		if input.fire:
			pass
