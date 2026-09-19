extends Observer
class_name AmmoControlInitObserver

const DIRS = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1)
]

func query() -> QueryBuilder:
	return q.with_all([C_Ammo]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var blocks_data: C_Blocks = entity.get_component(C_Blocks)
	if not blocks_data:
		return

	var map: Dictionary = blocks_data.blocks_map
	var socks: Array[Vector2] = []

	for key in map.keys():
		if map[key].block_id != 5:
			continue

		var base = Vector2(key)
		var best_length := 0
		var best_endpoint := Vector2.INF
		var best_dir := Vector2.ZERO

		for dir in DIRS:
			var current = base
			var length := 0
			var endpoint = base

			while true:
				var next = current + dir
				if not map.has(next):
					break
				if map[next].block_id != 1:
					break
				current = next
				endpoint = next
				length += 1

			if length > 1 and length > best_length:
				best_length = length
				best_endpoint = endpoint
				best_dir = dir

		if best_length > 1:
			var spawn_point = best_endpoint + best_dir + Vector2(0.5, 0.5)
			if not socks.has(spawn_point):
				socks.append(spawn_point)

	cmd.add_component(entity, C_AtackSocket.new(socks))
