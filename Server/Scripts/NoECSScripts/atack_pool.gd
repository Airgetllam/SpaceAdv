class_name MissilePool
extends RefCounted

var _pool: Array[Entity] = []
var _prefab: Entity
var _initial_size: int

func _init(prefab: Entity, size: int = 0):
	_prefab = prefab
	_initial_size = size
	_fill_pool(size)

# Создает начальное количество объектов
func _fill_pool(amount: int) -> void:
	for i in range(amount):
		var obj = Entity.new()
		_deactivate_object(obj)
		_pool.append(obj)

# Деактивирует объект (прячет и отключает обработку)
func _deactivate_object(obj: Entity) -> void:
	var entity_state: C_ExistenceState = obj.get_component(C_ExistenceState)
	entity_state.value = 0

# Активирует объект (показывает и включает обработку)
func _activate_object(obj: Entity) -> void:
	var entity_state: C_ExistenceState = obj.get_component(C_ExistenceState)
	entity_state.value = 1

# Получить объект из пула
func _get_entity() -> Entity:
	var obj: Entity
	if _pool.is_empty():
		obj = null
	else:
		obj = _pool.pop_back()
		_activate_object(obj)
	return obj

# Вернуть объект в пул
func return_object(obj: Entity) -> void:
	_deactivate_object(obj)
	_pool.append(obj)
