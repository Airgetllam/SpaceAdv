extends Node2D

# { 'points': Array (из PackedVector2Array), 'color': Color }
var frames: Array = []

func _draw() -> void:
	for frame in frames:
		var corners: Array = frame['points']
		var color: Color = frame['color']
		for corner in corners:
			draw_polyline(corner, color, 10)

func set_frames(new_frames: Array):
	frames = new_frames
	queue_redraw()
