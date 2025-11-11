extends Area2D

var dragging := false
var rotating := false
var drag_offset: Vector2
var rotation_offset := 0.0

@onready var focalMark: Marker2D = $CollisionPolygon2D/focalMark
@onready var polySide: Marker2D = $CollisionPolygon2D/focalMark2
@export var focal_offset: Vector2 = Vector2(0, 200) # relative focal point

var focalPoint
@onready var focalLight := preload("res://scenes/convexLight.tscn")
var fl = AnimatedSprite2D.new()

@export var beam_length: float = 600.0
const EPS = 1e-4
@export_range(0, 25, 1) var rayCount : int = 12

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

@onready var light_pos = $"../customLight".position

#Debugging lens direction
@export var debug_draw: bool = true
@export var debug_line_width: float = 2.0

var _dbg_lines: Array = []   # each: {a:Vector2, b:Vector2, color:Color, w:float}
var _dbg_points: Array = []  # each: {p:Vector2, r:float, color:Color}

#Prepping for how focal point is computed
var focal_positions: Array = []
var side_dirs: Array = []

#Light direction vars
@onready var redLight = focalMark.position.y
@onready var greenLight = -focalMark.position.y

#functions for debugging
func _dbg_add_line(a: Vector2, b: Vector2, color: Color, w: float = debug_line_width) -> void:
	if not debug_draw: return
	_dbg_lines.append({"a": a, "b": b, "color": color, "w": w})

func _dbg_add_point(p: Vector2, r: float = 4.0, color: Color = Color(1, 0, 0)) -> void:
	if not debug_draw: return
	_dbg_points.append({"p": p, "r": r, "color": color})

func _draw() -> void:
	if not debug_draw: return
	# Convert global → local so CanvasItem drawing is correct.
	for seg in _dbg_lines:
		var a := to_local(seg.a)
		var b := to_local(seg.b)
		draw_line(a, b, seg.color, seg.w, true)
	for dot in _dbg_points:
		draw_circle(to_local(dot.p), dot.r, dot.color)
#End debug

func lightDirection(inclight_pos: Vector2, globalPoint: Vector2, poly: CollisionPolygon2D, _mask := 0b00010010) -> bool:
	
	var space := poly.get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(inclight_pos, globalPoint)
	params.collision_mask = 0b00010010
	params.collide_with_areas = true
	params.collide_with_bodies = true

	# Base intent line (light → target), will recolor/overlay after raycast
	_dbg_add_line(inclight_pos, globalPoint, Color(1, 1, 1, 0.25))
	
	# ✅ NEW: draw the intended target (globalPoint) as a blue marker
	_dbg_add_point(globalPoint, 5.0, Color(0.2, 0.6, 1.0))

	var lightHit := space.intersect_ray(params)

	if lightHit.is_empty():
		# Clear path
		_dbg_add_line(inclight_pos, globalPoint, Color(0.1, 1.0, 0.1, 0.9)) # green
		return true

	# Blocked: draw red up to the hit, gray after
	var hit_pos: Vector2 = lightHit.position
	_dbg_add_line(inclight_pos, hit_pos, Color(1.0, 0.2, 0.2, 0.95))       # red to first hit
	_dbg_add_line(hit_pos, globalPoint, Color(0.7, 0.7, 0.7, 0.6))      # gray from hit → target
	_dbg_add_point(hit_pos, 4.0, Color(1, 0.2, 0.2))                    # hit marker

	var d_hit_sq := inclight_pos.distance_squared_to(hit_pos)
	var d_point_sq := inclight_pos.distance_squared_to(globalPoint)
	return d_point_sq <= d_hit_sq + 1e-6

func _ready():
	var visual_polygon = Polygon2D.new()
	add_child(visual_polygon)
	visual_polygon.polygon = collision_polygon.polygon
	visual_polygon.transform = collision_polygon.transform
	visual_polygon.color = Color(0.3, 0.7, 1, 0.3)
	visual_polygon.scale = collision_polygon.scale
	visual_polygon.z_index = 1
	input_pickable = true
	

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Decide whether this is a drag or a rotation based on Shift
			if Input.is_key_pressed(KEY_SHIFT):
				rotating = true
				dragging = false
				# angle from lens center to mouse, store offset so rotation doesn't snap
				var mouse_angle := (get_global_mouse_position() - global_position).angle()
				rotation_offset = global_rotation - mouse_angle
			else:
				dragging = true
				rotating = false
				drag_offset = global_position - get_global_mouse_position()
		else:
			# stop both on mouse release
			dragging = false
			rotating = false

func _process(_delta):

	# Allow switching modes mid-drag by pressing/releasing Shift
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var shift_down := Input.is_key_pressed(KEY_SHIFT)
		if shift_down and dragging:
			# switch to rotate
			dragging = false
			rotating = true
			var mouse_angle := (get_global_mouse_position() - global_position).angle()
			rotation_offset = global_rotation - mouse_angle
			
			
		elif (not shift_down) and rotating:
			# switch back to translate
			rotating = false
			dragging = true
			drag_offset = global_position - get_global_mouse_position()
	# --- DEBUG: clear last frame ---
	_dbg_lines.clear()
	_dbg_points.clear()
	if (lightDirection(light_pos, polySide.global_position, collision_polygon) == true):
		focalMark.position.y = greenLight
	else:
		focalMark.position.y = redLight
	queue_redraw()
	# --------------------------------
	# (rest of your _process stays the same)

	# Apply motion
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
	elif rotating:
		var mouse_angle := (get_global_mouse_position() - global_position).angle()
		global_rotation = rotation_offset + mouse_angle

	for node in get_tree().get_nodes_in_group("rays"):
		if node.has_method("getResult"):
			var results = node.getResult()
			lensActive(colCount(results))

	if focal_positions.is_empty():
		return
	var domSide: Vector2 = Vector2.ZERO
	for side in side_dirs:
		domSide += side
	domSide = domSide.normalized()

	var domPositions: Array = []
	for i in range(focal_positions.size()):
		var dir = side_dirs[i]
		if dir.dot(domSide) > 0.4:
			domPositions.append(focal_positions[i])

	if domPositions.size() > 0:
		var avgPosition: Vector2 = Vector2.ZERO
		for pos in domPositions:
			avgPosition += pos
		focalMark.global_position = avgPosition / domPositions.size()
	focal_positions.clear()
	side_dirs.clear()

func colCount(result):
	var raylensCount = 0
	for i in result:
		if i.collider.name.begins_with("convexLens"):
			raylensCount += 1
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
	var query := PhysicsRayQueryParameters2D.create(center, focal_pos)
	query.exclude = [self]
	query.collision_mask = 1 << 1
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty()

func _ray_segment_intersection(ray_o: Vector2, ray_dir: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var seg = b - a
	var denom = _cross(ray_dir, seg)
	if abs(denom) < 1e-6:
		return {}
	var ao = a - ray_o
	var t = _cross(ao, seg) / denom
	var u = _cross(ao, ray_dir) / denom
	if t >= 0.0 and u >= 0.0 and u <= 1.0:
		return {"pos": ray_o + ray_dir * t, "t": t, "u": u}
	return {}

func interact_with_ray(hit_pos: Vector2, _incoming_dir: Vector2, _rayIdx: int, _angle: float) -> Dictionary:

	return {
		"start": hit_pos,
		"end": focalMark.global_position,
		"color": Color(0.3, 0.7, 1)
		
	}
