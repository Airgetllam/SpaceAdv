extends GdUnitTestSuite
## Test suite for the Entity ID system functionality (v9 identity contract).
## Entity.id is a 64-bit generational int handle allocated by World.add_entity;
## pre-assigned nonzero ids are kept verbatim (deserialization / replication);
## the semantic-name singleton pattern moved to Entity.alias.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func test_entity_id_auto_allocation():
	# Entities get a nonzero handle allocated on add_entity
	var entity = Entity.new()
	entity.name = "TestEntity"

	# ID is the 0 sentinel before registration
	assert_int(entity.id).is_equal(0)

	world.add_entity(entity)

	# ID should now be a live nonzero handle
	assert_int(entity.id).is_not_equal(0)
	assert_bool(world.is_alive(entity.id)).is_true()

	# Should not change on subsequent reads (stable identity)
	var first_id = entity.id
	var second_id = entity.id
	assert_int(second_id).is_equal(first_id)


func test_entity_preassigned_id_kept_verbatim():
	# Pre-assigning a nonzero int id before add (deserialization / network
	# replication) keeps that foreign identity verbatim.
	var entity = Entity.new()
	entity.name = "ReplicatedEntity"

	entity.id = 9001
	assert_int(entity.id).is_equal(9001)

	world.add_entity(entity)
	assert_int(entity.id).is_equal(9001)
	assert_object(world.get_entity_by_id(9001)).is_same(entity)

	# Identity should not change on subsequent access
	assert_int(entity.id).is_equal(9001)


func test_world_id_tracking():
	# World tracks pre-assigned ids and provides O(1) lookup
	var entity1 = Entity.new()
	entity1.name = "Entity1"
	entity1.id = 1001

	var entity2 = Entity.new()
	entity2.name = "Entity2"
	entity2.id = 1002

	world.add_entity(entity1)
	world.add_entity(entity2)

	# Test lookup by ID
	assert_object(world.get_entity_by_id(1001)).is_same(entity1)
	assert_object(world.get_entity_by_id(1002)).is_same(entity2)
	assert_object(world.get_entity_by_id(999999)).is_null()

	# Test has_entity_with_id / is_alive
	assert_bool(world.has_entity_with_id(1001)).is_true()
	assert_bool(world.has_entity_with_id(1002)).is_true()
	assert_bool(world.has_entity_with_id(999999)).is_false()
	assert_bool(world.is_alive(1001)).is_true()
	assert_bool(world.is_alive(999999)).is_false()


func test_world_id_replacement():
	# Same-id add replaces the existing entity (collision semantics from v8)
	var entity1 = Entity.new()
	entity1.name = "FirstEntity"
	entity1.id = 7777
	var comp1 = C_TestA.new()
	comp1.value = 100
	entity1.add_component(comp1)
	world.add_entity(entity1)

	# Verify it's in the world
	assert_int(world.entities.size()).is_equal(1)
	assert_object(world.get_entity_by_id(7777)).is_same(entity1)

	# Create second entity with same ID
	var entity2 = Entity.new()
	entity2.name = "ReplacementEntity"
	entity2.id = 7777
	var comp2 = C_TestA.new()
	comp2.value = 200
	entity2.add_component(comp2)

	# Add to world - should replace first entity
	world.add_entity(entity2)

	# Should still have only one entity
	assert_int(world.entities.size()).is_equal(1)
	# Should be the new entity
	var found_entity = world.get_entity_by_id(7777)
	assert_object(found_entity).is_same(entity2)
	assert_str(found_entity.name).is_equal("ReplacementEntity")

	# Verify component value is from new entity
	var comp = found_entity.get_component(C_TestA) as C_TestA
	assert_int(comp.value).is_equal(200)


func test_alias_singleton_pattern():
	# The old `entity.id = "singleton_player"` pattern now lives on Entity.alias
	var player1 = Entity.new()
	player1.name = "Player1"
	player1.alias = &"singleton_player"
	var comp1 = C_TestA.new()
	comp1.value = 100
	player1.add_component(comp1)
	world.add_entity(player1)

	assert_bool(world.has_entity_with_alias(&"singleton_player")).is_true()
	assert_object(world.get_entity_by_alias(&"singleton_player")).is_same(player1)

	# Same-alias add REPLACES the existing entity (singleton pattern)
	var player2 = Entity.new()
	player2.name = "Player2"
	player2.alias = &"singleton_player"
	var comp2 = C_TestA.new()
	comp2.value = 200
	player2.add_component(comp2)
	world.add_entity(player2)

	assert_int(world.entities.size()).is_equal(1)
	var found_entity = world.get_entity_by_alias(&"singleton_player")
	assert_object(found_entity).is_same(player2)
	assert_str(found_entity.name).is_equal("Player2")

	var found_comp = found_entity.get_component(C_TestA) as C_TestA
	assert_int(found_comp.value).is_equal(200)

	# Alias is a NAME, not the identity — the handle is still an allocated int
	assert_int(player2.id).is_not_equal(0)


func test_alias_registry_runtime_api():
	# register_alias / unregister_alias re-point names at runtime
	var entity = Entity.new()
	entity.name = "AliasedEntity"
	world.add_entity(entity)

	assert_bool(world.has_entity_with_alias(&"boss")).is_false()
	world.register_alias(&"boss", entity)
	assert_object(world.get_entity_by_alias(&"boss")).is_same(entity)

	world.unregister_alias(&"boss")
	assert_bool(world.has_entity_with_alias(&"boss")).is_false()
	assert_object(world.get_entity_by_alias(&"boss")).is_null()


func test_alias_cleared_on_remove():
	# Removing an entity clears its alias registration
	var entity = Entity.new()
	entity.name = "TransientSingleton"
	entity.alias = &"transient"
	world.add_entity(entity)
	assert_bool(world.has_entity_with_alias(&"transient")).is_true()

	world.remove_entity(entity)
	assert_bool(world.has_entity_with_alias(&"transient")).is_false()


func test_auto_allocated_id_tracking():
	# Auto-allocated handles are also tracked by the world
	var entity = Entity.new()
	entity.name = "AutoIDEntity"
	# Don't pre-assign — let the world allocate

	world.add_entity(entity)

	# Should have an allocated nonzero handle
	assert_int(entity.id).is_not_equal(0)

	# Should be trackable by ID
	assert_object(world.get_entity_by_id(entity.id)).is_same(entity)
	assert_bool(world.has_entity_with_id(entity.id)).is_true()


func test_id_uniqueness():
	# Multiple entities get unique handles
	var ids = {}
	var entities = []

	# Allocate 100 entities with auto handles
	for i in range(100):
		var entity = Entity.new()
		entity.name = "Entity%d" % i
		world.add_entity(entity)
		entities.append(entity)

		# Should not have seen this ID before
		assert_bool(ids.has(entity.id)).is_false()
		ids[entity.id] = true

	# All IDs should be unique
	assert_int(ids.size()).is_equal(100)


func test_remove_entity_clears_id_registry():
	# Removing entities clears them from the ID registry — the handle dies
	var entity = Entity.new()
	entity.name = "TestEntity"

	world.add_entity(entity)
	var handle = entity.id
	assert_bool(world.has_entity_with_id(handle)).is_true()
	assert_bool(world.is_alive(handle)).is_true()

	world.remove_entity(entity)
	assert_bool(world.has_entity_with_id(handle)).is_false()
	assert_bool(world.is_alive(handle)).is_false()
	assert_object(world.get_entity_by_id(handle)).is_null()


func test_handle_recycling_never_aliases():
	# Recycled slots carry a bumped generation: a new entity's handle must
	# differ from a removed entity's stale handle even if the slot is reused.
	var old_entity = Entity.new()
	old_entity.name = "OldEntity"
	world.add_entity(old_entity)
	var stale_handle = old_entity.id

	world.remove_entity(old_entity)
	assert_bool(world.is_alive(stale_handle)).is_false()

	var new_entity = Entity.new()
	new_entity.name = "NewEntity"
	world.add_entity(new_entity)

	# New handle must never equal the stale one (generation bumped)
	assert_int(new_entity.id).is_not_equal(stale_handle)
	assert_bool(world.is_alive(new_entity.id)).is_true()
	# The stale handle stays dead — it does not resurrect with the new entity
	assert_bool(world.is_alive(stale_handle)).is_false()
	assert_object(world.get_entity_by_id(stale_handle)).is_null()


func test_set_entity_range_reserves_low_slots():
	# FLECS-style range reservation: local allocations stay above base_index so
	# they can't collide with an authority's low-slot handles.
	world.set_entity_range(1000)

	var local_entity = Entity.new()
	local_entity.name = "LocalEntity"
	world.add_entity(local_entity)

	# Low 32 bits carry the biased slot index — must be above the reserved range
	assert_bool((local_entity.id & 0xFFFFFFFF) > 1000).is_true()

	# A replicated entity with a low server-assigned handle coexists safely
	var replicated = Entity.new()
	replicated.name = "Replicated"
	replicated.id = 5
	world.add_entity(replicated)
	assert_object(world.get_entity_by_id(5)).is_same(replicated)
	assert_object(world.get_entity_by_id(local_entity.id)).is_same(local_entity)


func test_id_system_comprehensive_demo():
	# Comprehensive test demonstrating all ID system features
	# Test 1: Auto handle allocation
	var auto_entity = Entity.new()
	auto_entity.name = "AutoIDEntity"
	world.add_entity(auto_entity)

	var generated_id = auto_entity.id
	assert_int(generated_id).is_not_equal(0)  # Should auto-allocate

	# Should still have the same ID
	assert_int(auto_entity.id).is_equal(generated_id)

	# Test 2: Alias singleton behavior
	var player1 = Entity.new()
	player1.name = "Player1"
	player1.alias = &"singleton_player"
	var comp1 = C_TestA.new()
	comp1.value = 100
	player1.add_component(comp1)
	world.add_entity(player1)

	assert_int(world.entities.size()).is_equal(2)  # auto_entity + player1
	assert_object(world.get_entity_by_alias(&"singleton_player")).is_same(player1)

	# Add second entity with same alias - should replace first
	var player2 = Entity.new()
	player2.name = "Player2"
	player2.alias = &"singleton_player"
	var comp2 = C_TestA.new()
	comp2.value = 200
	player2.add_component(comp2)
	world.add_entity(player2)

	assert_int(world.entities.size()).is_equal(2)  # Should still be 2 (replacement occurred)
	var found_entity = world.get_entity_by_alias(&"singleton_player")
	assert_object(found_entity).is_same(player2)  # Should be the new entity
	assert_str(found_entity.name).is_equal("Player2")

	var found_comp = found_entity.get_component(C_TestA) as C_TestA
	assert_int(found_comp.value).is_equal(200)  # Should have new entity's data

	# Test 3: Multiple entity tracking with pre-assigned handles
	var tracked_entities = []
	for i in range(3):
		var entity = Entity.new()
		entity.name = "TrackedEntity%d" % i
		entity.id = 5000 + i
		tracked_entities.append(entity)
		world.add_entity(entity)

	# Verify all are tracked
	for i in range(3):
		var id = 5000 + i
		assert_bool(world.has_entity_with_id(id)).is_true()
		assert_object(world.get_entity_by_id(id)).is_same(tracked_entities[i])

	# Test 4: ID registry cleanup on removal
	world.remove_entity(tracked_entities[1])
	assert_bool(world.has_entity_with_id(5001)).is_false()
	assert_object(world.get_entity_by_id(5001)).is_null()
	# Others should still exist
	assert_bool(world.has_entity_with_id(5000)).is_true()
	assert_bool(world.has_entity_with_id(5002)).is_true()
