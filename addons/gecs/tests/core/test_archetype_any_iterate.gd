extends GdUnitTestSuite
## Documents the shape of the `components` array when combining
## `with_any([X, Y, Z]).iterate([X, Y, Z])`.
##
## Question (from Discord): is it safe to do `.with_any([X,Y,Z]).iterate([X,Y,Z])`,
## and would the returned columns be null-padded parallel arrays like
## `[[X, X, null, X], [null, null, null, Y], ...]`?
##
## Answer demonstrated here: NO. `with_any` matches entities that live in
## DIFFERENT archetypes, and the structural fast path calls `process()` once per
## archetype. Within each call, iterate() builds one column per component type,
## but a component absent from that archetype comes back as an EMPTY array (`[]`),
## sitting next to full-width columns. Columns are never null-padded to line up.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func test_with_any_iterate_columns_are_per_archetype_not_null_padded():
	var sys = ArchetypeAnyIterateTestSystem.new()
	world.add_system(sys)

	# Three distinct component combinations -> three archetypes.
	var e1 = Entity.new()
	world.add_entity(e1, [C_TestA.new()])  # archetype [A]
	var e2 = Entity.new()
	world.add_entity(e2, [C_TestB.new()])  # archetype [B]
	var e3 = Entity.new()
	world.add_entity(e3, [C_TestA.new(), C_TestB.new()])  # archetype [A, B]

	world.process(0.1)

	# with_any spreads matches across archetypes; process() fires once per archetype.
	assert_int(sys.invocations.size()).is_equal(3)

	# In every call, a column is either empty (component absent from that
	# archetype) or exactly as long as the entity list (component present).
	# It is NEVER null-padded to align with the other columns.
	for inv in sys.invocations:
		var n: int = inv.entities
		for col_size in inv.col_sizes:
			assert_bool(col_size == 0 or col_size == n).override_failure_message(
				"column size %d should be 0 or %d (entity count)" % [col_size, n]
			).is_true()

	# No column ever contains null padding — absent components yield [] instead.
	for inv in sys.invocations:
		assert_bool(inv.any_null).override_failure_message(
			"iterate() columns should contain no null padding"
		).is_false()

	# Headline: prove the size mismatch. At least one call has a zero-width
	# column next to a full-width one (the [A] and [B] single-component archetypes).
	var saw_mismatch := false
	for inv in sys.invocations:
		if inv.entities > 0 and inv.col_sizes.has(0) and inv.col_sizes.has(inv.entities):
			saw_mismatch = true
	assert_bool(saw_mismatch).override_failure_message(
		"expected at least one process() call with mismatched (empty vs full) columns"
	).is_true()


func test_with_all_iterate_columns_are_aligned():
	# Contrast case: with_all() keeps every iterated component in the same
	# archetype, so all columns are the same width and safe to zip positionally.
	var sys = ArchetypeMultipleArchetypesTestSystem.new()
	world.add_system(sys)

	var e1 = Entity.new()
	world.add_entity(e1, [C_TestA.new(), C_TestB.new()])
	var e2 = Entity.new()
	world.add_entity(e2, [C_TestA.new(), C_TestB.new()])

	world.process(0.1)

	# Single archetype [A, B] -> one call, both columns present.
	assert_int(sys.archetype_call_count).is_equal(1)
	assert_int(sys.total_entities_processed).is_equal(2)
