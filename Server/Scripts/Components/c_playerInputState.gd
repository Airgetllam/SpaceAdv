extends Component
class_name C_PlayerInputState

# Последний input frame, применённый simulation.
var current_frame: PlayerInputFrame = PlayerInputFrame.new()

# Discrete events из последнего применённого frame.
# Их consume делает gameplay system.
var pending_events: Array[PlayerInputAction] = []
