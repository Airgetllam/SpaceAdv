class_name AbilityModel

const BOOST_IMPULSE: float = 500.0

static func apply_boost(velocity: Vector2, rot: float) -> Vector2:
	var forward := Vector2.UP.rotated(rot)
	return velocity + forward * BOOST_IMPULSE
