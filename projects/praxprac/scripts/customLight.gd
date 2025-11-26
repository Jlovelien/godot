extends Node2D

@export_range(0, 1024, 1) var num_rays: int = 32
@export_range(0.0, 20000.0, 1.0) var radius: float = 400.0
@export_range(0.0, 7.0, 0.01) var spread: float = PI / 2.0
@export_range(0.0, 7.0, 0.01) var direction: float = PI
@export_range(0, 16, 1) var max_bounces: int = 5 

@export var focal_sample_step: float = 100.0        # distance between samples along each segment
@export var focal_ray_threshold: int = 60          # how many samples = "bright enough" for debug heatmap
@export var debug_density_view: bool = true        # toggle density heatmap
@export var enable_density: bool = false           # enable density sampling and focal calculation
@export var use_depth_colors: bool = false         # if true, use depth-based colors for ray segments; else use actual ray colors
@export var depth_colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.MAGENTA, Color.WHITE]  # colors for each depth level

@export var light_id: int = 0                      # ID for this light source, used to distinguish light types
@export_enum("Radial", "Cone", "Line") var light_shape: int = 0  # Shape of the light emission
@export_range(0.0, 1000.0, 1.0) var line_length: float = 100.0   # Length of the line for line shape
@export_range(1, 100, 1) var line_rays: int = 10                 # Number of rays along the line

const DEBUG_DRAW_OPTIC_SEGMENTS := false  # turn this on if you want the mirror/lens debug segments

var density_samples: Array[Vector2] = []
var density_debug: Array[Dictionary] = []          # [{ "pos": Vector2, "count": int }]

signal density_updated(samples: Array[Vector2])

var rayData: Array = []                            # raw Physics2D hits (debug)
var segments: Array[Dictionary] = []               # [{"start": Vector2, "end": Vector2, "color": Color, "depth": int}]
var rays_to_trace: Array[RayState] = []            # stack / queue of RayState

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	segments.clear()
	rayData.clear()
	rays_to_trace.clear()
	density_samples.clear()
	density_debug.clear()

	var hit_stats: Dictionary = {}  # collider -> { "count": int, "positions": Array[Vector2] }

	# 1. Seed initial rays
	var initial_color = depth_colors[0] if depth_colors.size() > 0 else Color.RED
	if light_shape == 0 or light_shape == 1:  # Radial or Cone
		for i in range(num_rays):
			var angle: float = direction - spread / 2.0 + (i / float(num_rays)) * spread
			var dir: Vector2 = Vector2(cos(angle), sin(angle)).normalized()
			var ray: RayState = RayState.new(global_position, dir, initial_color, 0, i, angle, light_id)
			rays_to_trace.append(ray)
	elif light_shape == 2:  # Line
		var ray_dir = Vector2(cos(direction), sin(direction)).normalized()
		var perp_dir = Vector2(-ray_dir.y, ray_dir.x)  # perpendicular to ray_dir
		for i in range(line_rays):
			var t = (i - (line_rays - 1) / 2.0) / max(1, line_rays - 1) if line_rays > 1 else 0.0
			var offset = t * line_length * perp_dir
			var ray_origin = global_position + offset
			var ray = RayState.new(ray_origin, ray_dir, initial_color, 0, i, direction, light_id)
			rays_to_trace.append(ray)

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	# 2. Trace rays iteratively
	while rays_to_trace.size() > 0:
		var ray: RayState = rays_to_trace.pop_back()

		if ray.depth > max_bounces:
			continue

		var origin: Vector2 = ray.origin
		var dir: Vector2 = ray.dir.normalized()
		var color: Color = ray.color
		var max_dist: float = radius

		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			origin,
			origin + dir * max_dist
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = ray.interacted_objects.map(func(obj): return obj.get_rid())

		var result: Dictionary = space_state.intersect_ray(query)
		rayData.append(result)

		if result.is_empty():
			# no hit → draw full segment
			var endpoint: Vector2 = origin + dir * max_dist
			segments.append({"start": origin, "end": endpoint, "color": color, "depth": ray.depth})
			continue

		var hit_pos: Vector2 = result.position
		var collider: Object = result.collider

		# always draw incoming segment up to hit
		segments.append({"start": origin, "end": hit_pos, "color": color, "depth": ray.depth})

		# accumulate per-object stats for this frame
		if collider != null:
			if not hit_stats.has(collider):
				hit_stats[collider] = {
					"count": 0,
					"positions": []
				}
			hit_stats[collider]["count"] += 1
			var pos_arr: Array = hit_stats[collider]["positions"]
			pos_arr.append(hit_pos)

		if collider != null and collider.has_method("interact_with_ray") and not (collider in ray.interacted_objects):
			# Note: we now pass the entire RayState instead of idx/angle/etc.
			var out: Dictionary = collider.interact_with_ray(
				hit_pos,
				dir,
				ray
			)

			if out.is_empty():
				continue

			# OPTIONAL extra segments provided by the optic
			# These do NOT respect further collisions, so they are off by default.
			if DEBUG_DRAW_OPTIC_SEGMENTS and out.has("segments"):
				for s in out["segments"]:
					var start: Vector2 = s["start"]
					var end: Vector2 = s["end"]
					var seg_color: Color = s.get("color", color)
					segments.append({"start": start, "end": end, "color": seg_color, "depth": ray.depth})

			# New rays to keep tracing
			if out.has("rays"):
				for r in out["rays"]:
					var offset_depth: int = int(r.get("offset_depth", 1))
					var new_depth: int = ray.depth + offset_depth

					if new_depth > max_bounces:
						continue

					var new_origin: Vector2 = r["origin"]
					var new_dir: Vector2 = (r["dir"] as Vector2).normalized()
					var new_color: Color = color  # Preserve the color across bounces

					var child_ray: RayState = RayState.new(
						new_origin,
						new_dir,
						new_color,
						new_depth,
						ray.idx,
						ray.angle,
						ray.source_id
					)
					child_ray.interacted_objects = [collider]
					rays_to_trace.append(child_ray)
		# else: collider has no interact_with_ray → ray stops at hit_pos

	# putting the density code behind the enable_density flag to avoid unnecessary computation
	if enable_density:
		# 3. Build density samples from all segments (post-processing)
		for seg in segments:
			_add_density_samples(seg)

		# 4. Compute density debug for heatmap
		density_debug.clear()
		for i in range(density_samples.size()):
			var p: Vector2 = density_samples[i]
			var count: int = 0
			for j in range(density_samples.size()):
				var q: Vector2 = density_samples[j]
				if p.distance_to(q) <= 32.0:  # focal_cluster_radius, hardcoded for debug
					count += 1
			density_debug.append({"pos": p, "count": count})

		# 5. Emit density data for external focal calculation
		#print("CustomLight: Emitting density_samples with ", density_samples.size(), " points")
		density_updated.emit(density_samples)

	# 6. After all rays for this frame, notify optics about batch stats
	for collider in hit_stats.keys():
		if collider != null and collider.has_method("on_ray_batch_stats"):
			collider.on_ray_batch_stats(hit_stats[collider])

	queue_redraw()


# --------------------------------------------------------------------
# Add density samples along a segment (filtered by depth and camera view)
# --------------------------------------------------------------------
func _is_point_in_camera_view(point: Vector2) -> bool:
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return true  # if no camera, include all
	var viewport_size = get_viewport().size
	var screen_pos = camera.get_viewport_transform() * point
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y

func _get_color_for_depth(depth: int) -> Color:
	if depth < depth_colors.size():
		return depth_colors[depth]
	else:
		return Color.WHITE

func _add_density_samples(seg: Dictionary) -> void:
	if seg.depth <= 0:
		return

	var a: Vector2 = seg.start
	var b: Vector2 = seg.end
	var dist: float = a.distance_to(b)
	if dist <= 0.001:
		return

	var step: float = max(1.0, focal_sample_step)
	var steps: int = max(1, int(dist / step))

	for i in range(1, steps + 1):  # Skip the start point to avoid hot spots at collision origins
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		if _is_point_in_camera_view(p):
			density_samples.append(p)



func _draw() -> void:
	# draw ray segments
	for seg in segments:
		var col = _get_color_for_depth(seg.depth) if use_depth_colors else seg.color
		draw_line(
			to_local(seg.start),
			to_local(seg.end),
			col,
			2.0
		)

	# draw density "heatmap"
	if debug_density_view:
		for d in density_debug:
			var pos: Vector2 = d["pos"]
			var count: int = d["count"]

			var t: float = clamp(float(count) / float(focal_ray_threshold), 0.0, 1.0)
			var draw_radius: float = lerp(2.0, 8.0, t)
			var col: Color = Color(1.0, 1.0 - t, 0.0, 0.2 + 0.5 * t) # pale yellow → orange

			draw_circle(to_local(pos), draw_radius, col)


func getResult() -> Array:
	return rayData
