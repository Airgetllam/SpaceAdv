extends GdUnitTestSuite

# Test suite for GECSTracker: dependency tracking of component reads and query executions.

var world: World


func before_test():
	world = World.new()
	world.name = "TestWorld"
	Engine.get_main_loop().root.add_child(world)
	ECS.world = world


func after_test():
	# Always clear instrumentation, so a failing test can't leak the static hooks
	# into the rest of the suite.
	QueryBuilder.set_execute_tracker(Callable())
	Entity.set_read_tracker(Callable())
	ECS.world = null
	if is_instance_valid(world):
		world.queue_free()


func _spawn(components: Array) -> Entity:
	var entity = Entity.new()
	for component in components:
		entity.add_component(component)
	world.add_entity(entity)
	return entity


func test_track_returns_callable_result():
	var deps = GECSTracker.track(func(): return 42)
	assert_int(deps.result).is_equal(42)


func test_track_reports_component_reads():
	var entity = _spawn([C_TestA.new(), C_TestB.new()])

	var deps = GECSTracker.track(
		func():
			entity.get_component(C_TestA)
			entity.has_component(C_TestB)
			return null
	)

	assert_array(deps.reads).contains([C_TestA, C_TestB])
	assert_array(deps.reads).has_size(2)


func test_reads_deduplicate_by_component_type():
	var entity = _spawn([C_TestA.new()])

	var deps = GECSTracker.track(
		func():
			for i in range(5):
				entity.get_component(C_TestA)
				entity.has_component(C_TestA)
			return null
	)

	# Ten reads of one type collapse to a single dependency.
	assert_array(deps.reads).has_size(1)
	assert_array(deps.reads).contains([C_TestA])


func test_reads_normalize_component_instances_to_scripts():
	var entity = _spawn([C_TestA.new()])
	var probe := C_TestA.new()

	# get_component accepts a Script OR an instance; both must report the Script
	# so a type read is one dependency however it was spelled.
	var deps = GECSTracker.track(
		func():
			entity.get_component(probe)
			entity.get_component(C_TestA)
			return null
	)

	assert_array(deps.reads).has_size(1)
	assert_array(deps.reads).contains([C_TestA])


func test_track_reports_executed_queries():
	_spawn([C_TestA.new()])

	var deps = GECSTracker.track(
		func():
			world.query.with_all([C_TestA]).execute()
			world.query.with_all([C_TestB]).execute()
			return null
	)

	# world.query hands back a fresh builder per access, so these are two instances.
	assert_array(deps.queries).has_size(2)


func test_queries_deduplicate_by_builder_instance():
	_spawn([C_TestA.new()])

	var deps = GECSTracker.track(
		func():
			var builder = world.query.with_all([C_TestA])
			builder.execute()
			builder.execute()
			builder.execute()
			return null
	)

	assert_array(deps.queries).has_size(1)


func test_track_captures_reads_inside_nested_helpers():
	var entity = _spawn([C_TestA.new(), C_TestB.new()])

	# The point of the instrumentation: dependencies are found no matter how deep
	# in helper code the access happens, not just at the top level of the callable.
	var inner := func(): return entity.get_component(C_TestB)
	var outer := func():
		entity.get_component(C_TestA)
		return inner.call()

	var deps = GECSTracker.track(outer)

	assert_array(deps.reads).contains([C_TestA, C_TestB])
	assert_that(deps.result).is_not_null()


func test_instrumentation_is_disabled_outside_track():
	var entity = _spawn([C_TestA.new()])

	# Reads and queries performed outside a tracked call must not be attributed
	# to the next tracked call.
	entity.get_component(C_TestA)
	world.query.with_all([C_TestA]).execute()

	var deps = GECSTracker.track(func(): return null)

	assert_array(deps.reads).is_empty()
	assert_array(deps.queries).is_empty()


func test_consecutive_tracks_do_not_accumulate():
	var entity = _spawn([C_TestA.new(), C_TestB.new()])

	var first = GECSTracker.track(func(): return entity.get_component(C_TestA))
	var second = GECSTracker.track(func(): return entity.get_component(C_TestB))

	assert_array(first.reads).contains([C_TestA])
	# The second call reports only its own reads, not the first call's.
	assert_array(second.reads).has_size(1)
	assert_array(second.reads).contains([C_TestB])


func test_query_sensitivity_reports_component_dependencies():
	var builder = world.query.with_all([C_TestA]).with_any([C_TestB]).with_none([C_TestD])

	var sensitivity := builder.sensitivity()

	# Sensitivity is the set of component script paths whose mutation could change
	# this query's membership, used to build a dependency signature.
	assert_array(sensitivity).contains([
		C_TestA.resource_path, C_TestB.resource_path, C_TestD.resource_path
	])


func test_has_relationship_filters_reports_relationship_use():
	var plain = world.query.with_all([C_TestA])
	assert_bool(plain.has_relationship_filters()).is_false()

	var with_rel = world.query.with_relationship([Relationship.new(C_TestC.new(), ECS.wildcard)])
	assert_bool(with_rel.has_relationship_filters()).is_true()

	var without_rel = (
		world.query.without_relationship([Relationship.new(C_TestC.new(), ECS.wildcard)])
	)
	assert_bool(without_rel.has_relationship_filters()).is_true()
