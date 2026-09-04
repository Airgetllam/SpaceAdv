extends Component
class_name C_ServerIP

@export var UDP_connection: Array
@export var peers: Dictionary
@export var sessions: Dictionary  # key: peer, value: session_id (int)

func _init() -> void:
	var _server = UDPServer.new()
	_server.listen(9999)
	UDP_connection.append(_server)
	print('UDP server started!')

func add_peer(peer: PacketPeerUDP, params: Dictionary) -> void:
	peers[peer] = params
	# Генерируем session_id
	var session_id = randi()
	sessions[peer] = session_id
	# Отправляем session_id клиенту
	var response = {"type": "session", "session_id": session_id}
	var json = JSON.stringify(response)
	peer.put_packet(json.to_utf8_buffer())
	property_changed.emit(self, "peers", peers, peers)

func remove_peer(peer: PacketPeerUDP) -> void:
	if peers.has(peer):
		var disconnect_data = {"type": "disconnect"}
		var json = JSON.stringify(disconnect_data)
		peer.put_packet(json.to_utf8_buffer())
		
		peer.close()
		peers.erase(peer)
		sessions.erase(peer)
		property_changed.emit(self, "peers", peers, peers)
