class_name NetConfig
# Транспорт
const SERVER_PORT: int = 9999
const SERVER_HOST: String = "127.0.0.1"   # для клиента
const PROTOCOL_VERSION: int = 1

# Тикрейты
const SERVER_TICK_RATE: int = 20
const CLIENT_INPUT_RATE: int = 30
const SERVER_TICK_DT: float = 1.0 / SERVER_TICK_RATE
const CLIENT_INPUT_DT: float = 1.0 / CLIENT_INPUT_RATE

# AOI
const AOI_RADIUS: float = 10000

# Надёжный канал
const RELIABLE_TIMEOUT_MS: int = 200
const RELIABLE_MAX_RETRIES: int = 5
const PEER_TIMEOUT_MS: int = 5000

# Квантование
const POS_SCALE: float = 1.0    # 1 px = 1 единица
const ROT_SCALE: float = 65535.0 / TAU
const VEL_SCALE: float = 1.0    # 1 px/s = 1 единица, clamp ±32767
const THROTTLE_SCALE: float = 127.0

# Лимиты
const MAX_PACKETS_PER_PEER_PER_TICK: int = 128
const MAX_ENTITIES_PER_STATE_PACKET: int = 64
const MAX_RELIABLE_QUEUE: int = 256
const MAX_INPUT_EVENTS_PER_PACKET: int = 8

# Один MSG_INPUT содержит последовательное окно
# самых старых unacked input frames.
#
# Даже при MAX_INPUT_EVENTS_PER_PACKET = 8
# шесть frames остаются ниже нашего MTU budget.
const MAX_INPUT_FRAMES_PER_PACKET: int = 6

# Пока очередь небольшая, simulation работает
# с обычной частотой 30 Hz.
#
# Если накопилось больше frames, сервер временно
# использует промежуточные physics frames для catch-up.
const INPUT_CATCHUP_QUEUE_THRESHOLD: int = 2

# AOI / приоритизация
const AOI_REFRESH_TICKS: int = 2           # пересчёт видимости раз в 2 серверных тика
const NEAR_RADIUS: float = 5000.0
const MID_RADIUS: float = 10000.0
const PROJECTILE_UPDATE_INTERVAL: int = 2  # снаряды шлём раз в 2 тика (10 Гц)

# Лимиты пакетов 
const MAX_STATE_PACKET_BYTES: int = 1100   # держим MSG_STATE < MTU 1200
const MAX_RELIABLE_PER_TICK: int = 16      # защита от всплесков MSG_FIRE
const MIN_STATE_PAYLOAD_BYTES: int = 20
const STATE_DEFER_MAX_TICKS: int = 2

# Границы карты (для квантования позиции в uint16)
const MAP_MIN := Vector2(-10000.0, -10000.0)
const MAP_MAX := Vector2( 10000.0,  10000.0)
const MAP_SIZE := Vector2(20000.0, 20000.0)  # MAP_MAX - MAP_MIN

# Логирование
const LOG_NETWORK_ARG: String = "--log-network"
