extends Area2D

@export var focal_offset: Vector2 = Vector2(0, 200) # relative focal point
var dragging := false
var drag_offset: Vector2

@export var beam_length: float = 600.0
const EPS = 1e-4

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

func _ready():
	# Create a Polygon2D node in code
	var visual_polygon = Polygon2D.new()
	add_child(visual_polygon)

	# Copy the shape from the CollisionPolygon2D
	visual_polygon.polygon = collision_polygon.polygon
	visual_polygon.transform = collision_polygon.transform

	# Style the lens look
	visual_polygon.color = Color(0.3, 0.7, 1, 0.3)  # bluish transparent
	visual_polygon.scale = collision_polygon.scale
	visual_polygon.z_index = 1  # draw on top of other stuff
	input_pickable = true  # lets us click this Area2D

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = true
			drag_offset = global_position - get_global_mouse_position()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position() + drag_offset

func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x
	
func _ray_segment_intersection(ray_o: Vector2, ray_dir: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	# Solve ray_o + t*ray_dir = a + u*(b-a)
	var seg = b - a
	var denom = _cross(ray_dir, seg)
	if abs(denom) < 1e-6:
		return {} # parallel or nearly parallel
	var ao = a - ray_o
	var t = _cross(ao, seg) / denom
	var u = _cross(ao, ray_dir) / denom
	# valid intersection if t >= 0 (on ray) and u in [0,1] (on segment)
	if t >= 0.0 and u >= 0.0 and u <= 1.0:
		return {"pos": ray_o + ray_dir * t, "t": t, "u": u}
	return {}

func interact_with_ray(hit_pos: Vector2, incoming_dir: Vector2) -> Dictionary:
	# 1) Build polygon points in global coords
	var local_poly = collision_polygon.polygon
	if local_poly.size() < 3:
		# degenerate polygon: fallback to opposite incoming direction
		return {
			"start": hit_pos,
			"end": hit_pos + (-incoming_dir).normalized() * beam_length,
			"color": Color(0.3, 0.7, 1)
			}
		
	var poly: Array = []
	for p in local_poly:
		 # collision_polygon is a Node2D; convert local poly points to global
		poly.append(collision_polygon.to_global(p))
		
	# 2) Ray from hit_pos through polygon centroid to find opposite intersection
	var centroid = Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= poly.size()
	
	# direction from hit point toward centroid (goes through shape to the far side)
	var across = centroid - hit_pos
	if across.length() < EPS:
		# hit is effectively at centroid or too close; fallback
		across = -incoming_dir
	var ray_dir = across.normalized()
	
	# 3) Find all intersections of ray (origin hit_pos) with polygon edges
	var best_t = -INF
	var best_hit = null
	var n = poly.size()
	for i in range(n):
		var a = poly[i]
		var b = poly[(i + 1) % n]
		var inter = _ray_segment_intersection(hit_pos, ray_dir, a, b)
		if inter.size() > 0:
			var t = inter["t"]
			# choose the intersection farthest along the ray (largest t)
			 # (the far side across the polygon)
			if t > EPS and t > best_t: #skip the near-edge t ~= 0
				best_t = t
				best_hit = {
					"pos": inter["pos"],
					"a": a,
					"b": b
				}
				
	# 4) If we found an exit intersection, compute the edge normal and emit perpendicular beam
	if best_hit != null:
		var exit_pos: Vector2 = best_hit["pos"]
		var a: Vector2 = best_hit["a"]
		var b: Vector2 = best_hit["b"]
		var edge = (b - a).normalized()
		# edge normal (one of the two perpendicular directions)
		var normal = Vector2(-edge.y, edge.x).normalized()
		# choose the normal that points away from the polygon interior / along ray_dir
		# If normal and ray_dir point roughly the same way, use that, otherwise flip it.
		if normal.dot(ray_dir) < 0.0:
			normal = -normal

		var start_point = exit_pos + normal * 1.0 # tiny offset to avoid z-fighting if needed
		var end_point = start_point + normal * beam_length
		
		# debug prints (uncomment for debugging)
		#print("hit_pos:", hit_pos, "centroid:", centroid, "ray_dir:", ray_dir)
		# print("exit_pos:", exit_pos, "edge:", edge, "normal:", normal)
		
		return {
			"start": start_point,
			"end": end_point,
			"color": Color(0.3, 0.7, 1)
		}
	# 5) Fallback: emit opposite incoming direction
	# fallback: couldn't find opposite intersection; emit opposite incoming_dir
	return {
		"start": hit_pos,
		"end": hit_pos + (-incoming_dir).normalized() * beam_length,
		"color": Color(0.3, 0.7, 1)
	}
