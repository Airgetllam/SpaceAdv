extends Observer
class_name RigidbodyInitObserver

func query() -> QueryBuilder:
	return q.with_all([C_RigidBody]).on_added()

func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var spawn_pos: C_SpawnPoint = entity.get_component(C_SpawnPoint)
	var body: C_RigidBody = entity.get_component(C_RigidBody)
	var rig = RigidBody2D.new()
	rig.name = 'ship1' # TODO: Добавить компонент C_Nickname и брать оттуда
	rig.position = spawn_pos.value
	rig.gravity_scale = 0
	rig.can_sleep = false
	rig.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rig.linear_damp = 0
	rig.set_meta('entity', entity)
	entity.set_meta('rigidbody', rig)
	body.node.append(rig)
