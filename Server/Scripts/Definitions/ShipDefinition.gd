extends Resource
class_name ShipDefinition

## Название модуля, отображаемое в интерфейсе.
@export var ship_name: String = ""

## Массив данных о модулях, из которых состоит корабль.
## Каждый словарь содержит ключи:
##   - "name": String — имя модуля
##   - "blocks_data": Array[Dictionary]
##        - "block_id": int
##        - "local_pos": Vector2i — позиция блока относительно корня модуля
@export var modules_data: Array[Dictionary] = []

## количество блоков корабля.
@export var size: int
