extends StaticBody2D

@onready var mirrorSide: Marker2D = $CollisionPolygon2D/focalMark
@onready var light_pos = $"../customLight".position
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D


func _process(_delta):
	# Turn mirror 90 degrees right
	if Input.is_action_just_pressed("rotateRight"):
		self.rotation_degrees += 90
	if Input.is_action_just_pressed("rotateLeft"):
		self.rotation_degrees -= 90

#TODO calculate mirror angle
func interact_with_ray(hit_pos: Vector2, incoming_dir: Vector2, _idx: int, angle) -> Dictionary:
	# normal that always sticks out of the reflective face
	var global_normal := global_transform.x.rotated(2*PI)

	var in_dir := hit_pos.normalized()
	# front-side hit?
	if in_dir.dot(global_normal) >= 0:          # 0° … 90° → back side
		return {}                               # empty = “pass through”

	# reflect
	var reflected_dir := in_dir.bounce(global_normal)
	return { "start": hit_pos,
			"end":  hit_pos + reflected_dir * 400.0,
			"color": Color(0.3, 0.7, 1) }
