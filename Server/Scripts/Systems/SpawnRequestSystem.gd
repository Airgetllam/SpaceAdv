extends System
class_name SpawnRequestSystem

func query() -> QueryBuilder:
	return q.with_all([C_SpawnRequest])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var pos: C_SpawnRequest = entity.get_component(C_SpawnRequest)
		var player = Entity.new()
		player.add_component(C_Position.new(pos.position))
		player.add_component(C_Force.new())
		player.add_component(C_Direction.new())
		player.add_component(C_UserIP.new())
		ECS.world.add_entity(player)
		cmd.remove_component(entity, C_SpawnRequest)
		print("[SpawnSystem] Игрок создан")
