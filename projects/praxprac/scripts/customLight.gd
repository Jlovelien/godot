extends Node2D

@export_range(0, 1024, 1) var num_rays: int = 32
@export_range(0.0, 20000, 1) var radius: float = 400
@export_range(0.0, 7, 0.01) var spread: float = PI / 2
@export_range(0.0, 7, 0.01) var direction: float = PI
var rayData = []

var rays: Array = []  # [(start, end, color)]

func _process(_delta):
	#resets the "rays" array
	rays.clear()
	#creates "space state" variable which contains the world in which all these scritps are happening
	var space_state = get_world_2d().direct_space_state
	#Makes allRays equal to an empty dictionary
	var allRays = []
	for i in range(num_rays):
		var angle = direction - spread/2 + (i / float(num_rays)) * spread
		var dir = Vector2(cos(angle), sin(angle))
		var hit = global_position + dir * radius
		
		# default: no hit -> draw full ray to 'hit'
		#Literally cannot believe we called this 'to' for so long what the hell so unintuitive send help
		var endpoint: Vector2 = hit
		var color: Color = Color.RED

		var query = PhysicsRayQueryParameters2D.create(global_position, hit)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result = space_state.intersect_ray(query)
		allRays.append(result)
		
		if result.size() > 0:
			var collider = result.get("collider")
			var hit_pos: Vector2 = result.get("position")
			
			# default: incoming ray ends at the hit
			endpoint = hit_pos
			color = Color.RED
			
			#TODO: Keep working getting lens position correct
			#Direction from light source to lens
			#query.collide_with_areas = true
			#query.collide_with_bodies = false
			#var dir_to_hit = (hit_pos - global_position).normalized()
			#print(dir_to_hit)
			
			# This is interesting; this checks the collider to see if it has a funciton with that name
			# if collider implements interact_with_ray, call it
			#ChrisNote: This function doesn't do *anything* until it hits a collider (i.e., *any object*)
			#and that collider needs to have "interact_with_ray" in it somewhere.
			if collider != null and collider.has_method("interact_with_ray"):
				var ray_data = collider.interact_with_ray(hit_pos, dir)
				if ray_data:
					# if the object provided a start & end (preferred), add two segments:
					if ray_data.has("start") and ray_data.has("end"):
						# incoming: emitter -> hit_pos (yellow)
						rays.append([global_position, hit_pos, Color(1, 1, 0)])
						# outgoing beam: start -> end (object color or fallback)
						rays.append([ray_data["start"], ray_data["end"], ray_data.get("color", Color(0.3, 0.7, 1))])
						# skip the default append below for this ray
						continue
					else:
						# older/simple contract: object returned only "end"
						endpoint = ray_data.get("end", endpoint)
						color = ray_data.get("color", color)
			else:
				# no interact_with_ray: draw to hit_pos (default)
				endpoint = hit_pos

		rays.append([global_position, endpoint, color])
	queue_redraw()
	rayData = allRays

func getResult():
	return rayData

func _draw():
	for ray in rays:
		draw_line(to_local(ray[0]), to_local(ray[1]), ray[2], 2.0)
