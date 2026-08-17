extends GdUnitTestSuite
## CHANGE DETECTION benchmarks (v9) — .changed() sparse-write win.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## CHANGE DETECTION (v9): system with .changed() vs plain system under sparse
## writes (1% of entities per frame). The changed() system should skip nearly
## all work — the headline FLECS-parity feature.
class SparseChangedSystem:
	extends System
	var processed_total: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest]).changed([C_ObserverTest])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		processed_total += entities.size()
		for entity in entities:
			var _v = entity.get_component(C_ObserverTest).value


class SparsePlainSystem:
	extends System
	var processed_total: int = 0

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		processed_total += entities.size()
		for entity in entities:
			var _v = entity.get_component(C_ObserverTest).value


func test_changed_query_sparse(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []
	for i in scale:
		var entity = Entity.new()
		entity.name = "Sparse_%d" % i
		entity.add_component(C_ObserverTest.new(i))
		world.add_entity(entity, null, false)
		entities.append(entity)

	var write_count = maxi(scale / 100, 1)

	# Plain system: processes ALL entities every frame regardless of writes
	var plain = SparsePlainSystem.new()
	world.add_system(plain)
	var plain_ms = PerfHelpers.time_it(
		func():
			for frame in 60:
				for i in write_count:
					var comp = entities[(frame * write_count + i) % scale].get_component(
						C_ObserverTest
					)
					comp.value += 1
				world.process(0.016)
	)
	world.remove_system(plain)
	PerfHelpers.record_result("changed_query_sparse_plain", scale, plain_ms)

	# changed() system: skips untouched archetypes/rows
	var changed_sys = SparseChangedSystem.new()
	world.add_system(changed_sys)
	world.process(0.016)  # drain the initial all-new pass
	var changed_ms = PerfHelpers.time_it(
		func():
			for frame in 60:
				for i in write_count:
					var comp = entities[(frame * write_count + i) % scale].get_component(
						C_ObserverTest
					)
					comp.value += 1
				world.process(0.016)
	)
	PerfHelpers.record_result("changed_query_sparse", scale, changed_ms)
	prints(
		(
			"changed() processed %d rows vs plain %d — %.1fx frame-time win"
			% [
				changed_sys.processed_total,
				plain.processed_total,
				plain_ms / maxf(changed_ms, 0.001),
			]
		)
	)
	world.purge(false)
