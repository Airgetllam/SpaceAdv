class_name NetProtocol
## Бинарный протокол SpaceAdv. Все числа little-endian (StreamPeerBuffer).
## Строки: uint16 length + utf8 bytes.

# --- Типы сообщений ---
const MSG_HELLO     := 1   # C→S reliable
const MSG_WELCOME   := 2   # S→C reliable
const MSG_INPUT     := 3   # C→S unreliable
const MSG_STATE     := 4   # S→C unreliable
const MSG_SPAWN     := 5   # S→C reliable
const MSG_DESPAWN   := 6   # S→C reliable
const MSG_BLOCK_HP  := 7   # S→C reliable (владельцу)
const MSG_FIRE      := 8   # S→C reliable
const MSG_PING      := 9   # C→S unreliable
const MSG_PONG      := 10  # S→C unreliable
const MSG_ACK       := 11  # C→S / S→C unreliable

# --- Заголовок ---
static func write_header(buf: StreamPeerBuffer, msg_type: int, seq: int) -> void:
	buf.put_u8(msg_type)
	buf.put_u16(seq)

static func read_header(buf: StreamPeerBuffer) -> Dictionary:
	return { "msg_type": buf.get_u8(), "seq": buf.get_u16() }

# --- Строки ---
static func write_string(buf: StreamPeerBuffer, s: String) -> void:
	var bytes := s.to_utf8_buffer()
	buf.put_u16(bytes.size())
	buf.put_data(bytes)

static func read_string(buf: StreamPeerBuffer) -> String:
	var n := buf.get_u16()
	var res := buf.get_data(n)
	if res[0] != OK: return ""
	return (res[1] as PackedByteArray).get_string_from_utf8()

# --- Квантование позиции (uint16 на ось) ---
static func quant_pos(p: Vector2, map_min: Vector2, map_max: Vector2) -> Vector2i:
	var nx := int(clamp((p.x - map_min.x) / (map_max.x - map_min.x), 0.0, 1.0) * 65535.0)
	var ny := int(clamp((p.y - map_min.y) / (map_max.y - map_min.y), 0.0, 1.0) * 65535.0)
	return Vector2i(nx, ny)

static func dequant_pos(q: Vector2i, map_min: Vector2, map_max: Vector2) -> Vector2:
	return Vector2(
		map_min.x + (float(q.x) / 65535.0) * (map_max.x - map_min.x),
		map_min.y + (float(q.y) / 65535.0) * (map_max.y - map_min.y)
	)

# --- Поворот (uint16 → 0..2π) ---
static func quant_rot(r: float) -> int:
	return int(fposmod(r, TAU) / TAU * 65535.0)

static func dequant_rot(q: int) -> float:
	return float(q) / 65535.0 * TAU

# --- Throttle/turn (int8 → -1..1) ---
static func quant_axis(v: float) -> int:
	return int(clamp(v, -1.0, 1.0) * 127.0) & 0xFF

static func dequant_axis(q: int) -> float:
	return float(q if q < 128 else q - 256) / 127.0
