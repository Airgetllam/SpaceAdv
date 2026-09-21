extends Observer
class_name RigidbodyInitObserver

func query() -> QueryBuilder:
	return q.with_all([C_RigidBody]).on_added()

func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var pos: C_Position = entity.get_component(C_Position)
	var dir: C_Direction = entity.get_component(C_Direction)
	var body: C_RigidBody = entity.get_component(C_RigidBody)
	var entity_name: C_EntityName = entity.get_component(C_EntityName)
	var entity_type: C_EntityType = entity.get_component(C_EntityType)
	var script = preload('res://Server/Scripts/NoECSScripts/rigidbody_contact.gd')
	var parent: Node
	var rig = RigidBody2D.new()
	if entity_type.value == 'user':
		parent = get_tree().current_scene.get_node('World/Ships')
	elif entity_type.value == 'projectile':
		parent = get_tree().current_scene.get_node('World/Projectile')
	rig.name = entity_name.value
	rig.position = pos.value
	rig.rotation_degrees = dir.value
	rig.gravity_scale = 0
	rig.can_sleep = false
	rig.freeze = true
	rig.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rig.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rig.linear_damp = 0
	rig.contact_monitor = true
	rig.max_contacts_reported = 10
	rig.set_script(script)
	rig.set_meta('entity', entity)
	entity.set_meta('rigidbody', rig)
	body.node.append(rig)
	parent.add_child(rig)
