## Entity Performance Tests
## Tests entity creation, addition, removal, and operations
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


## Test entity creation performance at different scales
func test_entity_creation(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	var time_ms = PerfHelpers.time_it(
		func():
			for i in scale:
				var entity = auto_free(Entity.new())
				entity.name = "PerfEntity_%d" % i
				entities.append(entity)
	)

	PerfHelpers.record_result("entity_creation", scale, time_ms)


## Test entity creation with multiple components
func test_entity_with_components(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	var time_ms = PerfHelpers.time_it(
		func():
			for i in scale:
				var entity = auto_free(Entity.new())
				entity.name = "PerfEntity_%d" % i
				entity.add_component(C_TestA.new())
				entity.add_component(C_TestB.new())
				if i % 2 == 0:
					entity.add_component(C_TestC.new())
				entities.append(entity)
	)

	PerfHelpers.record_result("entity_with_components", scale, time_ms)
	world.purge(false)


## Test adding entities to world
func test_entity_world_addition(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Pre-create entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "PerfEntity_%d" % i
		entities.append(entity)

	# Time just the world addition
	var time_ms = PerfHelpers.time_it(
		func():
			for entity in entities:
				world.add_entity(entity, null, false)
	)

	PerfHelpers.record_result("entity_world_addition", scale, time_ms)
	world.purge(false)


## Test removing entities from world
func test_entity_removal(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Setup: create and add entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "PerfEntity_%d" % i
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time removal of half the entities
	var time_ms = PerfHelpers.time_it(
		func():
			var to_remove = entities.slice(0, scale / 2)
			for entity in to_remove:
				world.remove_entity(entity)
	)

	PerfHelpers.record_result("entity_removal", scale, time_ms)
	world.purge(false)


## Test bulk entity operations
func test_bulk_entity_operations(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Create batch
	for i in scale:
		var entity = Entity.new()
		entity.name = "BatchEntity_%d" % i
		entities.append(entity)

	# Time bulk addition to world
	var time_ms = PerfHelpers.time_it(func(): world.add_entities(entities))

	PerfHelpers.record_result("bulk_entity_operations", scale, time_ms)
	world.purge(false)


## Bulk spawn where every entity shares one composition (single archetype).
## This is the template-spawn case a true bulk-spawn path should collapse
## into one signature calc + one archetype insert per batch.
func test_bulk_spawn_grouped(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []
	for i in scale:
		var entity = Entity.new()
		entity.name = "GroupedEntity_%d" % i
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		entities.append(entity)

	var time_ms = PerfHelpers.time_it(func(): world.add_entities(entities))

	PerfHelpers.record_result("bulk_spawn_grouped", scale, time_ms)
	world.purge(false)


## Sustained spawn/despawn churn: repeatedly fill and empty the world with the
## same composition. Cycle 2+ re-hits the same archetypes — if transition
## edges/archetypes survive emptying, later cycles should cost the same or
## less than the first.
func test_spawn_despawn_churn(scale: int, test_parameters := [[100], [1000]]):
	var cycle_times: Array[float] = []

	for cycle in 3:
		var entities = []
		for i in scale:
			var entity = Entity.new()
			entity.name = "ChurnEntity_%d_%d" % [cycle, i]
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			entities.append(entity)

		var time_ms = PerfHelpers.time_it(
			func():
				world.add_entities(entities)
				for entity in entities:
					world.remove_entity(entity)
		)
		cycle_times.append(time_ms)

	PerfHelpers.record_result("spawn_despawn_churn_cycle1", scale, cycle_times[0])
	PerfHelpers.record_result("spawn_despawn_churn_cycle3", scale, cycle_times[2])
	prints(
		(
			"churn cycle3/cycle1 ratio: %.2f (<=1.0 means archetype/edge reuse works)"
			% (cycle_times[2] / maxf(cycle_times[0], 0.001))
		)
	)
	world.purge(false)
