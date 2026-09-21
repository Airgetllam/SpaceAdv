class_name TransformSyncSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Position, C_Direction, C_RigidBody])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for e in entities:
		var pos: C_Position  = e.get_component(C_Position)
		var dir: C_Direction = e.get_component(C_Direction)
		var rb: C_RigidBody  = e.get_component(C_RigidBody)
		if not (rb.node is Array) or rb.node.is_empty():
			continue
		var body: RigidBody2D = rb.node[0]
		if not is_instance_valid(body):
			continue
		body.global_position = pos.value
		body.rotation = deg_to_rad(dir.value)
