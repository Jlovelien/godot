extends Node2D

@export var focal_ray_threshold: int = 60          # how many samples = "bright enough"
@export var focal_cluster_radius: float = 32.0     # proximity for points to count as same cluster
@export var focal_frames: SpriteFrames             # assign convexLight.tres in inspector

var focal_sprite: AnimatedSprite2D = null

func _ready() -> void:
	if focal_frames != null:
		focal_sprite = AnimatedSprite2D.new()
		add_child(focal_sprite)
		focal_sprite.sprite_frames = focal_frames
		focal_sprite.visible = false
		focal_sprite.z_index = 100
	else:
		push_warning("FocalManager: focal_frames is not set; focal sprite will not be shown.")

func update_focal(points: Array[Vector2]) -> void:
	#print("FocalManager: Received ", points.size(), " density points")
	if points.is_empty():
		if focal_sprite:
			focal_sprite.visible = false
			focal_sprite.stop()
		return

	var best_pos: Vector2 = Vector2.ZERO
	var best_count: int = 0

	# naive density clustering: for each point, count neighbors within focal_cluster_radius
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var count: int = 0
		var sum: Vector2 = Vector2.ZERO

		for j in range(points.size()):
			var q: Vector2 = points[j]
			if p.distance_to(q) <= focal_cluster_radius:
				count += 1
				sum += q

		if count > best_count:
			best_count = count
			if count > 0:
				best_pos = sum / float(count)

	#print("FocalManager: Best count ", best_count, " at ", best_pos, " threshold ", focal_ray_threshold)
	# if density is high enough, show the focal sprite there
	if focal_sprite:
		if best_count >= focal_ray_threshold:
			focal_sprite.global_position = best_pos
			focal_sprite.visible = true
			focal_sprite.play()
			#print("FocalManager: Showing focal sprite")
		else:
			focal_sprite.visible = false
			focal_sprite.stop()
			#print("FocalManager: Hiding focal sprite")
	else:
		print("FocalManager: No focal_sprite")
