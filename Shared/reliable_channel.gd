class_name ReliableChannel

var _next_seq: int = 1
var _pending: Dictionary = {}          # seq(int) -> { data: PackedByteArray, last_send_ms: int, retries: int }
var _received_seqs: Dictionary = {}    # seq(int) -> true

## Принимает msg_type и тело сообщения БЕЗ заголовка.
## Возвращает готовый пакет (header + seq + body) для немедленной отправки.
func enqueue(msg_type: int, body: PackedByteArray) -> PackedByteArray:
	var seq := _next_seq
	_next_seq = (_next_seq + 1) & 0xFFFF
	if _next_seq == 0:
		_next_seq = 1

	var buf := StreamPeerBuffer.new()
	buf.put_u8(msg_type)
	buf.put_u16(seq)
	buf.put_data(body)
	var packet := buf.data_array

	_pending[seq] = {
		"data": packet,
		"last_send_ms": Time.get_ticks_msec(),
		"retries": 0,
	}
	return packet

## Ретрансмит с таймаутом. Вызывается из NetworkSendSystem на каждом тике.
func tick(peer: PacketPeerUDP, now_ms: int) -> void:
	var to_remove: Array = []
	for seq in _pending.keys():
		var entry: Dictionary = _pending[seq]
		if now_ms - entry.last_send_ms < NetConfig.RELIABLE_TIMEOUT_MS:
			continue
		if entry.retries >= NetConfig.RELIABLE_MAX_RETRIES:
			to_remove.append(seq)
			NetLog.d("reliable", "give up seq=%d" % seq)
			continue
		entry.retries += 1
		entry.last_send_ms = now_ms
		peer.put_packet(entry.data)
		NetLog.d("reliable", "retransmit seq=%d attempt=%d" % [seq, entry.retries])
	for seq in to_remove:
		_pending.erase(seq)

func on_ack(seq: int) -> void:
	if _pending.erase(seq):
		NetLog.d("reliable", "acked seq=%d" % seq)

## Возвращает true, если сообщение новое (не дубликат). Окно дедупликации — 256.
func on_receive(seq: int, _raw: PackedByteArray) -> bool:
	if _received_seqs.has(seq):
		return false
	_received_seqs[seq] = true
	if _received_seqs.size() > 256:
		var keys: Array = _received_seqs.keys()
		keys.sort()
		_received_seqs.erase(keys[0])
	return true

func has_pending() -> bool:
	return not _pending.is_empty()
