class_name PeerState

var udp_peer: PacketPeerUDP
var nick: String = ""
var session_id: int = 0
var net_id: int = 0
var reliable: ReliableChannel = ReliableChannel.new()
var last_recv_ms: int = 0
var last_rtt_ms: int = 0
var last_acked_input_seq: int = 0

# Спавн: выставляется в _handle_hello, обрабатывается NetworkPeerRegistrationSystem
var needs_spawn: bool = false
var spawn_pos: Vector2 = Vector2.ZERO

# AOI
var visible_net_ids: Dictionary = {}       # net_id -> true
var last_sent_state: Dictionary = {}       # net_id -> snapshot Dictionary

# Очередь надёжных сообщений: Array[Dictionary { msg_type: int, body: PackedByteArray }]
var reliable_outbox: Array = []

func touch() -> void:
	last_recv_ms = Time.get_ticks_msec()

func is_timed_out(now_ms: int) -> bool:
	return (now_ms - last_recv_ms) > NetConfig.PEER_TIMEOUT_MS

func queue_reliable(msg_type: int, body: PackedByteArray) -> void:
	reliable_outbox.append({ "msg_type": msg_type, "body": body })
