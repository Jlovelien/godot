extends Marker2D

func _ready():
	position = Vector2(0, -50)
	queue_redraw()  # forces _draw to run once
