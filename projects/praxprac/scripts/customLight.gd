extends Node2D

@export_range(0, 1024, 1) var num_rays: int = 4
@export_range(0.0, 2000, 1) var radius: float = 40
@export_range(0.0, 7, 0.01) var spread: float = PI / 2
@export_range(0.0, 7, 0.01) var direction: float = PI   # aiming bottom-left

var rays: Array = []  # will store tuples [(start, end), ...]
var color: Color = "RED"

func _process(_delta):
	rays.clear()
	var space_state = get_world_2d().direct_space_state

	for i in range(num_rays):
		color = "RED"
		var angle = direction - spread/2 + (i / float(num_rays)) * spread
		var dir = Vector2(cos(angle), sin(angle))
		var to = global_position + dir * radius

		var query = PhysicsRayQueryParameters2D.create(global_position, to)
		var result = space_state.intersect_ray(query)

		var endpoint: Vector2 = to
		if result.size() > 0:   # means something was hit
			var collider = result["collider"]
			var hit_pos = result["position"]

			#print("Hit:", collider.name, " Groups:", collider.get_groups())

			if collider.is_in_group("lens"):
				print("Lens hit!")
				rays.append([global_position, endpoint,"GREEN"])
			# endpoint = handle_lens_interaction(hit_pos, dir)
			else:
				endpoint = hit_pos
				rays.append([global_position, endpoint,color])
		else:
			endpoint = global_position + dir * radius
			rays.append([global_position, endpoint,color])
	print(rays)
	print("______")
	
	
	queue_redraw()
func _draw():
	for ray in rays:
		draw_line(to_local(ray[0]), to_local(ray[1]), ray[2], 2.0)
