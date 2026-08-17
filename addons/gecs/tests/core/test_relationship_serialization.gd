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


func test_serialize_entity_with_basic_relationship():
	# Create two entities with a basic relationship
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())

	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())

	# Create relationship: A -> B
	var relationship = Relationship.new(C_TestC.new(), entity_b)
	entity_a.add_relationship(relationship)

	world.add_entity(entity_a)
	world.add_entity(entity_b)

	# Serialize only entity A (entity B should be auto-included)
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)

	# Validate serialization
	assert_that(serialized_data).is_not_null()
	assert_that(serialized_data.entities).has_size(2)  # Both A and B should be included

	# Check that entity B is marked as auto-included
	var entity_a_data = serialized_data.entities.filter(func(e): return e.entity_name == "EntityA")[0]
	var entity_b_data = serialized_data.entities.filter(func(e): return e.entity_name == "EntityB")[0]

	assert_that(entity_a_data.auto_included).is_false()  # Original query entity
	assert_that(entity_b_data.auto_included).is_true()  # Auto-included dependency

	# Check relationship data
	assert_that(entity_a_data.relationships).has_size(1)
	var rel_data = entity_a_data.relationships[0]
	assert_that(rel_data.target_type).is_equal("Entity")
	assert_that(rel_data.target_entity_id).is_equal(entity_b.id)


func test_deserialize_entity_with_basic_relationship():
	# Create and serialize entities with relationship
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())

	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())

	var relationship = Relationship.new(C_TestC.new(), entity_b)
	entity_a.add_relationship(relationship)

	world.add_entity(entity_a)
	world.add_entity(entity_b)

	# Serialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)

	# Save and load
	var file_path = "res://reports/test_relationship_basic.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)

	# Validate deserialization
	assert_that(deserialized_entities).has_size(2)

	var des_entity_a = deserialized_entities.filter(func(e): return e.has_component(C_TestA))[0]
	var des_entity_b = deserialized_entities.filter(func(e): return e.has_component(C_TestB))[0]

	# Check that relationships are restored
	assert_that(des_entity_a.relationships).has_size(1)
	var des_relationship = des_entity_a.relationships[0]
	assert_that(des_relationship.target).is_equal(des_entity_b)

	# Cleanup
	for entity in deserialized_entities:
		auto_free(entity)


func test_circular_relationships():
	# Create entities with circular relationships: A -> B -> A
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())

	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())

	# Create circular relationships
	var rel_a_to_b = Relationship.new(C_TestC.new(), entity_b)
	var rel_b_to_a = Relationship.new(C_TestD.new(), entity_a)

	entity_a.add_relationship(rel_a_to_b)
	entity_b.add_relationship(rel_b_to_a)

	world.add_entity(entity_a)
	world.add_entity(entity_b)

	# Serialize starting from entity A
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)

	# Should include both entities (no infinite loop)
	assert_that(serialized_data.entities).has_size(2)

	# Deserialize and validate
	var file_path = "res://reports/test_relationship_circular.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)

	assert_that(deserialized_entities).has_size(2)

	var des_a = deserialized_entities.filter(func(e): return e.has_component(C_TestA))[0]
	var des_b = deserialized_entities.filter(func(e): return e.has_component(C_TestB))[0]

	# Validate circular relationships are restored
	assert_that(des_a.relationships).has_size(1)
	assert_that(des_b.relationships).has_size(1)
	assert_that(des_a.relationships[0].target).is_equal(des_b)
	assert_that(des_b.relationships[0].target).is_equal(des_a)

	# Cleanup
	for entity in deserialized_entities:
		auto_free(entity)


func test_component_target_relationship():
	# Create entity with component-based relationship
	var entity = Entity.new()
	entity.name = "EntityWithComponentRel"
	entity.add_component(C_TestA.new())

	# Create relationship with Component target
	var target_component = C_TestB.new()
	# Note: Components don't have a 'name' property, so we don't set it
	var relationship = Relationship.new(C_TestC.new(), target_component)
	entity.add_relationship(relationship)

	world.add_entity(entity)

	# Serialize and deserialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)

	var file_path = "res://reports/test_relationship_component.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)

	# Validate
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.relationships).has_size(1)

	var des_relationship = des_entity.relationships[0]
	assert_that(des_relationship.target is C_TestB).is_true()

	# Cleanup
	auto_free(des_entity)


func test_script_target_relationship():
	# Create entity with script archetype relationship
	var entity = Entity.new()
	entity.name = "EntityWithScriptRel"
	entity.add_component(C_TestA.new())

	# Create relationship with Script target
	var relationship = Relationship.new(C_TestC.new(), C_TestB)
	entity.add_relationship(relationship)

	world.add_entity(entity)

	# Serialize and deserialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)

	var file_path = "res://reports/test_relationship_script.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)

	# Validate
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.relationships).has_size(1)

	var des_relationship = des_entity.relationships[0]
	assert_that(des_relationship.target).is_equal(C_TestB)

	# Cleanup
	auto_free(des_entity)


func test_id_persistence_across_save_load_cycles():
	# Create entity and save its UUID
	var entity = Entity.new()
	entity.name = "UUIDTestEntity"
	entity.add_component(C_TestA.new())

	world.add_entity(entity)
	var original_id = entity.id

	# Serialize, save, and load multiple times
	var query = world.query.with_all([C_TestA])

	for cycle in range(3):
		var serialized_data = ECS.serialize(query)
		var file_path = "res://reports/test_id_cycle_" + str(cycle) + ".tres"
		ECS.save(serialized_data, file_path)

		var deserialized_entities = ECS.deserialize(file_path)
		assert_that(deserialized_entities).has_size(1)

		var des_entity = deserialized_entities[0]
		assert_that(des_entity.id).is_equal(original_id)

		# Cleanup
		auto_free(des_entity)


func test_deep_relationship_chain():
	# Create a chain: A -> B -> C -> D
	var entities = []
	for i in range(4):
		var entity = Entity.new()
		entity.name = "Entity" + String.num(i)
		entity.add_component(C_TestA.new())
		entities.append(entity)
		world.add_entity(entity)

	# Create chain relationships
	for i in range(3):
		var relationship = Relationship.new(C_TestC.new(), entities[i + 1])
		entities[i].add_relationship(relationship)

	# Serialize starting from first entity only - create a query that matches just the first entity
	# We'll use a unique component for the first entity
	entities[0].add_component(C_TestE.new())  # Add unique component to first entity
	var query = world.query.with_all([C_TestE])
	var serialized_data = ECS.serialize(query)

	# Should auto-include entire chain
	assert_that(serialized_data.entities).has_size(4)

	# Verify auto-inclusion flags
	var auto_included_count = 0
	var original_entity_count = 0

	for entity_data in serialized_data.entities:
		if entity_data.auto_included:
			auto_included_count += 1
		else:
			original_entity_count += 1

	assert_that(original_entity_count).is_equal(1)  # Only one entity from original query
	assert_that(auto_included_count).is_equal(3)  # Three entities auto-included

	# Test deserialization
	var file_path = "res://reports/test_relationship_chain.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)

	assert_that(deserialized_entities).has_size(4)

	# Cleanup
	for entity in deserialized_entities:
		auto_free(entity)


## Serialize everything matching [param query], purge the world, restore, and re-add.
## This is the level-swap path: World.purge() plus GECSIO round trip, no file involved.
func _round_trip(query: QueryBuilder) -> Array:
	var data = ECS.serialize(query)
	world.purge(false)
	var restored = GECSIO.deserialize_gecs_data(data)
	world.add_entities(restored)
	return restored


## REGRESSION: a deserialized Relationship must be matchable, not merely present.
## to_relationship() used to build an empty Relationship.new() and assign `relation`
## afterwards, which left the cached _relation_script null. matches() compares that
## cache, so every restored relationship failed get/has/remove_relationship and every
## with_relationship() query while still showing up in entity.relationships.
func test_deserialized_relationship_is_matchable():
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())

	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())

	entity_a.add_relationship(Relationship.new(C_TestC.new(), entity_b))

	world.add_entity(entity_a)
	world.add_entity(entity_b)

	# In-memory round trip (the level-swap path: serialize, purge, restore).
	var data = ECS.serialize(world.query.with_all([C_TestA]))
	world.purge(false)
	var restored = GECSIO.deserialize_gecs_data(data)
	world.add_entities(restored)

	var des_a = restored.filter(func(e): return e.has_component(C_TestA))[0]
	var des_b = restored.filter(func(e): return e.has_component(C_TestB))[0]

	# Wildcard probe (Relationship.new(C_TestC.new(), null)) must find it.
	var found = des_a.get_relationship(Relationship.new(C_TestC.new(), null))
	assert_that(found).is_not_null()
	assert_that(found.target).is_equal(des_b)

	# Exact-target probe and the has_ fast path must agree.
	assert_bool(des_a.has_relationship(Relationship.new(C_TestC.new(), des_b))).is_true()
	assert_bool(des_a.has_relationship(Relationship.new(C_TestD.new(), null))).is_false()

	# The restored relationship must also satisfy a with_relationship() query.
	var matched = (
		world.query.with_relationship([Relationship.new(C_TestC.new(), ECS.wildcard)]).execute()
	)
	assert_that(matched).contains([des_a])


## A Component target must stay matchable. matches() compares component targets by
## get_script(), and the restored target is a duplicate rather than the original
## instance, so type matching (not identity) has to carry it.
func test_deserialized_component_target_is_matchable():
	var entity = Entity.new()
	entity.name = "EntityWithComponentRel"
	entity.add_component(C_TestA.new())
	entity.add_relationship(Relationship.new(C_TestC.new(), C_TestB.new()))
	world.add_entity(entity)

	var restored = _round_trip(world.query.with_all([C_TestA]))
	var des = restored[0]

	assert_bool(des.has_relationship(Relationship.new(C_TestC.new(), C_TestB.new()))).is_true()
	# Archetype (Script) probe against a Component target must match too.
	assert_bool(des.has_relationship(Relationship.new(C_TestC.new(), C_TestB))).is_true()
	# Wrong component type must not match.
	assert_bool(des.has_relationship(Relationship.new(C_TestC.new(), C_TestD.new()))).is_false()

	var matched = (
		world.query.with_relationship([Relationship.new(C_TestC.new(), C_TestB.new())]).execute()
	)
	assert_that(matched).contains([des])


## A Script (archetype) target must stay matchable after a round trip. The target is
## reloaded by resource path, so it must resolve back to the same Script reference.
func test_deserialized_script_target_is_matchable():
	var entity = Entity.new()
	entity.name = "EntityWithScriptRel"
	entity.add_component(C_TestA.new())
	entity.add_relationship(Relationship.new(C_TestC.new(), C_TestB))
	world.add_entity(entity)

	var restored = _round_trip(world.query.with_all([C_TestA]))
	var des = restored[0]

	assert_bool(des.has_relationship(Relationship.new(C_TestC.new(), C_TestB))).is_true()
	assert_bool(des.has_relationship(Relationship.new(C_TestC.new(), C_TestD))).is_false()

	var matched = (
		world.query.with_relationship([Relationship.new(C_TestC.new(), C_TestB)]).execute()
	)
	assert_that(matched).contains([des])


## Relation component DATA must survive and stay queryable. This exercises the
## relation_query branch of matches(), which compares the cached relation script
## before evaluating property criteria.
func test_deserialized_relation_data_is_queryable():
	var entity_a = Entity.new()
	entity_a.add_component(C_TestA.new())
	var entity_b = Entity.new()
	entity_b.add_component(C_TestB.new())
	entity_a.add_relationship(Relationship.new(C_TestC.new(42), entity_b))
	world.add_entity(entity_a)
	world.add_entity(entity_b)

	var restored = _round_trip(world.query.with_all([C_TestA]))
	var des_a = restored.filter(func(e): return e.has_component(C_TestA))[0]

	# The relation payload itself round-tripped.
	var found = des_a.get_relationship(Relationship.new(C_TestC.new(), null))
	assert_that(found).is_not_null()
	assert_int(found.relation.value).is_equal(42)

	# ...and is reachable through a property-query relationship.
	var hit = (
		world
		. query
		. with_relationship([Relationship.new({C_TestC: {"value": {"_eq": 42}}}, ECS.wildcard)])
		. execute()
	)
	assert_that(hit).contains([des_a])

	var miss = (
		world
		. query
		. with_relationship([Relationship.new({C_TestC: {"value": {"_eq": 7}}}, ECS.wildcard)])
		. execute()
	)
	assert_that(miss).is_empty()


## remove_relationship() matches by pattern, so it fails on unmatchable restored
## relationships exactly like get/has do. Covers the removal side of the same cache.
func test_deserialized_relationship_can_be_removed():
	var entity_a = Entity.new()
	entity_a.add_component(C_TestA.new())
	var entity_b = Entity.new()
	entity_b.add_component(C_TestB.new())
	entity_a.add_relationship(Relationship.new(C_TestC.new(), entity_b))
	world.add_entity(entity_a)
	world.add_entity(entity_b)

	var restored = _round_trip(world.query.with_all([C_TestA]))
	var des_a = restored.filter(func(e): return e.has_component(C_TestA))[0]

	des_a.remove_relationship(Relationship.new(C_TestC.new(), ECS.wildcard))
	assert_that(des_a.relationships).is_empty()
	assert_bool(des_a.has_relationship(Relationship.new(C_TestC.new(), null))).is_false()

	var matched = (
		world.query.with_relationship([Relationship.new(C_TestC.new(), ECS.wildcard)]).execute()
	)
	assert_that(matched).is_empty()


## REGRESSION (ZAMN hub -> level -> hub): relationships must survive REPEATED swaps.
## A single round trip is not enough coverage. World.purge() resets the entity handle
## allocator, so the second swap re-allocates ids that the restored entities already
## hold, and relationship targets must still resolve to the right entity.
func test_relationships_survive_repeated_round_trips():
	var owner_entity = Entity.new()
	owner_entity.name = "Owner"
	owner_entity.add_component(C_TestA.new())

	var item_a = Entity.new()
	item_a.name = "ItemA"
	item_a.add_component(C_TestB.new())
	var item_b = Entity.new()
	item_b.name = "ItemB"
	item_b.add_component(C_TestB.new())

	# Both items point at the owner, mirroring ZAMN's C_OwnedBy inventory model.
	item_a.add_relationship(Relationship.new(C_TestC.new(), owner_entity))
	item_b.add_relationship(Relationship.new(C_TestC.new(), owner_entity))

	world.add_entity(owner_entity)
	world.add_entity(item_a)
	world.add_entity(item_b)

	for swap in range(3):
		var restored = _round_trip(world.query.with_all([C_TestB]))
		assert_array(restored).has_size(3)

		var des_owner = restored.filter(func(e): return e.has_component(C_TestA))[0]
		var des_items = restored.filter(func(e): return e.has_component(C_TestB))

		assert_array(des_items).has_size(2)
		for item in des_items:
			# The exact failure from the field: get_relationship(...).target was null.
			var rel = item.get_relationship(Relationship.new(C_TestC.new(), null))
			assert_that(rel).is_not_null()
			assert_that(rel.target).is_equal(des_owner)

		# "Which items does this owner own?" (the inventory query).
		var owned = (
			world.query.with_relationship([Relationship.new(C_TestC.new(), des_owner)]).execute()
		)
		assert_array(owned).has_size(2)


func test_backward_compatibility_no_relationships():
	# Test that entities without relationships still work
	var entity = Entity.new()
	entity.name = "NoRelationshipEntity"
	entity.add_component(C_TestA.new())

	world.add_entity(entity)

	# Serialize and deserialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)

	var file_path = "res://reports/test_no_relationships.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)

	# Should work normally
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.name).is_equal("NoRelationshipEntity")
	assert_that(des_entity.relationships).has_size(0)
	assert_that(des_entity.id).is_not_equal(0)

	# Cleanup
	auto_free(des_entity)
