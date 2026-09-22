class_name C_ServerIP
extends Component

static var instance: C_ServerIP = null

var UDP_connection: Array = []
var peers: Dictionary = {}          # PacketPeerUDP -> PeerState
var sessions: Dictionary = {}       # session_id(int) -> PeerState
var net_id_counter: int = 1
var net_id_to_entity: Dictionary = {}   # int -> Entity
var entity_to_net_id: Dictionary = {}   # Entity -> int
var tick: int = 0
var aoi_tick: int = 0

func _init() -> void:
	instance = self
	var server := UDPServer.new()
	var err := server.listen(NetConfig.SERVER_PORT)
	if err != OK:
		push_error("UDPServer.listen failed: %d" % err)
		return
	UDP_connection.append(server)
	NetLog.d("server", "listening on %d" % NetConfig.SERVER_PORT)

func allocate_net_id() -> int:
	var id := net_id_counter
	net_id_counter += 1
	return id

func register_entity(net_id: int, entity: Entity) -> void:
	net_id_to_entity[net_id] = entity
	entity_to_net_id[entity] = net_id

func get_entity(net_id: int) -> Entity:
	return net_id_to_entity.get(net_id, null)

func get_peer_by_net_id(net_id: int) -> PeerState:
	for ps in peers.values():
		if ps.net_id == net_id:
			return ps
	return null
