extends Component
class_name C_ServerIP

@export var UDP_connection: Array
@export var peers: Dictionary


func _init() -> void:
	var _server = UDPServer.new()
	_server.listen(9999)
	UDP_connection.append(_server)
	print('UDP server started!')


func add_peer(peer: PacketPeerUDP, nick: String) -> void:
	peers[peer] = nick
	property_changed.emit(self, "peers", peers, peers)
