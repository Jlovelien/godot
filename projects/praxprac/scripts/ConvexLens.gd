extends StaticBody2D

@export var focal_point: Vector2 = Vector2(400, 400)

func interact_with_ray(hit_pos: Vector2, incoming_dir: Vector2) -> Dictionary:
	# Simplified focusing: redirect ray to focal_point
	#var new_dir = (focal_point - hit_pos).normalized()
	return {
		#"end": hit_pos + new_dir * 500,  
		"end": hit_pos, # arbitrary length of refracted ray
		"color": Color.GREEN
	}
