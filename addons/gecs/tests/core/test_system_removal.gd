## Regression tests for systems_by_group mutation-during-read defects:
## - process(): the PER_GROUP command-buffer flush re-read systems_by_group[group]
##   unchecked after a self-removing system erased the key mid-frame
## - remove_system(): unchecked group access crashed on double-remove
## - remove_system_group(): live-array iteration removed only every other system
extends GdUnitTestSuite

# Preloaded because a freshly added class_name may not be in the global class
# cache when running headless.
const SelfRemoving := preload("res://addons/gecs/tests/systems/s_self_removing.gd")

var runner: GdUnitSceneRunner
var world: World


## Counts its runs without any structural side effects; the bystander that a
## self-removing peer must not cause to be skipped.
class CountingSystem:
	extends System

	var run_count := 0

	func query():
		process_empty = true
		return ECS.world.query

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		run_count += 1


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## A system that removes itself during process() and empties its group must not
## crash the PER_GROUP flush loop that re-reads systems_by_group[group].
func test_self_removing_last_system_does_not_crash_process():
	var system := SelfRemoving.new()
	system.group = "one_shot"
	world.add_system(system)

	world.process(0.016, "one_shot")

	assert_int(system.run_count).is_equal(1)
	assert_bool(world.systems_by_group.has("one_shot")).is_false()


## Same scenario with a PER_GROUP flush-mode system in the group; the flush loop
## itself must survive the key being erased mid-frame.
func test_self_removing_systems_with_per_group_flush():
	var first := SelfRemoving.new()
	first.group = "one_shot"
	var second := SelfRemoving.new()
	second.group = "one_shot"
	second.command_buffer_flush_mode = System.FlushMode.PER_GROUP
	world.add_systems([first, second])

	# Self-removal must not skip the next system: both run on the same frame
	# and the group empties immediately.
	world.process(0.016, "one_shot")

	assert_int(first.run_count).is_equal(1)
	assert_int(second.run_count).is_equal(1)
	assert_bool(world.systems_by_group.has("one_shot")).is_false()


## A self-removing system shifts the live systems array; the system that moves
## into the vacated slot must still run on the same frame, not be skipped.
func test_self_removal_does_not_skip_next_system():
	var remover := SelfRemoving.new()
	remover.group = "mixed"
	var bystander := CountingSystem.new()
	bystander.group = "mixed"
	world.add_systems([remover, bystander])

	world.process(0.016, "mixed")

	assert_int(remover.run_count).is_equal(1)
	assert_int(bystander.run_count).is_equal(1)

	# The remover is gone; the bystander keeps running on later frames.
	world.process(0.016, "mixed")
	assert_int(bystander.run_count).is_equal(2)


## Removing a system twice (the second time after its group key is gone) must be
## safe, not an invalid-key crash.
func test_double_remove_system_is_safe():
	var system := System.new()
	system.group = "solo"
	world.add_system(system)

	world.remove_system(system)
	world.remove_system(system)

	assert_bool(world.systems_by_group.has("solo")).is_false()
	assert_bool(world.systems.has(system)).is_false()


## remove_system_group() must remove every system in the group, not every other
## one (live-array iteration while remove_system erases from it).
func test_remove_system_group_removes_all_systems():
	var group_systems: Array = []
	for i in 4:
		var system := System.new()
		system.group = "doomed"
		group_systems.append(system)
	world.add_systems(group_systems)
	assert_int(world.systems_by_group["doomed"].size()).is_equal(4)

	world.remove_system_group("doomed")

	assert_bool(world.systems_by_group.has("doomed")).is_false()
	for system in group_systems:
		assert_bool(world.systems.has(system)).is_false()
