class_name PeerState

var udp_peer: PacketPeerUDP
var nick: String = ""
var session_id: int = 0
var net_id: int = 0
var reliable: ReliableChannel = ReliableChannel.new()
var last_recv_ms: int = 0
var last_rtt_ms: int = 0

# --- Input queue (server applies 1 per MovementSystem step) ---
var input_queue: Array = []                 # [{ seq, throttle, turn, brake }]
var last_applied_input_seq: int = 0

# --- Snapshot at acked_seq (что отправляем владельцу) ---
var acked_pos: Vector2 = Vector2.ZERO
var acked_rot: float = 0.0                  # в градусах (как C_Direction)
var acked_vel: Vector2 = Vector2.ZERO
var acked_initialized: bool = false

# AOI
var visible_net_ids: Dictionary = {}
var last_sent_state: Dictionary = {}
var reliable_outbox: Array = []

# Спавн
var needs_spawn: bool = false
var spawn_pos: Vector2 = Vector2.ZERO

func touch() -> void:
	last_recv_ms = Time.get_ticks_msec()

func is_timed_out(now_ms: int) -> bool:
	return (now_ms - last_recv_ms) > NetConfig.PEER_TIMEOUT_MS

func queue_reliable(msg_type: int, body: PackedByteArray) -> void:
	reliable_outbox.append({ "msg_type": msg_type, "body": body })
