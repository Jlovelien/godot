extends Area2D

var dragging := false
var drag_offset: Vector2

@onready var focalMark: Marker2D = $focalMark
@export var focal_offset: Vector2 = Vector2(0, 200) # relative focal point
var focalPoint
@onready var focalLight := preload("res://scenes/convexLight.tscn")
var fl = AnimatedSprite2D.new()

@export var beam_length: float = 600.0
const EPS = 1e-4
@export_range(0, 25, 1) var rayCount : int = 12

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

#Prepping for how focal point is computed
var focal_positions: Array = []
var side_dirs: Array = []

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
	for node in get_tree().get_nodes_in_group("rays"):
		if node.has_method("getResult"):
			var results= node.getResult()  # This can return something
			lensActive(colCount(results))
	
	if focal_positions.is_empty():
		return
	# Step 1: find dominant side
	var domSide: Vector2 = Vector2.ZERO
	for side in side_dirs:
		domSide += side
	domSide = domSide.normalized()
	
	# Step 2: keep only focal points from that side
	var domPositions: Array = []
	for i in range(focal_positions.size()):
		var dir = side_dirs[i]
		if dir.dot(domSide) > 0.4: # threshold controls strictness
			domPositions.append(focal_positions[i])
			
	# Step 3: average them
	if domPositions.size() > 0:
		var avgPosition: Vector2 = Vector2.ZERO
		for pos in domPositions:
			avgPosition += pos
		focalMark.global_position = avgPosition/domPositions.size()
	# Step 4: clear for next frame
	focal_positions.clear()
	side_dirs.clear()

func colCount(result):
	#print(result)
	var raylensCount = 0
	for i in result:
		if i.collider.name.begins_with("convexLens"):
			raylensCount +=1
	return raylensCount
	
func lensActive(rayNum):
	if rayNum >= rayCount and fl.get_parent() == null:
		focalMark.add_child(fl)
		fl.sprite_frames = preload("res://assets/animations/convexLight.tres") 
		fl.play("convexLight")
	elif rayNum < rayCount and fl.get_parent() == focalMark:
		focalMark.remove_child(fl)
	return

func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

func noSolid(center: Vector2, focal_pos: Vector2) -> bool:
	# Build query parameters
	var query := PhysicsRayQueryParameters2D.create(center, focal_pos)
	query.exclude = [self]  # don’t count the lens itself
	query.collision_mask = 1 << 0  # only test against “solid” layer (layer 2 in this example)
	# Perform the raycast
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	# If nothing was hit, result will be empty → return true (no solid in the way)
	return result.is_empty()


#My attempt to create this function from scratch lmao
#func noSolid(center: Vector2, focal_pos: Vector2) -> bool:
	#var exclude = [self] #Prepping unnecessary parameters ahead of time
	#var collision_mask = 1 << 2
	#var solidCheck = get_world_2d().direct_space_state.intersect_ray(center, focal_pos, exclude, collision_mask)
	#if solidCheck.is_empty():
		#return true 
	#else:
		#return false
	

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
	# 1) Get the lens center in world space
	var center: Vector2 = global_position
	
	# 2) Vector from center -> hit position (tells us which side was struck)
	var center_to_hit: Vector2 = hit_pos - center
	
	# 3) If the hit is basically on the center, fall back to using the incoming direction
	#Otherwise use the center_to_hit to determine which side the ray came from.
	var side_dir: Vector2
	if center_to_hit.length() < EPS:
		# incoming_dir points *toward* the lens; invert to find the side the ray came from
		side_dir = (-incoming_dir).normalized()
	else:
		# direction from center to the hit point (points toward the struck side)
		side_dir = center_to_hit.normalized()

	# 4) We want the focal point on the opposite side, so flip the side_dir
	var exit_dir: Vector2 = -side_dir

	# 5) Focal distance (how far past the center the focal point sits).
	#Reuse your exported focal_offset vector's magnitude so you can tune in the editor.
	var focal_distance: float = focal_offset.length()

	# 6) Compute focal point position: center + exit_dir * focal_distance
	var focal_pos: Vector2 = center + exit_dir * focal_distance
	
	#6.5) Average focal points to inform focalMark location
	if noSolid(center, focal_pos):
		focal_positions.append(focal_pos)
		side_dirs.append(side_dir)

	# 7) Tell the ray system: incoming segment ends at hit_pos, outgoing goes to focal_pos
	return {
		"start": hit_pos,
		"end": focal_pos,
		"color": Color(0.3, 0.7, 1) # optional tint for refracted beam
	}



#This function treats raycasting more realistically - we might return to it, but
#it's basically useless to us at the moment
#func interact_with_ray(hit_pos: Vector2, incoming_dir: Vector2) -> Dictionary:
	## 1) Build polygon points in global coords
	#var local_poly = collision_polygon.polygon
	#if local_poly.size() < 3:
		## degenerate polygon: fallback to opposite incoming direction
		#return {
			#"start": hit_pos,
			#"end": hit_pos + (-incoming_dir).normalized() * beam_length,
			#"color": Color(0.3, 0.7, 1)
			#}
		#
	#var poly: Array = []
	#for p in local_poly:
		 ## collision_polygon is a Node2D; convert local poly points to global
		#poly.append(collision_polygon.to_global(p))
		#
	## 2) Ray from hit_pos through polygon centroid to find opposite intersection
	#var centroid = Vector2.ZERO
	#for p in poly:
		#centroid += p
	#centroid /= poly.size()
	#
	## direction from hit point toward centroid (goes through shape to the far side)
	#var across = centroid - hit_pos
	#if across.length() < EPS:
		## hit is effectively at centroid or too close; fallback
		#across = -incoming_dir
	#var ray_dir = across.normalized()
	#
	## 3) Find all intersections of ray (origin hit_pos) with polygon edges
	#var best_t = -INF
	#var best_hit = null
	#var n = poly.size()
	#for i in range(n):
		#var a = poly[i]
		#var b = poly[(i + 1) % n]
		#var inter = _ray_segment_intersection(hit_pos, ray_dir, a, b)
		#if inter.size() > 0:
			#var t = inter["t"]
			## choose the intersection farthest along the ray (largest t)
			 ## (the far side across the polygon)
			#if t > EPS and t > best_t: #skip the near-edge t ~= 0
				#best_t = t
				#best_hit = {
					#"pos": inter["pos"],
					#"a": a,
					#"b": b
				#}
				#
	## 4) If we found an exit intersection, compute the edge normal and emit perpendicular beam
	#if best_hit != null:
		#var exit_pos: Vector2 = best_hit["pos"]
		#var a: Vector2 = best_hit["a"]
		#var b: Vector2 = best_hit["b"]
		#var edge = (b - a).normalized()
		## edge normal (one of the two perpendicular directions)
		#var normal = Vector2(-edge.y, edge.x).normalized()
		## choose the normal that points away from the polygon interior / along ray_dir
		## If normal and ray_dir point roughly the same way, use that, otherwise flip it.
		#if normal.dot(ray_dir) < 0.0:
			#normal = -normal
#
		#var start_point = exit_pos + normal * 1.0 # tiny offset to avoid z-fighting if needed
		#var end_point = start_point + normal * beam_length
		#
		## debug prints (uncomment for debugging)
		##print("hit_pos:", hit_pos, "centroid:", centroid, "ray_dir:", ray_dir)
		## print("exit_pos:", exit_pos, "edge:", edge, "normal:", normal)
		#
		#return {
			#"start": start_point,
			#"end": end_point,
			#"color": Color(0.3, 0.7, 1)
		#}
	# 5) Fallback: emit opposite incoming direction
	# fallback: couldn't find opposite intersection; emit opposite incoming_dir
	#return {
		#"start": hit_pos,
		#"end": hit_pos + (-incoming_dir).normalized() * beam_length,
		#"color": Color(0.3, 0.7, 1)
	#}
