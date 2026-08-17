## One-shot init-system pattern: removes itself from the world on its first run.
class_name SelfRemovingSystem
extends System

var run_count := 0


func query():
	process_empty = true
	return ECS.world.query


func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	run_count += 1
	ECS.world.remove_system(self)
