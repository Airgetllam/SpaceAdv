extends GdUnitTestSuite
## CHANGE DETECTION (v9): QueryBuilder.changed() + per-column write versions.
## Systems using .changed() must process rows written since their last run —
## and skip untouched archetypes entirely.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


class ChangedSystem:
	extends System
	var processed: Array = []

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest]).changed([C_ObserverTest])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		processed.append_array(entities)


func _spawn(count: int) -> Array:
	var out: Array = []
	for i in count:
		var e = Entity.new()
		e.name = "CD_%d" % i
		e.add_component(C_ObserverTest.new(i))
		world.add_entity(e, null, false)
		out.append(e)
	return out


func test_first_run_sees_everything_then_settles():
	var entities = _spawn(3)
	var system = ChangedSystem.new()
	world.add_system(system)

	# First run: new rows count as changed — all 3 processed
	world.process(0.016)
	assert_int(system.processed.size()).is_equal(3)

	# No writes since — second run processes nothing
	system.processed.clear()
	world.process(0.016)
	assert_int(system.processed.size()).is_equal(0)

	# Emitting-setter write on ONE entity — only it is processed
	var comp = entities[1].get_component(C_ObserverTest)
	comp.value = 999
	world.process(0.016)
	assert_int(system.processed.size()).is_equal(1)
	assert_object(system.processed[0]).is_same(entities[1])

	# And it settles again
	system.processed.clear()
	world.process(0.016)
	assert_int(system.processed.size()).is_equal(0)


func test_mark_changed_covers_direct_writes():
	var entities = _spawn(2)
	var system = ChangedSystem.new()
	world.add_system(system)
	world.process(0.016)  # drain the initial "all new" pass
	system.processed.clear()

	# Direct write (bypasses the setter) + explicit mark_changed
	var comp = entities[0].get_component(C_ObserverTest)
	comp.name_prop = "x"  # emitting setter would also work; simulate direct:
	entities[0].mark_changed(comp)

	world.process(0.016)
	assert_bool(system.processed.has(entities[0])).is_true()


func test_new_entity_is_seen_by_changed_query():
	var system = ChangedSystem.new()
	world.add_system(system)
	world.process(0.016)
	system.processed.clear()

	var newcomers = _spawn(1)
	world.process(0.016)
	assert_int(system.processed.size()).is_equal(1)
	assert_object(system.processed[0]).is_same(newcomers[0])


func test_plain_queries_unaffected():
	# A system WITHOUT .changed() still processes every frame
	var entities = _spawn(2)
	var system = ChangedSystem.new()
	world.add_system(system)

	var plain = PlainSystem.new()
	world.add_system(plain)

	world.process(0.016)
	world.process(0.016)
	# plain ran twice over 2 entities = 4; changed system only saw first pass
	assert_int(plain.count).is_equal(4)
	assert_int(system.processed.size()).is_equal(2)


class PlainSystem:
	extends System
	var count: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		count += entities.size()
