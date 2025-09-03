extends Node2D

@export_range(0, 1024, 1) var num_rays: int = 32
@export_range(0.0, 2000, 1) var radius: float = 400
@export_range(0.0, 7, 0.01) var spread: float = PI / 2
@export_range(0.0, 7, 0.01) var direction: float = PI

var rays: Array = []  # [(start, end, color)]

func _process(_delta):
	rays.clear()
	var space_state = get_world_2d().direct_space_state

	for i in range(num_rays):
		var angle = direction - spread/2 + (i / float(num_rays)) * spread
		var dir = Vector2(cos(angle), sin(angle))
		var to = global_position + dir * radius

		var query = PhysicsRayQueryParameters2D.create(global_position, to)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result = space_state.intersect_ray(query)

		var endpoint: Vector2 = to
		var color: Color = Color.RED

		if result.size() > 0:
			var collider = result["collider"]
			var hit_pos = result["position"]

# This is interesting.. this checks the collider to see if it has a funciton with that name
			if "interact_with_ray" in collider:
				var ray_data = collider.interact_with_ray(hit_pos, dir)
				if ray_data:
					endpoint = ray_data["end"]
					color = ray_data.get("color", color)
			else:
				endpoint = hit_pos

		rays.append([global_position, endpoint, color])

	queue_redraw()


func _draw():
	for ray in rays:
		draw_line(to_local(ray[0]), to_local(ray[1]), ray[2], 2.0)
