extends StaticBody2D

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

@export var segment_length: float = 400.0

func _process(_delta: float) -> void:
	# Turn mirror 90 degrees right / left
	if Input.is_action_just_pressed("rotateRight"):
		rotation_degrees += 90.0
	if Input.is_action_just_pressed("rotateLeft"):
		rotation_degrees -= 90.0

# Per-ray logic for a mirror
func interact_with_ray(
	hit_pos: Vector2,
	incoming_dir: Vector2,
	_ray: RayState,
	surface_normal: Vector2
) -> Dictionary:
	# Check if the ray is hitting the front side (dot product < 0 means incoming towards the surface)
	if incoming_dir.dot(surface_normal) >= 0.0:
		return {}  # no reflection; ray is hitting from the back or parallel

	# Reflect the incoming direction around the surface normal
	var reflected_dir: Vector2 = incoming_dir.bounce(surface_normal).normalized()

	return {
		"segments": [
			{
				"start": hit_pos,
				"end": hit_pos + reflected_dir * segment_length,
				"color": Color(0.3, 0.7, 1.0)
			}
		],
		"rays": [
			{
				"origin": hit_pos,
				"dir": reflected_dir,
				"color": Color(0.3, 0.7, 1.0),
				"offset_depth": 1
			}
		]
	}
