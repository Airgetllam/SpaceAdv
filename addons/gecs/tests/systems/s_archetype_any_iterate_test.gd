## Test system that records the shape of the `components` array produced by
## `with_any([...]).iterate([...])`. Used to document how iterate() columns
## behave when a query matches entities spread across multiple archetypes.
class_name ArchetypeAnyIterateTestSystem
extends System

# One entry per process() invocation:
#   { entities: int, col_sizes: Array[int], any_null: bool }
var invocations: Array = []


func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_TestA, C_TestB, C_TestC]).iterate(
		[C_TestA, C_TestB, C_TestC]
	)


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var col_sizes: Array = []
	var any_null := false
	for col in components:
		var arr := col as Array
		col_sizes.append(arr.size())
		for item in arr:
			if item == null:
				any_null = true
	invocations.append(
		{
			"entities": entities.size(),
			"col_sizes": col_sizes,
			"any_null": any_null,
		}
	)
