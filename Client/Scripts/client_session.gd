extends Node
## Autoload. Хранит состояние сессии клиента между сценами.

var session_id: int = 0
var net_id: int = 0
var tick_rate: int = 20
var map_min: Vector2 = Vector2.ZERO
var map_max: Vector2 = Vector2.ZERO
var udp: PacketPeerUDP = null
