extends Resource
class_name BlockDefinition

## Уникальный идентификатор блока (например, "armor_basic", "barrel_laser").
@export var id: String = ""

## Отображаемое имя блока в интерфейсе.
@export var display_name: String = ""

## Текстура блока для отображения в редакторах и игре.
@export var texture: Texture2D = null

## Категория блока (оружие, броня, двигатель, модуль и т.д.).
@export var category: String = ""

## Словарь со статистикой блока.
## Ожидаемые ключи: "hp", "armor", "mass", "energy_cost" и др.
@export var stats: Dictionary = {
	"hp": 0,
	"mass": 0,
	"armor": 0,
	"energy_cost": 0,
}

#@export var valid_patterns: Array[Pattern3x3]

func get_hp() -> int:
	return stats.get("hp", 0) as int

func get_armor() -> float:
	return stats.get("armor", 0) as float

func get_mass() -> float:
	return stats.get("mass", 0.0) as float

func get_energy_cost() -> float:
	return stats.get("energy_cost", 0.0) as float

func get_thrust() -> int:
	return stats.get("thrust", 0) as int
