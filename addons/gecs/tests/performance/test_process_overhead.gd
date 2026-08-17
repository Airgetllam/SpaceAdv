extends GdUnitTestSuite
## Micro-benchmark: fixed per-call cost of world.process() with one system
## that matches nothing. Guards against flat per-frame overhead regressions.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


class NoMatchSystem:
	extends System

	func query() -> QueryBuilder:
		return q.with_all([C_TestD])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		pass


func test_process_call_overhead():
	for i in 1000:
		var e = Entity.new()
		e.add_component(C_TestA.new())
		world.add_entity(e, null, false)

	var system = NoMatchSystem.new()
	world.add_system(system)

	for i in 5:
		world.process(0.016)

	var time_ms = PerfHelpers.time_it(
		func():
			for i in 100:
				world.process(0.016)
	)
	PerfHelpers.record_result("process_call_overhead_x100", 1000, time_ms)
	prints("per process() call: %.3f ms" % (time_ms / 100.0))
