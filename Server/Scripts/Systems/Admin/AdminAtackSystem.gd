extends System
class_name AdminAtackSystem

func query() -> QueryBuilder:
	return q.with_all([C_ServerIP])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var cursor: C_CursorPosition = entity.get_component(C_CursorPosition)
		var targets: C_Targets = entity.get_component(C_Targets)
		var _name = 'msl_%s' % [randi()]
		var polygon = [Vector2(8, 40)]
		if Input.is_action_just_pressed("pkm"):
			var _entity = Entity.new()
			var _target: Entity
			if targets.list.is_empty():
				_target = null
			else:
				_target = targets.list[0].entity
			_entity.name = _name
			var comps = [
				C_ExistenceState.new(),
				C_EntityName.new(_name),
				C_EntityType.new('projectile'),
				C_SpawnPoint.new(cursor.position),
				C_RigidBody.new(),
				C_Collider.new(polygon),
				C_Force.new(),
				C_AngularVelocity.new(),
				C_Target.new(_target)
			]
			cmd.add_components(_entity, comps)
			ECS.world.add_entity(_entity)
			#if !targets.list.is_empty() and targets.list[0].state == 1:
				
