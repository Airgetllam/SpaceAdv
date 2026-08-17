## Regression test: a relationship whose Entity target was freed outside
## remove_entity (direct free/queue_free teardown) left a dangling rel.target,
## and QueryCacheKey.build's `rel.target is Component` chain hard-errors on a
## freed operand. Structural changes on the holding entity must not crash.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func test_structural_change_with_freed_relationship_target():
	var holder := Entity.new()
	var target := Entity.new()
	world.add_entity(holder)
	world.add_entity(target)
	holder.add_relationship(Relationship.new(C_TestA.new(), target))

	# Free the target directly; bypasses remove_entity's
	# _cleanup_relationships_to_target, leaving holder with a dangling target.
	target.free()

	# Any structural change re-hashes holder's signature via QueryCacheKey.build.
	holder.add_component(C_TestB.new())

	assert_bool(holder.has_component(C_TestB)).is_true()


func test_removing_component_with_freed_relationship_target():
	var holder := Entity.new()
	var target := Entity.new()
	world.add_entity(holder)
	world.add_entity(target)
	holder.add_component(C_TestB.new())
	holder.add_relationship(Relationship.new(C_TestA.new(), target))

	target.free()

	holder.remove_component(C_TestB)

	assert_bool(holder.has_component(C_TestB)).is_false()


func test_serialize_with_freed_relationship_target():
	var holder := Entity.new()
	holder.name = "Holder"
	holder.add_component(C_TestA.new())
	var target := Entity.new()
	world.add_entity(holder)
	world.add_entity(target)
	holder.add_relationship(Relationship.new(C_TestC.new(), target))

	target.free()

	# Serializing must not crash; the dangling relationship is dropped from the save.
	var data = ECS.serialize(world.query.with_all([C_TestA]))

	assert_that(data).is_not_null()
	assert_that(data.entities).has_size(1)
	assert_that(data.entities[0].relationships).has_size(0)


func test_serialize_keeps_live_relationship_drops_dangling():
	var holder := Entity.new()
	holder.name = "Holder"
	holder.add_component(C_TestA.new())
	var live_target := Entity.new()
	live_target.name = "LiveTarget"
	live_target.add_component(C_TestB.new())
	var doomed_target := Entity.new()
	world.add_entity(holder)
	world.add_entity(live_target)
	world.add_entity(doomed_target)
	holder.add_relationship(Relationship.new(C_TestC.new(), live_target))
	holder.add_relationship(Relationship.new(C_TestD.new(), doomed_target))

	doomed_target.free()

	# The auto-include walk must skip the freed target but still follow the live one.
	var data = ECS.serialize(world.query.with_all([C_TestA]))

	assert_that(data.entities).has_size(2)
	# Filter on auto_included, not entity_name: a queue_freed node from an
	# earlier test can still occupy the name and force an auto-rename.
	var holder_data = data.entities.filter(func(e): return not e.auto_included)[0]
	assert_that(holder_data.relationships).has_size(1)
	assert_that(holder_data.relationships[0].target_type).is_equal("Entity")

	# Round-trip: the save loads back with only the live relationship intact.
	var file_path = "res://reports/test_dangling_relationship_target.tres"
	ECS.save(data, file_path)
	var restored = ECS.deserialize(file_path)

	assert_that(restored).has_size(2)
	var restored_holder = restored.filter(func(e): return e.has_component(C_TestA))[0]
	var restored_target = restored.filter(func(e): return e.has_component(C_TestB))[0]
	assert_that(restored_holder.relationships).has_size(1)
	assert_that(restored_holder.relationships[0].target).is_equal(restored_target)

	for entity in restored:
		auto_free(entity)
