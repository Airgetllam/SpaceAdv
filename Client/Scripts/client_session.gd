extends Node
## Autoload. Хранит состояние сессии клиента между сценами.

var session_id: int = 0
var net_id: int = 0
var tick_rate: int = 20
var map_min: Vector2 = Vector2.ZERO
var map_max: Vector2 = Vector2.ZERO
var udp: PacketPeerUDP = null
var game_node: Node = null

# ─── Этап 9 ────────────────────────────────────────────────────────
# Надёжный канал приёмки. Передаётся из connect.gd в Game.tscn,
# чтобы окно seq и last_seen не терялись при смене сцены.
var reliable_recv: ReliableChannel = null

# Реестр сущностей: net_id ↔ Entity (заполняется в клиентских системах).
var net_id_to_entity: Dictionary = {}
var entity_to_net_id: Dictionary = {}

# Счётчики, живущие между сценами.
var next_input_seq: int = 1
var next_ping_seq: int = 1


func reset() -> void:
	game_node = null
	session_id = 0
	net_id = 0
	tick_rate = 20
	map_min = Vector2.ZERO
	map_max = Vector2.ZERO
	udp = null
	reliable_recv = null
	net_id_to_entity.clear()
	entity_to_net_id.clear()
	next_input_seq = 1
	next_ping_seq = 1


func register_entity(nid: int, e) -> void:
	net_id_to_entity[nid] = e
	entity_to_net_id[e] = nid


func unregister_entity(nid: int) -> void:
	var e = net_id_to_entity.get(nid)
	if e != null:
		entity_to_net_id.erase(e)
	net_id_to_entity.erase(nid)


func get_entity(nid: int):
	return net_id_to_entity.get(nid)
