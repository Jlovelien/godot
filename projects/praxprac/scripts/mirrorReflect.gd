extends StaticBody2D

@onready var mirrorSide: Marker2D = $CollisionPolygon2D/mirrorMark
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

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
	ray: RayState
) -> Dictionary:
	# normal pointing out of the reflective face:
	# assume mirrorMark is on the reflective side
	var global_normal: Vector2 = (mirrorSide.global_position - global_position).normalized()

	# If dot > 0 → ray moving roughly in same direction as normal = back side.
	if incoming_dir.dot(global_normal) > 0.0:
		return {}  # no reflection; ray just dies at hit_pos

	# Reflect the incoming direction around the normal
	var reflected_dir: Vector2 = incoming_dir.bounce(global_normal).normalized()
	var segment_length := 400.0    # tweak or export if needed

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
