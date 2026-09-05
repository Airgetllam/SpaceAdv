extends Observer
class_name RigidbodyInitObserver

func query() -> QueryBuilder:
	return q.with_all([C_RigidBody]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var pos: C_Position = entity.get_component(C_Position)
	var body: C_RigidBody = entity.get_component(C_RigidBody)
	var entity_name: C_EntityName = entity.get_component(C_EntityName)
	var entity_type: C_EntityType = entity.get_component(C_EntityType)
	var parent: Node
	var rig = RigidBody2D.new()
	if entity_type.value == 'user':
		parent = get_tree().current_scene.get_node('World/Ships')
	elif entity_type.value == 'projectile':
		parent = get_tree().current_scene.get_node('World/Projectile')
	rig.name = entity_name.value
	rig.position = pos.value
	rig.gravity_scale = 0
	rig.can_sleep = false
	rig.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rig.linear_damp = 0
	rig.set_meta('entity', entity)
	entity.set_meta('rigidbody', rig)
	body.node.append(rig)
	parent.add_child(rig)
