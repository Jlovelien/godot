extends Marker2D

func _ready():
	#First, detect position
	
	position = Vector2(0, -120)
	queue_redraw()  # forces _draw to run once
