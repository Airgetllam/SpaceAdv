class_name MovementModel

const FIXED_DT: float = 1.0 / 30.0

const MAX_THROTTLE_ACCEL: float = 600.0   # px/s^2 при |throttle| = 1.0
const TURN_SPEED: float = 2.5              # rad/s при |turn| = 1.0
const THROTTLE_RATE: float = 3.0           # 1/s — сколько throttle набирается за секунду
const MAX_SPEED: float = 1500.0            # px/s
const BRAKE_DAMP: float = 4.0              # 1/s

## state: { pos: Vector2, rot: float (rad), vel: Vector2, throttle: float }
## input: { throttle: float (-1..1), turn: float (-1..1), brake: bool, dt: float }
static func step(s: Dictionary, input: Dictionary) -> Dictionary:
	var dt: float = input.get("dt", FIXED_DT)

	var t: float = s.get("throttle", 0.0)
	var target: float = clampf(input.get("throttle", 0.0), -1.0, 1.0)
	if t < target:
		t = minf(t + THROTTLE_RATE * dt, target)
	elif t > target:
		t = maxf(t - THROTTLE_RATE * dt, target)

	var turn: float = clampf(input.get("turn", 0.0), -1.0, 1.0)
	var rot: float = s.get("rot", 0.0) + turn * TURN_SPEED * dt

	var dir: Vector2 = Vector2.UP.rotated(rot)
	var vel: Vector2 = s.get("vel", Vector2.ZERO) + dir * (t * MAX_THROTTLE_ACCEL) * dt

	if input.get("brake", false):
		vel *= exp(-BRAKE_DAMP * dt)

	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED

	var pos: Vector2 = s.get("pos", Vector2.ZERO) + vel * dt

	return {
		"pos": pos,
		"rot": rot,
		"vel": vel,
		"throttle": t,
	}
