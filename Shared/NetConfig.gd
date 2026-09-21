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
const AOI_RADIUS: float = 2500.0

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
const MAX_PACKETS_PER_PEER_PER_TICK: int = 10
const MAX_ENTITIES_PER_STATE_PACKET: int = 64
const MAX_RELIABLE_QUEUE: int = 256

# Логирование
const LOG_NETWORK_ARG: String = "--log-network"
