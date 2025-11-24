extends Node2D

@export_range(0, 1024, 1) var num_rays: int = 32
@export_range(0.0, 20000.0, 1.0) var radius: float = 400.0
@export_range(0.0, 7.0, 0.01) var spread: float = PI / 2.0
@export_range(0.0, 7.0, 0.01) var direction: float = PI
@export_range(0, 16, 1) var max_bounces: int = 5

@export var focal_ray_threshold: int = 60          # how many samples = "bright enough"
@export var focal_cluster_radius: float = 32.0     # proximity for points to count as same cluster
@export var focal_sample_step: float = 100.0        # distance between samples along each segment
@export var focal_frames: SpriteFrames             # assign convexLight.tres in inspector
@export var debug_density_view: bool = true        # toggle density heatmap

const DEBUG_DRAW_OPTIC_SEGMENTS := false  # turn this on if you want the mirror/lens debug segments

var density_samples: Array[Vector2] = []
var density_debug: Array[Dictionary] = []          # [{ "pos": Vector2, "count": int }]

var focal_sprite: AnimatedSprite2D = null
var rayData: Array = []                            # raw Physics2D hits (debug)
var segments: Array = []                           # [start:Vector2, end:Vector2, color:Color]
var rays_to_trace: Array[RayState] = []            # stack / queue of RayState


func _ready() -> void:
	if focal_frames != null:
		focal_sprite = AnimatedSprite2D.new()
		add_child(focal_sprite)
		focal_sprite.sprite_frames = focal_frames
		focal_sprite.visible = false
		focal_sprite.z_index = 100
	else:
		push_warning("customLight: focal_frames is not set; focal sprite will not be shown.")


func _process(_delta: float) -> void:
	segments.clear()
	rayData.clear()
	rays_to_trace.clear()
	density_samples.clear()
	density_debug.clear()

	var hit_stats: Dictionary = {}  # collider -> { "count": int, "positions": Array[Vector2] }

	# 1. Seed initial rays
	for i in range(num_rays):
		var angle: float = direction - spread / 2.0 + (i / float(num_rays)) * spread
		var dir: Vector2 = Vector2(cos(angle), sin(angle)).normalized()
		var ray: RayState = RayState.new(global_position, dir, Color.RED, 0, i, angle)
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

		var result: Dictionary = space_state.intersect_ray(query)
		rayData.append(result)

		if result.is_empty():
			# no hit → draw full segment
			var endpoint: Vector2 = origin + dir * max_dist
			segments.append([origin, endpoint, color])
			continue

		var hit_pos: Vector2 = result.position
		var collider: Object = result.collider

		# always draw incoming segment up to hit
		segments.append([origin, hit_pos, color])

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

		if collider != null and collider.has_method("interact_with_ray"):
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
					segments.append([start, end, seg_color])

			# New rays to keep tracing
			if out.has("rays"):
				for r in out["rays"]:
					var offset_depth: int = int(r.get("offset_depth", 1))
					var new_depth: int = ray.depth + offset_depth

					if new_depth > max_bounces:
						continue

					var new_origin: Vector2 = r["origin"]
					var new_dir: Vector2 = (r["dir"] as Vector2).normalized()
					var new_color: Color = r.get("color", color)

					var child_ray: RayState = RayState.new(
						new_origin,
						new_dir,
						new_color,
						new_depth,
						ray.idx,
						ray.angle
					)
					rays_to_trace.append(child_ray)
		# else: collider has no interact_with_ray → ray stops at hit_pos

	# 3. Build density samples from all segments (post-processing)
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		_add_density_samples(a, b)

	# 4. After all rays for this frame, notify optics about batch stats
	for collider in hit_stats.keys():
		if collider != null and collider.has_method("on_ray_batch_stats"):
			collider.on_ray_batch_stats(hit_stats[collider])

	# 5. Focal point based on density
	_update_focal_sprite(density_samples)
	queue_redraw()


# --------------------------------------------------------------------
# Add density samples along a segment (no depth filtering here)
# --------------------------------------------------------------------
func _add_density_samples(a: Vector2, b: Vector2) -> void:
	var dist: float = a.distance_to(b)
	if dist <= 0.001:
		return

	var step: float = max(1.0, focal_sample_step)
	var steps: int = max(1, int(dist / step))

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		density_samples.append(p)


# --------------------------------------------------------------------
# FOCAL POINT + density debug
# --------------------------------------------------------------------
func _update_focal_sprite(points: Array[Vector2]) -> void:

	if points.is_empty():
		focal_sprite.visible = false
		focal_sprite.stop()
		return

	var best_pos: Vector2 = Vector2.ZERO
	var best_count: int = 0
	density_debug.clear()

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

		density_debug.append({
			"pos": p,
			"count": count
		})

		if count > best_count:
			best_count = count
			if count > 0:
				best_pos = sum / float(count)

	# if density is high enough, show the focal sprite there
	if best_count >= focal_ray_threshold:
		focal_sprite.global_position = best_pos
		focal_sprite.visible = true
		focal_sprite.play()
	else:
		focal_sprite.visible = false
		focal_sprite.stop()


func _draw() -> void:
	# draw ray segments
	for seg in segments:
		draw_line(
			to_local(seg[0]),
			to_local(seg[1]),
			seg[2],
			2.0
		)

	# draw density "heatmap"
	if debug_density_view:
		for d in density_debug:
			var pos: Vector2 = d["pos"]
			var count: int = d["count"]

			var t: float = clamp(float(count) / float(focal_ray_threshold), 0.0, 1.0)
			var radius: float = lerp(2.0, 8.0, t)
			var col: Color = Color(1.0, 1.0 - t, 0.0, 0.2 + 0.5 * t) # pale yellow → orange

			draw_circle(to_local(pos), radius, col)


func getResult() -> Array:
	return rayData
