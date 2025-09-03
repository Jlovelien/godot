extends Area2D

@export var focal_offset: Vector2 = Vector2(0, 200) # relative focal point
var dragging := false
var drag_offset: Vector2

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

func _ready():
	# Create a Polygon2D node in code
	var visual_polygon = Polygon2D.new()
	add_child(visual_polygon)

	# Copy the shape from the CollisionPolygon2D
	visual_polygon.polygon = collision_polygon.polygon
	visual_polygon.transform = collision_polygon.transform

	# Style the lens look
	visual_polygon.color = Color(0.3, 0.7, 1, 0.3)  # bluish transparent
	visual_polygon.scale = collision_polygon.scale
	visual_polygon.z_index = 1  # draw on top of other stuff
	input_pickable = true  # lets us click this Area2D

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = true
			drag_offset = global_position - get_global_mouse_position()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position() + drag_offset

func interact_with_ray(hit_pos: Vector2, incoming_dir: Vector2) -> Dictionary:
	# Dynamic focal point = lens position + offset
	#var focal_point = global_position + focal_offset
	#var new_dir = (focal_point - hit_pos).normalized()

	return {
		"end": hit_pos,
		"color": Color.GREEN
	}
