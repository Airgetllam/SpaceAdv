# Документация проекта «space adventure 20 minutes in and out v0.0.4»

> Сгенерировано автоматически на основе анализа исходного кода проекта. Дата: 2026-08-30.

---

# 1. Общее описание проекта

## 1.1 Архитектура

Проект — прототип многопользовательской 2D космической игры с клиент-серверной архитектурой:

- **Сервер** (`res://Server/`) — авторитарная симуляция мира на базе ECS-фреймворка **GECS**. Сервер принимает ввод игроков по UDP, создаёт сущности-корабли из блоков, симулирует физику (RigidBody2D) и урон.
- **Клиент** (`res://Client/`) — тонкий клиент: UI-панель подключения, которая каждый кадр отправляет состояние ввода (тяга, поворот, тормоз, позиция курсора) на сервер по UDP в формате JSON.
- **Точка входа** (`res://boot.tscn` + `res://Server/Scripts/NoECSScripts/boot.gd`) — выбирает загружаемую сцену по аргументам командной строки.

## 1.2 Технологии

| Технология | Версия / детали |
|---|---|
| Godot | 4.7 (проект запущен в редакторе 4.7.2-stable), рендерер GL Compatibility |
| GECS (Godot Entity Component System) | **9.2.0** (аддон `res://addons/gecs/`, автозагрузка `ECS`) |
| Сеть | UDP (`UDPServer` / `PacketPeerUDP`), полезная нагрузка — JSON-строки |
| Физика | Встроенная 2D-физика Godot (`RigidBody2D`); для 3D в настройках указан Jolt Physics (не используется) |
| Рендеринг кораблей | `MultiMeshInstance2D` — по одному мультимешу на тип блока |


## 1.3 Основные принципы

1. **ECS (Entity–Component–System)**: данные лежат в компонентах (`Component`), логика — в системах (`System`), реакции на добавление/изменение компонентов — в наблюдателях (`Observer`).
2. **Событийная сборка корабля**: спавн игрока реализован как цепочка Observer'ов — добавление одного компонента порождает следующий (`C_SpawnPoint` → `C_Modules` → `C_Multimesh` → `C_Blocks` + `C_Collider`).
3. **Отложенные структурные изменения**: системы и наблюдатели меняют состав компонентов через `cmd` (CommandBuffer), чтобы не ломать итерацию по сущностям.
4. **Разделение циклов**: сетевые/визуальные системы работают в кадровом цикле (`_process`), физические — в группе `"physics"` (`_physics_process`).
5. **Data-driven контент**: блоки кораблей описываются ресурсами `BlockDefinition` (`.tres`), корабли — `ShipDefinition`.

## 1.4 Структура папок

```
res://
├── boot.tscn                      # главная сцена (точка входа)
├── project.godot
├── Client/
│   ├── Resources/all_blocks_test.tres   # тестовый ShipDefinition
│   ├── Scenes/UI/spawn.tscn             # UI подключения клиента
│   └── Scripts/UI/connect.gd            # логика клиента (UDP + ввод)
└── Server/
    ├── main.gd                    # инициализация ECS-мира сервера
    ├── ServerConfig.gd            # константы сервера
    ├── Resources/Blocks/*.tres    # определения блоков (BlockDefinition)
    ├── Scenes/server.tscn         # серверная сцена
    ├── Sprites/                   # текстуры блоков
    └── Scripts/
        ├── Components/            # ECS-компоненты (C_*)
        ├── Systems/               # ECS-системы (+ Systems/Admin/)
        ├── Observers/             # ECS-наблюдатели
        ├── Definitions/           # Resource-классы (BlockDefinition, ShipDefinition)
        └── NoECSScripts/boot.gd   # скрипт точки входа
```

---

# 2. Компоненты

Все компоненты лежат в `res://Server/Scripts/Components/` и наследуют `Component` (GECS). Компоненты — контейнеры данных; логика в них минимальна.

### res://Server/Scripts/Components/c_angularVelocity.gd (`C_AngularVelocity`)
**Назначение**: Целевая угловая скорость сущности (рад/с), которую физическая система применяет к RigidBody2D.
**Поля**:
- `value: float = 0.0` — угловая скорость.
**Методы**: явных нет.
**Взаимодействия**: пишется `ControlSystem`, читается `AngularVelocityApplySystem`; создаётся в `UserSpawnRequestObserver`.

### res://Server/Scripts/Components/c_blocks.gd (`C_Blocks`)
**Назначение**: Актуальная карта блоков корабля (состояние HP, индексы инстансов мультимеша и т.д.).
**Поля**:
- `blocks_map: Dictionary` — ключ: локальная позиция блока (`Vector2`), значение: словарь параметров блока (`block_index`, `block_id`, `block_hp`, `block_hp_max`, `energy`, `thrust`, `block_mass`, `destroy`, `mmi` — ссылка на `MultiMeshInstance2D`).
**Методы**:
- `_init(blocks: Dictionary) -> void` — принимает готовую карту блоков и сохраняет её в `blocks_map`.
**Взаимодействия**: создаётся `RenderInitObserver` (из `C_Multimesh.blocks_map`); читается/мутируется `DamageControlSystem` и `ParamsSyncSystem`.

### res://Server/Scripts/Components/c_collider.gd (`C_Collider`)
**Назначение**: Полигон коллизии корабля (внешний контур всех блоков).
**Поля**:
- `polygon: PackedVector2Array` — вершины полигона коллизии в локальных координатах.
**Методы**:
- `_init(_polygon: PackedVector2Array) -> void` — сохраняет переданный полигон.
**Взаимодействия**: создаётся `RenderInitObserver` (контур вычисляется из блоков); при добавлении обрабатывается `ColliderCreationObserver`, который создаёт `CollisionPolygon2D` на `C_RigidBody.node`.

### res://Server/Scripts/Components/c_controlInput.gd (`C_ControlInput`)
**Назначение**: Последний полученный от клиента ввод управления кораблём.
**Поля**:
- `throttle: float` — тяга, диапазон −1..1.
- `turn: float` — поворот, диапазон −1..1.
- `brake: bool` — флаг инерционного тормоза.
**Методы**: явных нет.
**Взаимодействия**: заполняется `NetworkControlSystem` из UDP-пакетов; читается `ControlSystem`; создаётся `UserSpawnRequestObserver`.

### res://Server/Scripts/Components/c_damagedBlock.gd (`C_DamagedBlock`)
**Назначение**: «Событие»-компонент: заявка на нанесение урона по конкретным блокам корабля. Одноразовый — удаляется после обработки.
**Поля**:
- `block_pos: Array[Vector2]` — локальные позиции повреждённых блоков (ключи `C_Blocks.blocks_map`).
- `value: int` — величина урона.
**Методы**: явных нет.
**Взаимодействия**: потребляется и удаляется `DamageControlSystem`; в текущем коде никто его не добавляет (предполагается будущая боевая система).

### res://Server/Scripts/Components/c_force.gd (`C_Force`)
**Назначение**: Текущая накопленная сила тяги двигателя (скаляр, направление берётся из ориентации корабля).
**Поля**:
- `value: float = 0` — величина тяги (ограничивается ±100 в `ControlSystem`).
**Методы**: явных нет.
**Взаимодействия**: пишется `ControlSystem`, читается `ForceApplySystem`; создаётся `UserSpawnRequestObserver`.

### res://Server/Scripts/Components/c_modules.gd (`C_Modules`)
**Назначение**: Описание состава корабля: список модулей с блоками, доступные определения блоков и их текстуры. Служит «исходником» для генерации мультимешей.
**Поля**:
- `list: Array[Dictionary]` — данные модулей корабля (из `ShipDefinition.modules_data`).
- `available_blocks: Array[BlockDefinition] = []` — все загруженные определения блоков.
- `blocks_textures: Dictionary = {}` — карта `block_id → Texture2D`.
**Методы**:
- `_init() -> void` — (помечен как временный) загружает все определения блоков, строит карту текстур и берёт тестовый корабль из `res://Client/Resources/all_blocks_test.tres` (поле `modules_data`).
- `_load_blocks()` — сканирует каталог `ServerConfig.BLOCK_PATH` (`res://Server/Resources/Blocks/`), загружает все `.tres` в `available_blocks`. Параметров и возвращаемого значения нет.
- `_define_textures(blocks: Array[BlockDefinition]) -> Dictionary` — строит и возвращает словарь `id → texture` по списку определений блоков.
**Взаимодействия**: создаётся `UserSpawnRequestObserver`; при добавлении обрабатывается `MultimeshCreationObserver`. Зависит от `ServerConfig` и ресурсов `BlockDefinition`/`ShipDefinition`.

### res://Server/Scripts/Components/c_multimesh.gd (`C_Multimesh`)
**Назначение**: Сгенерированные визуальные данные корабля: мультимеши по типам блоков и карта блоков.
**Поля**:
- `multlimesh: Dictionary` — (опечатка в имени сохранена как в коде) карта `имя (block_id) → MultiMeshInstance2D`.
- `blocks_map: Dictionary` — карта параметров блоков (та же структура, что в `C_Blocks`).
- `all_blocks: Array` — плоский список всех блоков корабля (словари с `block_id`, `local_pos`).
**Методы**: явных нет.
**Взаимодействия**: создаётся `MultimeshCreationObserver`; при добавлении обрабатывается `RenderInitObserver` (добавляет меши в дерево сцены, порождает `C_Blocks` и `C_Collider`).

### res://Server/Scripts/Components/c_peerID.gd (`C_PeerID`)
**Назначение**: Идентификатор сетевого пира, которому принадлежит сущность-игрок.
**Поля**:
- `value: int = 0` — хэш от IP+порт пира.
**Методы**: явных нет.
**Взаимодействия**: создаётся `NetworkPeerRegistrationSystem`; используется как маркер «игрока» в запросах `ControlSystem` и `UserSpawnRequestObserver`.

### res://Server/Scripts/Components/c_position.gd (`C_Position`)
**Назначение**: Позиция сущности в мировых координатах. Сеттер эмитит сигнал изменения — на этом построена реактивная синхронизация с физическим телом.
**Поля**:
- `value: Vector2 = Vector2.ZERO` — позиция; кастомный `set` при реальном изменении эмитит `property_changed.emit(self, 'value', old_value, new_value)`.
**Методы**:
- `_init(pos: Vector2 = Vector2.ZERO) -> void` — инициализирует позицию переданным значением.
**Взаимодействия**: пишется `PositionSyncSystem` (из физики) и `SpawnPositionSyncObserver` (из точки спавна); изменение `value` ловит `PositionToRigidbodyObserver` (`on_changed`) и телепортирует RigidBody2D.

### res://Server/Scripts/Components/c_rigidbody.gd (`C_RigidBody`)
**Назначение**: Ссылка на физическое тело `RigidBody2D`, представляющее сущность в мире Godot.
**Поля**:
- `node: RigidBody2D = null` — узел тела (не `@export`, обычная переменная).
**Методы**:
- `_init(_node: RigidBody2D = null) -> void` — сохраняет ссылку на узел.
**Взаимодействия**: создаётся `UserSpawnRequestObserver`; используется почти всеми физическими системами (`ForceApplySystem`, `AngularVelocityApplySystem`, `PositionSyncSystem`, `ControlSystem`) и наблюдателями (`ColliderCreationObserver`, `RenderInitObserver`, `PositionToRigidbodyObserver`).

### res://Server/Scripts/Components/c_serverIP.gd (`C_ServerIP`)
**Назначение**: Серверный «singleton»-компонент: держит UDP-сервер и список подключённых пиров.
**Поля**:
- `UDP_connection: Array` — массив с одним элементом `UDPServer` (обёртка нужна, т.к. `@export` не сериализует объект напрямую).
- `peers: Dictionary` — ключ: `PacketPeerUDP`, значение: ник (String).
**Методы**:
- `_init() -> void` — создаёт `UDPServer`, начинает слушать порт **9999**, кладёт сервер в `UDP_connection`.
- `add_peer(peer: PacketPeerUDP, nick: String) -> void` — регистрирует пира в `peers` и эмитит `property_changed` (для потенциальных наблюдателей).
**Взаимодействия**: создаётся в `Server.main.gd` на сущности `server`; читается `NetworkControlSystem`, `NetworkPeerRegistrationSystem`, `AdminCursorSyncSystem`.

### res://Server/Scripts/Components/c_spawnPoint.gd (`C_SpawnPoint`)
**Назначение**: «Событие»-компонент: точка, где нужно заспавнить сущность. Удаляется после применения.
**Поля**:
- `value: Vector2 = Vector2.ZERO` — координаты спавна.
**Методы**: явных нет.
**Взаимодействия**: добавляется `NetworkPeerRegistrationSystem`; триггерит `UserSpawnRequestObserver` (вместе с `C_PeerID`) и `SpawnPositionSyncObserver` (который копирует значение в `C_Position` и удаляет компонент).

### res://Server/Scripts/Components/c_stateChanged.gd (`C_StateChanged`)
**Назначение**: «Событие»-компонент: список блоков, чьё состояние (HP) изменилось и требует визуального обновления.
**Поля**:
- `list: Array` — локальные позиции изменённых блоков.
**Методы**:
- `_init(_list: Array) -> void` — сохраняет список изменённых блоков.
**Взаимодействия**: добавляется `DamageControlSystem`; читается `ParamsSyncSystem` (перекраска мультимеша). В коде есть TODO: компонент нигде не удаляется после обработки.

### res://Server/Scripts/Components/c_target.gd (`C_Target`)
**Назначение**: Компонент-отношение (Relationship): маркирует, что сущность «целится» в другую сущность (используется как ключ отношения, а не как обычный компонент).
**Поля**:
- `state: int` — состояние цели (семантика значений в коде не определена).
**Методы**:
- `set_state(_state)` — записывает состояние. Параметр: `_state` (нетипизированный). Ничего не возвращает.
- `get_state() -> int` — возвращает текущее состояние.
**Взаимодействия**: используется `CursorInteractionSystem` внутри `Relationship.new(C_Target.new(), target_entity)`.

### res://Server/Scripts/Components/с_сursorPosition.gd (`C_CursorPosition`)
**Назначение**: Позиция курсора (мировая) владельца сущности — игрока или администратора сервера.
**Поля**:
- `position: Vector2 = Vector2.ZERO` — позиция курсора.
**Методы**: явных нет.
**Взаимодействия**: пишется `NetworkControlSystem` (курсор клиента из JSON) и `AdminCursorSyncSystem` (курсор мыши на сервере); читается `CursorInteractionSystem`.

---

# 3. Системы

Все системы лежат в `res://Server/Scripts/Systems/`, наследуют `System` (GECS) и регистрируются в `res://Server/main.gd`. Системы без группы работают в кадровом цикле (`ECS.process(delta)` из `_process`); системы группы `"physics"` — в `ECS.process(delta, "physics")` из `_physics_process`.

| Система | Группа | Цикл |
|---|---|---|
| NetworkControlSystem | (по умолчанию) | `_process` |
| NetworkPeerRegistrationSystem | (по умолчанию) | `_process` |
| AdminCursorSyncSystem | `"admin"` | **не вызывается** (см. примечание) |
| CursorInteractionSystem | (по умолчанию) | `_process` |
| PositionSyncSystem | (по умолчанию) | `_process` |
| ControlSystem | `"physics"` | `_physics_process` |
| ForceApplySystem | `"physics"` | `_physics_process` |
| AngularVelocityApplySystem | `"physics"` | `_physics_process` |
| DamageControlSystem | (по умолчанию) | `_process` |
| ParamsSyncSystem | (по умолчанию) | `_process` |

### res://Server/Scripts/Systems/NetworkControlSystem.gd (`NetworkControlSystem`)
**Назначение**: Сетевой приём: принимает новые UDP-подключения и парсит входящие пакеты ввода от подключённых клиентов.
**Запрос**: `q.with_all([C_ServerIP])` — серверная сущность.
**Методы**:
- `query() -> QueryBuilder` — возвращает запрос по `C_ServerIP`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — для серверной сущности: (1) `poll()` UDP-сервера; при доступном подключении принимает пира, эхо-отвечает первым пакетом и регистрирует через `C_ServerIP.add_peer(peer, 'test')`; (2) для каждого пира читает до 10 пакетов за кадр (константа `MAX_PACKETS`), парсит JSON и, если у пира есть мета `"entity"`, обновляет `C_ControlInput` (`throttle`, `turn`, `brake` с clamp) и `C_CursorPosition` (парсит строку `"(x, y)"` в `Vector2`).
**Цикл**: `_process` (группа по умолчанию).
**Взаимодействия**: наполняет данные для `ControlSystem` и `CursorInteractionSystem`; полагается на мету `"entity"`, которую ставит `NetworkPeerRegistrationSystem`.
**Особенности**: жёстко зашитый лимит 10 пакетов/пир/кадр; ник пира всегда `'test'`.

### res://Server/Scripts/Systems/NetworkPeerRegistrationSystem.gd (`NetworkPeerRegistrationSystem`)
**Назначение**: Создаёт сущность-игрока для каждого нового пира, у которого её ещё нет.
**Запрос**: `q.with_all([C_ServerIP])`.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_ServerIP`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — для каждого пира без меты `"entity"`: создаёт `Entity` с именем `Player_<ip>_<ник>`, добавляет `C_PeerID` (значение из `_generate_peer_id`) и `C_SpawnPoint`, добавляет сущность в мир и записывает её в мету пира.
- `_generate_peer_id(peer: PacketPeerUDP) -> int` — возвращает `hash(ip + str(port))` — уникальный ID пира.
**Цикл**: `_process`.
**Взаимодействия**: добавление `C_PeerID` + `C_SpawnPoint` триггерит `UserSpawnRequestObserver` (цепочка спавна корабля); мета `"entity"` используется `NetworkControlSystem`.

### res://Server/Scripts/Systems/Admin/AdminCursorSyncSystem.gd (`AdminCursorSyncSystem`)
**Назначение**: Синхронизирует `C_CursorPosition` серверной сущности с позицией мыши в окне сервера (курсор администратора).
**Запрос**: `q.with_all([C_ServerIP])`.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_ServerIP`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — берёт глобальную позицию мыши через `get_viewport().get_camera_2d()` и записывает её в `C_CursorPosition` серверной сущности. Локальная переменная `pos` (`C_Position`) получается, но не используется.
**Цикл / зависимости**: назначена в группу `"admin"` (`main.gd`), **но `ECS.process(delta, "admin")` нигде не вызывается — система в текущем коде фактически не исполняется**. Также нет обработки аргумента `--admin`. Судя по всему, это задел на будущий «режим администратора».
**Взаимодействия**: при включении группы давала бы данные `CursorInteractionSystem` для серверной сущности.

### res://Server/Scripts/Systems/CursorInteractionSystem.gd (`CursorInteractionSystem`)
**Назначение**: Определяет, на какую сущность наведён курсор (игрока или админа), и поддерживает Relationship `C_Target` «сущность → цель».
**Запрос**: `q.with_all([C_CursorPosition])`.
**Поля**:
- `current_targets: Dictionary` — кэш текущей цели для каждой сущности (ключ: Entity, значение: Entity-цель или null).
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_CursorPosition`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — через `direct_space_state.intersect_point()` мира 2D находит физическое тело под курсором; извлекает сущность из меты `"entity"` коллайдера (исключая самонаведение); при смене цели удаляет старое отношение `cmd.remove_relationship(...)` и добавляет новое `cmd.add_relationship(entity, Relationship.new(C_Target.new(), new_target))`, обновляя `current_targets`.
**Цикл**: `_process`.
**Взаимодействия**: использует мету `"entity"` на RigidBody2D (ставится `UserSpawnRequestObserver`); данные курсора поступают из `NetworkControlSystem` / `AdminCursorSyncSystem`. Потребителей отношения `C_Target` в текущем коде нет (задел на систему прицеливания/стрельбы).

### res://Server/Scripts/Systems/PositionSyncSystem.gd (`PositionSyncSystem`)
**Назначение**: Копирует фактическую позицию физического тела в `C_Position` (физика → ECS-данные).
**Запрос**: `q.with_all([C_Position, C_RigidBody])`.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_Position` + `C_RigidBody`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — `pos.value = body.node.global_position` для каждой сущности.
**Цикл**: `_process`.
**Взаимодействия**: запись в `C_Position.value` через сеттер эмитит `property_changed`, что триггерит `PositionToRigidbodyObserver` (тот пишет позицию обратно в тело — при синхронизации из физики значения совпадают, реальная телепортация происходит только при внешнем изменении `C_Position`, например из `SpawnPositionSyncObserver`).

### res://Server/Scripts/Systems/ControlSystem.gd (`ControlSystem`)
**Назначение**: Преобразует ввод игрока (`C_ControlInput`) в физические намерения: наращивает/уменьшает тягу (`C_Force`), задаёт угловую скорость (`C_AngularVelocity`), управляет тормозом (linear_damp).
**Запрос**: `q.with_all([C_PeerID])` — все сущности-игроки. ⚠️ Запрос не включает `C_Force`/`C_RigidBody`/`C_ControlInput`, компоненты берутся напрямую; до срабатывания `UserSpawnRequestObserver` они могут отсутствовать.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_PeerID`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — константы: `THROTTLE_INCREASE_SPEED = 0.01`, `THROTTLE_DECREASE_SPEED = 0.01`, `MAX_THROTTLE = 100`, `TURN_SPEED = 2.5`. Для каждой сущности: наращивает `force.value` пропорционально `delta / speed * throttle` с clamp в ±100; задаёт `angular_velocity.value = turn * TURN_SPEED`; при `brake` включает `linear_damp = 1.0` и обнуляет тягу, иначе `linear_damp = 0.0`.
**Цикл**: группа `"physics"` → `_physics_process`.
**Взаимодействия**: вход — `NetworkControlSystem` (`C_ControlInput`); выход — `ForceApplySystem` (`C_Force`) и `AngularVelocityApplySystem` (`C_AngularVelocity`).

### res://Server/Scripts/Systems/ForceApplySystem.gd (`ForceApplySystem`)
**Назначение**: Применяет тягу к физическому телу в направлении «носа» корабля.
**Запрос**: `q.with_all([C_RigidBody, C_Force])`.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_RigidBody` + `C_Force`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — вычисляет направление `Vector2.UP.rotated(body.node.global_rotation)` и вызывает `body.node.apply_central_force(direction * force.value)`.
**Цикл**: группа `"physics"` → `_physics_process`.
**Взаимодействия**: потребляет `C_Force`, обновляемый `ControlSystem`.

### res://Server/Scripts/Systems/AngularVelocityApplySystem.gd (`AngularVelocityApplySystem`)
**Назначение**: Записывает целевую угловую скорость из компонента прямо в RigidBody2D.
**Запрос**: `q.with_all([C_RigidBody, C_AngularVelocity])`.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_RigidBody` + `C_AngularVelocity`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — `body.node.angular_velocity = angular_velocity.value`.
**Цикл**: группа `"physics"` → `_physics_process`.
**Взаимодействия**: потребляет `C_AngularVelocity`, обновляемый `ControlSystem`.

### res://Server/Scripts/Systems/DamageControlSystem.gd (`DamageControlSystem`)
**Назначение**: Применяет урон к блокам корабля: уменьшает HP, помечает уничтоженные блоки, инициирует визуальное обновление.
**Запрос**: `q.with_all([C_Blocks, C_DamagedBlock])`.
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_Blocks` + `C_DamagedBlock`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — для каждой позиции из `C_DamagedBlock.block_pos` уменьшает `block_hp` в `C_Blocks.blocks_map` на `value`; при `block_hp <= 0` ставит `destroy = true` и HP = 0. Затем через CommandBuffer добавляет `C_StateChanged` (со списком позиций) и удаляет `C_DamagedBlock`.
**Цикл**: `_process`.
**Взаимодействия**: выход — `ParamsSyncSystem` (через `C_StateChanged`). В коде TODO: обработку `C_StateChanged` планируется вынести в отдельную систему.

### res://Server/Scripts/Systems/ParamsSyncSystem.gd (`ParamsSyncSystem`)
**Назначение**: Визуальная синхронизация состояния блоков: перекрашивает инстансы мультимеша в цвет, соответствующий проценту HP.
**Запрос**: `q.with_all([C_StateChanged, C_Blocks])`.
**Поля**:
- `hp_colors: Dictionary = ServerConfig.HP_COLORS` — палитра «процент HP → Color».
**Методы**:
- `query() -> QueryBuilder` — запрос по `C_StateChanged` + `C_Blocks`.
- `process(entities: Array[Entity], _components: Array, delta: float) -> void` — для каждой позиции из `C_StateChanged.list` берёт блок из `blocks_map`, вычисляет процент HP и вызывает `block.mmi.multimesh.set_instance_color(block.block_index, color)`.
- `_get_hp_percent(value: int, _max: int) -> int` — возвращает процент HP, округлённый к ближайшему десятку и ограниченный 0..100.
**Цикл**: `_process`.
**Взаимодействия**: вход — `DamageControlSystem` (`C_StateChanged`); работает с `MultiMeshInstance2D`, созданным `MultimeshCreationObserver`.
**Особенности**: `C_StateChanged` не удаляется после обработки — перекраска повторяется каждый кадр (известный TODO).

---

# 4. Наблюдатели (Observers)

Наблюдатели лежат в `res://Server/Scripts/Observers/`, наследуют `Observer` (GECS) и реагируют на добавление (`on_added`) или изменение (`on_changed`) компонентов. Регистрируются в `main.gd` через `_world.add_observers(...)`. Через них построена вся цепочка спавна корабля.

### res://Server/Scripts/Observers/user_spawn_request_observer.gd (`UserSpawnRequestObserver`)
**Назначение**: Стартует спавн корабля игрока: создаёт RigidBody2D и навешивает базовый набор компонентов.
**Запрос**: `q.with_all([C_PeerID, C_SpawnPoint]).on_added()`.
**Методы**:
- `query() -> QueryBuilder` — реагирует на появление пары `C_PeerID` + `C_SpawnPoint`.
- `each(event: Variant, entity: Entity, payload: Variant = null) -> void` — создаёт `RigidBody2D` (`gravity_scale = 0`, `can_sleep = false`, `linear_damp_mode = DAMP_MODE_REPLACE`, позиция из `C_SpawnPoint`), ставит мету `"entity"` на тело, и через `cmd.add_components` добавляет: `C_RigidBody`, `C_Position`, `C_Force`, `C_AngularVelocity`, `C_ControlInput`, `C_CursorPosition`, `C_Modules`.
**Взаимодействия**: триггерится `NetworkPeerRegistrationSystem`; добавление `C_Modules` запускает `MultimeshCreationObserver`; мета `"entity"` используется `NetworkControlSystem` и `CursorInteractionSystem`.

### res://Server/Scripts/Observers/spawn_position_sync_observer.gd (`SpawnPositionSyncObserver`)
**Назначение**: Переносит точку спавна в `C_Position` и удаляет одноразовый `C_SpawnPoint`.
**Запрос**: `q.with_all([C_SpawnPoint]).on_added()`.
**Методы**:
- `query() -> QueryBuilder` — реагирует на добавление `C_SpawnPoint`.
- `each(event: Variant, entity: Entity, payload: Variant = null) -> void` — `pos.value = spawn_pos.value` (что через сеттер `C_Position` триггерит `PositionToRigidbodyObserver`), затем `cmd.remove_component(entity, C_SpawnPoint)`.

### res://Server/Scripts/Observers/multimesh_creation_observer.gd (`MultimeshCreationObserver`)
**Назначение**: Из описания модулей (`C_Modules`) строит мультимеши по типам блоков и карту блоков, добавляет `C_Multimesh`.
**Поля**:
- `blocks_map: Dictionary = {}` — накапливаемая карта блоков (обнуляется на каждый вызов `each`).
- `cell_size: int = ServerConfig.CELL_SIZE` — размер ячейки (64 px).
- `hp_colors: Dictionary = ServerConfig.HP_COLORS` — палитра HP.
**Запрос**: `q.with_all([C_Modules]).on_added()`.
**Методы**:
- `query() -> QueryBuilder` — реагирует на добавление `C_Modules`.
- `each(event: Variant, entity: Entity, payload: Variant = null) -> void` — собирает все блоки всех модулей в плоский список, конвертирует `local_pos` в `Vector2`, центрирует блоки относительно геометрического центра bounding box, группирует по `block_id`, для каждой группы создаёт `MultiMeshInstance2D` (`_create_multimesh`), заполняет `C_Multimesh` (`multlimesh`, `blocks_map`, `all_blocks`) и добавляет его через `cmd.add_component`.
- `_group_blocks_by_id(blocks: Array) -> Dictionary` — возвращает словарь `block_id → Array[Vector2]` (позиции блоков этого типа).
- `_create_multimesh(blocks: Array, texture: String, available_blocks: Array[BlockDefinition], blocks_textures: Dictionary) -> MultiMeshInstance2D` — создаёт `MultiMesh` (TRANSFORM_2D, use_colors) с квадом `cell_size × cell_size` (два треугольника + UV), расставляет инстансы по позициям блоков, красит в цвет 100% HP, находит статы блока в `available_blocks` по `id == texture` и заполняет `blocks_map` записями (`block_index`, `block_id`, `block_hp`, `block_hp_max`, `energy`, `thrust`, `block_mass`, `destroy`, `mmi`). Возвращает готовый `MultiMeshInstance2D` с назначенной текстурой.
- `_get_center_position(blocks: Array) -> Vector2` — среднее арифметическое позиций блоков (в текущем коде не вызывается; центрирование делается по bounding box прямо в `each`).
**Взаимодействия**: вход — `UserSpawnRequestObserver` (`C_Modules`); выход — `RenderInitObserver` (`C_Multimesh`). Зависит от `ServerConfig` и `BlockDefinition`.

### res://Server/Scripts/Observers/render_init_observer.gd (`RenderInitObserver`)
**Назначение**: Финализация спавна: добавляет мультимеши в тело корабля, тело — в дерево сцены (`World/Ships`), порождает `C_Blocks` и `C_Collider`.
**Запрос**: `q.with_all([C_Multimesh]).on_added()`.
**Методы**:
- `query() -> QueryBuilder` — реагирует на добавление `C_Multimesh`.
- `each(event: Variant, entity: Entity, payload: Variant = null) -> void` — вычисляет полигон контура (`_get_outline_points` + `_remove_collinear_points`), добавляет все `MultiMeshInstance2D` детьми в `C_RigidBody.node`, добавляет тело в узел `World/Ships` текущей сцены, затем `cmd.add_component(C_Blocks)` и `cmd.add_component(C_Collider)`.
- `_get_outline_points(all_blocks: Array) -> Array[Vector2]` — по занятым ячейкам строит словарь направленных граничных рёбер (рёбра между занятой и пустой ячейками), находит стартовую точку (мин. x, затем y) и обходит контур по цепочке рёбер. Возвращает вершины контура, умноженные на `CELL_SIZE`.
- `_remove_collinear_points(points: Array[Vector2]) -> Array[Vector2]` — удаляет коллинеарные промежуточные вершины (с учётом замкнутости полигона), возвращает упрощённый полигон.
- `_is_collinear(a: Vector2, b: Vector2, c: Vector2) -> bool` — проверка коллинеарности трёх точек через векторное произведение (== 0).
**Взаимодействия**: вход — `MultimeshCreationObserver`; выход — `ColliderCreationObserver` (`C_Collider`), `DamageControlSystem`/`ParamsSyncSystem` (`C_Blocks`). Зависит от структуры сцены `server.tscn` (узел `World/Ships`).

### res://Server/Scripts/Observers/collider_creation_observer.gd (`ColliderCreationObserver`)
**Назначение**: При появлении `C_Collider` создаёт узел `CollisionPolygon2D` и добавляет его к физическому телу.
**Запрос**: `q.with_all([C_Collider]).on_added()`.
**Методы**:
- `query() -> QueryBuilder` — реагирует на добавление `C_Collider`.
- `each(event: Variant, entity: Entity, payload: Variant = null) -> void` — создаёт `CollisionPolygon2D`, присваивает `polygon` из компонента и добавляет ребёнком в `C_RigidBody.node`.
**Взаимодействия**: вход — `RenderInitObserver`; результат используется физикой и `CursorInteractionSystem` (intersect_point).

### res://Server/Scripts/Observers/position_to_rigidbody_observer.gd (`PositionToRigidbodyObserver`)
**Назначение**: Реактивная телепортация: при изменении `C_Position.value` перемещает физическое тело в новую позицию.
**Запрос**: `q.with_all([C_Position, C_RigidBody]).on_changed([&"value"])`.
**Методы**:
- `query() -> QueryBuilder` — реагирует на изменение свойства `value` компонента `C_Position` (сигнал `property_changed` из сеттера).
- `each(event: Variant, entity: Entity, payload: Variant = null) -> void` — при `event == Observer.Event.CHANGED` пишет `payload.new_value` в `body.node.global_position` (payload содержит `component`, `property`, `old_value`, `new_value`).
**Взаимодействия**: триггерится `SpawnPositionSyncObserver` (спавн) и `PositionSyncSystem` (каждый кадр, но со значением, равным текущему — сеттер `C_Position` эмитит сигнал только при реальном изменении).

---

# 5. Определения ресурсов (Definitions)

### res://Server/Scripts/Definitions/BlockDefinition.gd (`BlockDefinition`, extends Resource)
**Назначение**: Описание типа блока корабля (data-driven ресурс `.tres`).
**Поля**:
- `id: String` — уникальный идентификатор блока (в текущих ресурсах — числовые строки: `"0"`…`"5"`).
- `display_name: String` — отображаемое имя.
- `texture: Texture2D` — текстура блока.
- `category: String` — категория (оружие, броня, двигатель и т.д.).
- `stats: Dictionary` — статы: `hp`, `mass`, `armor`, `energy_cost` (и опционально `thrust`).
**Методы** (все — геттеры по ключам `stats` со значениями по умолчанию):
- `get_hp() -> int` — HP блока.
- `get_armor() -> float` — броня.
- `get_mass() -> float` — масса.
- `get_energy_cost() -> float` — потребление энергии.
- `get_thrust() -> int` — тяга.

Ресурсы блоков: `res://Server/Resources/Blocks/` — `ammo.tres`, `armor.tres`, `barrel.tres`, `breech.tres`, `engine.tres`, `reactor.tres`. Текстуры: `res://Server/Sprites/`.

### res://Server/Scripts/Definitions/ShipDefinition.gd (`ShipDefinition`, extends Resource)
**Назначение**: Описание корабля как набора модулей из блоков.
**Поля**:
- `ship_name: String` — имя корабля.
- `modules_data: Array[Dictionary]` — модули; каждый словарь: `"name": String`, `"blocks_data": Array[Dictionary]` (`"block_id": int`, `"local_pos": Vector2i`).
- `size: int` — количество блоков корабля.

Тестовый корабль: `res://Client/Resources/all_blocks_test.tres` (загружается в `C_Modules._init()`).

### res://Server/ServerConfig.gd (`ServerConfig`)
**Назначение**: Глобальные константы сервера (класс без наследования, используется статически).
**Константы**:
- `CELL_SIZE: int = 64` — размер ячейки блока в пикселях.
- `BLOCK_PATH: String = 'res://Server/Resources/Blocks/'` — путь к ресурсам блоков.
- `HP_COLORS: Dictionary` — палитра «процент HP (0–100 с шагом 10) → Color» (от зелёного к красному; 0% — прозрачный белый, т.е. блок визуально исчезает).

---

# 6. Сетевой слой

## 6.1 Транспорт и протокол

- **Транспорт**: чистый **UDP**. Сервер — `UDPServer` (создаётся в `C_ServerIP._init()`, порт **9999**); клиент — `PacketPeerUDP.connect_to_host("127.0.0.1", 9999)`.
- **WebSocket / высокоуровневый RPC Godot (MultiplayerAPI) не используются.**
- **Формат данных**: JSON-строка в UTF-8 в каждом UDP-пакете.

## 6.2 Пакет ввода клиента (клиент → сервер, каждый кадр)

```json
{
  "throttle": -1.0..1.0,     // ось тяги (thrust_down / thrust_up)
  "turn": -1.0..1.0,         // ось поворота (rotate_minus / rotate_plus)
  "brake": true|false,       // inertia_break (Space)
  "cursor_pos": "(x, y)"     // Vector2, сериализованный строкой через str()
}
```

Сервер парсит `cursor_pos` вручную: срезает скобки и делит по запятой (`NetworkControlSystem`, строки 47–53).

## 6.3 Жизненный цикл подключения

1. Клиент жмёт «Connect» → `udp.connect_to_host("127.0.0.1", 9999)` и начинает слать пакеты ввода каждый кадр (`connect.gd`).
2. `NetworkControlSystem` (сервер): `UDPServer.poll()` → `take_connection()` → эхо-ответ первым пакетом → `C_ServerIP.add_peer(peer, 'test')`.
3. `NetworkPeerRegistrationSystem`: для пира без меты `"entity"` создаёт сущность-игрока с `C_PeerID` + `C_SpawnPoint(200, 200)` и записывает её в мету пира.
4. Цепочка Observer'ов собирает корабль (см. раздел 9).
5. Далее каждый кадр `NetworkControlSystem` читает до 10 пакетов на пира и обновляет `C_ControlInput` / `C_CursorPosition` его сущности.

## 6.4 Ограничения текущей реализации

- Синхронизация **сервер → клиент отсутствует** (клиент ничего не рендерит из мира; приём пакетов на клиенте закомментирован).
- Нет отключения/таймаутов пиров, нет проверки ников (всегда `'test'`), адрес сервера захардкожен `127.0.0.1`.
- Нет защиты от подделки пакетов и валидации схемы JSON (только clamp значений).

---

# 7. UI

### res://Client/Scenes/UI/spawn.tscn + res://Client/Scripts/UI/connect.gd
**Назначение**: Клиентская панель подключения и одновременно панель ввода.
**Структура сцены**: `Spawn (Control)` → `VBoxContainer` → поля: ник (`LineEdit`), позиция X/Y (`LineEdit` × 2), кнопка Connect (`Button`), статус (`Label`), индикатор ввода (`StatusLabel`).
**Методы скрипта**:
- `_ready()` — подключает сигнал `pressed` кнопки к `_on_connect_pressed`.
- `_process(delta: float) -> void` — каждый кадр: читает оси ввода (`thrust_down`/`thrust_up`, `rotate_minus`/`rotate_plus`), тормоз (`inertia_break`), позицию мыши (через Camera2D, если есть); обновляет текст `input_label`; если `connected` — сериализует ввод в JSON и шлёт UDP-пакет. Приём входящих пакетов присутствует, но тело обработчика закомментировано.
- `_on_connect_pressed()` — подключается к `127.0.0.1:9999`, ставит `connected = true`, блокирует кнопку; проверяет непустой ник (проверка выполняется **после** подключения — фактически подключение происходит при любом нике).
- `_on_connected_to_server()` — задел на будущее: должен грузить `res://Client/Scenes/UI/control.tscn` и читать ник/позицию. **Нигде не вызывается**, а сцена `control.tscn` в проекте отсутствует.
**Прочее**: в конце файла — закомментированный черновик `ClientNode` (тестовый UDP-клиент).

**Панель администратора**: отдельной UI-сцены администратора в проекте **нет**. «Административная» функциональность ограничена системой `AdminCursorSyncSystem` (группа `"admin"`, в данный момент не исполняется) — курсор мыши в окне сервера.

**Серверная сцена** `res://Server/Scenes/server.tscn`: `Server (Node2D)` с `main.gd`; дети: `World` (GECS World; внутри `Ships` — контейнер для тел кораблей и `Camera2D`), спрайты-плейсхолдеры (`CianPlaceholder`, `GrayPlaceholder`, `LightgrayPlaceholder`) и тестовый `RigidBody2D` с `CollisionShape2D`.

---

# 8. Сценарии запуска

### res://boot.tscn + res://Server/Scripts/NoECSScripts/boot.gd
**Назначение**: Главная сцена проекта (main_scene в `project.godot`). Выбирает режим по аргументам командной строки.
**Методы**:
- `_ready()` — читает `OS.get_cmdline_args()`; при `--server` целевая сцена — `res://Server/Scenes/server.tscn`, иначе (в т.ч. при `--client` или без аргументов) — `res://Client/Scenes/UI/spawn.tscn`. Загрузка откладывается через `call_deferred`.
- `_deferred_load_scene(path: String)` — загружает `PackedScene` и делает `change_scene_to_packed`; при ошибке печатает сообщение.

**Аргументы командной строки**:

| Аргумент | Эффект |
|---|---|
| `--server` | Загружается серверная сцена `server.tscn` (ECS-мир, UDP-сервер на 9999). |
| `--client` | Считывается в переменную `is_client`, но **не влияет на выбор сцены** — клиентская сцена и так является сценой по умолчанию. |
| `--admin` | **Не обрабатывается в коде вообще.** Группа систем `"admin"` существует, но нигде не запускается. |
| (без аргументов) | Загружается клиентская сцена `spawn.tscn`. |

Пример запуска:
```
godot --path <project> -- --server
godot --path <project> -- --client
```

### res://Server/main.gd (`Server`)
**Назначение**: Корневой скрипт серверной сцены: инициализирует GECS-мир, регистрирует системы/наблюдателей, создаёт серверную сущность и гоняет циклы обработки.
**Методы**:
- `_ready() -> void` — присваивает `ECS.world = $World`; создаёт 10 систем (словарь `systems`) и 6 наблюдателей; добавляет их в мир (`add_system` / `add_observers`); назначает группы: `control`, `force_apply`, `angular_velocity_apply` → `"physics"`; `admin_cursor_sync` → `"admin"`; создаёт сущность `server` с `C_ServerIP`, `C_Position`, `C_CursorPosition`.
- `_process(delta: float) -> void` — `ECS.process(delta)` — системы группы по умолчанию.
- `_physics_process(delta: float) -> void` — `ECS.process(delta, "physics")` — физические системы. (Группа `"admin"` не вызывается.)
- `_create_entity(_name: String, components: Array, _world_: World) -> void` — вспомогательный: создаёт `Entity`, задаёт имя и мету `entity_id`, добавляет компоненты и регистрирует сущность в мире. Ничего не возвращает.

---

# 9. Схема данных: связи компонентов и систем

## 9.1 Цепочка спавна игрока (событийная, через Observers)

```
UDP-пакет от нового клиента
  └─ NetworkControlSystem: take_connection() → C_ServerIP.add_peer()
	   └─ NetworkPeerRegistrationSystem: Entity + C_PeerID + C_SpawnPoint
			├─ UserSpawnRequestObserver (on_added C_PeerID+C_SpawnPoint):
			│    RigidBody2D + [C_RigidBody, C_Position, C_Force, C_AngularVelocity,
			│                   C_ControlInput, C_CursorPosition, C_Modules]
			│      └─ MultimeshCreationObserver (on_added C_Modules):
			│           строит MultiMeshInstance2D-ы → C_Multimesh
			│             └─ RenderInitObserver (on_added C_Multimesh):
			│                  меши → в тело; тело → World/Ships;
			│                  добавляет C_Blocks + C_Collider
			│                    └─ ColliderCreationObserver (on_added C_Collider):
			│                         CollisionPolygon2D → в тело
			└─ SpawnPositionSyncObserver (on_added C_SpawnPoint):
				 C_Position.value = C_SpawnPoint.value; удаляет C_SpawnPoint
				   └─ PositionToRigidbodyObserver (on_changed C_Position.value):
						телепортирует RigidBody2D
```

## 9.2 Каждокадровый поток данных (управление и физика)

```
Клиент (connect.gd)
  │ UDP JSON {throttle, turn, brake, cursor_pos}
  ▼
NetworkControlSystem (_process)          [C_ServerIP]
  │ пишет C_ControlInput, C_CursorPosition
  ▼
ControlSystem (physics)                  [C_PeerID]
  │ C_ControlInput → C_Force, C_AngularVelocity, linear_damp
  ├─▶ ForceApplySystem (physics)         [C_RigidBody, C_Force]        → apply_central_force
  └─▶ AngularVelocityApplySystem (physics)[C_RigidBody, C_AngularVelocity] → angular_velocity
		│ физика Godot двигает RigidBody2D
		▼
PositionSyncSystem (_process)            [C_Position, C_RigidBody]
  │ body.global_position → C_Position.value
  ▼ (сигнал property_changed при изменении)
PositionToRigidbodyObserver

CursorInteractionSystem (_process)       [C_CursorPosition]
  └─ intersect_point → Relationship(C_Target, target_entity)

DamageControlSystem (_process)           [C_Blocks, C_DamagedBlock]
  │ HP−, destroy; +C_StateChanged; −C_DamagedBlock
  ▼
ParamsSyncSystem (_process)              [C_StateChanged, C_Blocks]
  └─ set_instance_color по проценту HP (HP_COLORS)
```

## 9.3 Таблица «компонент → кто пишет / кто читает»

| Компонент | Создаёт | Пишет | Читает | Удаляет |
|---|---|---|---|---|
| C_ServerIP | main.gd | NetworkControlSystem (peers) | NetworkControl-, NetworkPeerRegistration-, AdminCursorSync- | — |
| C_PeerID | NetworkPeerRegistrationSystem | — | ControlSystem (маркер), UserSpawnRequestObserver | — |
| C_SpawnPoint | NetworkPeerRegistrationSystem | — | UserSpawnRequestObserver, SpawnPositionSyncObserver | SpawnPositionSyncObserver |
| C_RigidBody | UserSpawnRequestObserver | — | почти все физ. системы и наблюдатели | — |
| C_Position | UserSpawnRequestObserver, main.gd | PositionSyncSystem, SpawnPositionSyncObserver | PositionToRigidbodyObserver (on_changed) | — |
| C_Force | UserSpawnRequestObserver | ControlSystem | ForceApplySystem | — |
| C_AngularVelocity | UserSpawnRequestObserver | ControlSystem | AngularVelocityApplySystem | — |
| C_ControlInput | UserSpawnRequestObserver | NetworkControlSystem | ControlSystem | — |
| C_CursorPosition | UserSpawnRequestObserver, main.gd | NetworkControlSystem, AdminCursorSyncSystem | CursorInteractionSystem | — |
| C_Modules | UserSpawnRequestObserver | — | MultimeshCreationObserver | — |
| C_Multimesh | MultimeshCreationObserver | — | RenderInitObserver | — |
| C_Blocks | RenderInitObserver | DamageControlSystem (HP) | DamageControl-, ParamsSync- | — |
| C_Collider | RenderInitObserver | — | ColliderCreationObserver | — |
| C_DamagedBlock | (внешний код / будущая система) | — | DamageControlSystem | DamageControlSystem |
| C_StateChanged | DamageControlSystem | — | ParamsSyncSystem | — (TODO) |
| C_Target | CursorInteractionSystem (как Relationship) | — | (потребителей пока нет) | CursorInteractionSystem |

## 9.4 Известные особенности / TODO текущего кода

- Группа `"admin"` (AdminCursorSyncSystem) нигде не вызывается — система неактивна; аргумент `--admin` не обрабатывается.
- `C_StateChanged` не удаляется после обработки — перекраска блоков повторяется каждый кадр.
- `ControlSystem` запрашивает только `C_PeerID` и не проверяет наличие остальных компонентов — возможна ошибка на кадре между регистрацией пира и срабатыванием Observer'а спавна.
- `C_Modules._init()` помечен как временный: корабль всегда грузится из `all_blocks_test.tres`.
- `connect.gd`: `_on_connected_to_server()` не вызывается, сцены `control.tscn` не существует; ник не влияет на подключение.
- Файл `с_сursorPosition.gd` назван с кириллическими «с».
- В `Server/Scenes/` остались временные файлы `server.tscn*.tmp` — мусор, можно удалить.
- Обратной синхронизации мира на клиент нет — клиент «слепой».

---

# 10. Словарь терминов

| Термин | Определение |
|---|---|
| **ECS** | Entity–Component–System — архитектурный паттерн: сущности — это идентификаторы-контейнеры, компоненты — чистые данные, системы — логика, обрабатывающая сущности с нужным набором компонентов. |
| **World** | Контейнер GECS (`res://addons/gecs/ecs/world.gd`, узел `World` в `server.tscn`), хранящий все сущности, системы и наблюдателей; предоставляет `add_entity`, `add_system`, `add_observers` и выполняет запросы. Назначается в `ECS.world`. |
| **Entity** | Сущность — узел GECS с уникальным `id` и набором компонентов (`add_component`, `get_component`). В проекте: сущность `server` и сущности `Player_<ip>_<ник>`. |
| **Component** | Компонент — ресурс-контейнер данных (класс, наследующий `Component`), без игровой логики. Может эмитить `property_changed` для реактивных наблюдателей (пример — `C_Position`). |
| **System** | Система — класс, наследующий `System`; объявляет `query()` (какие сущности обрабатывать) и `process(entities, components, delta)` (логика на каждый тик). Свойство `group` определяет, в каком вызове `ECS.process(delta, group)` она исполняется. |
| **Observer** | Наблюдатель — класс, наследующий `Observer`; реагирует на события компонентов: `on_added()` (компонент добавлен) и `on_changed([&"prop"])` (свойство изменилось, через сигнал `property_changed`). Обработчик — `each(event, entity, payload)`. |
| **CommandBuffer (`cmd`)** | Буфер отложенных структурных команд, доступный в системах и наблюдателях: `add_component`, `add_components`, `remove_component`, `add_relationship`, `remove_relationship`. Изменения применяются после итерации, что защищает от модификации списка сущностей во время обхода. |
| **Relationship** | Отношение GECS — типизированная связь «сущность → сущность» с компонентом-ключом: `Relationship.new(C_Target.new(), target_entity)`. Используется `CursorInteractionSystem` для пометки цели под курсором. |
| **QueryBuilder (`q`)** | Построитель запросов GECS: `q.with_all([...])` — сущности со всеми перечисленными компонентами; модификаторы `.on_added()` / `.on_changed([...])` превращают запрос в реактивный (для Observer). |

---

*Конец документации.*
