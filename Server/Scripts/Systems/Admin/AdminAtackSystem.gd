extends System
class_name AdminAtackSystem

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		var targets: C_Targets = entity.get_component(C_Targets)
		var _name = 'msl_%s' % [randi()]
		if Input.is_action_just_pressed("pkm"):
			var _entity = Entity.new()
			var _target: Entity
			if targets.list.is_empty():
				_target = null
			else:
				_target = targets.list[0].entity
			_entity.name = _name
			var comps = [
				C_Debug.new(),
				C_ExistenceState.new(),
				C_EntityName.new(_name),
				C_EntityType.new('projectile'),
				C_SpawnPoint.new(cursor.position),
				C_LifeTimer.new(5),
				C_Velocity.new(),
				C_Damage.new(100, 1.5),                       #TODO: heh
				C_Target.new(_target),
				C_HomingParams.new(3000, 5)
			]
			cmd.add_components(_entity, comps)
			ECS.world.add_entity(_entity)
