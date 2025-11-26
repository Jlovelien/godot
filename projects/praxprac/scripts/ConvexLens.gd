extends Area2D

var dragging := false
var rotating := false
var drag_offset: Vector2
var rotation_offset := 0.0

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var focalMark: Marker2D
@onready var focalMark2: Marker2D

@export var ray_threshold: int = 12          # how many rays to "activate" lens
@export var beam_length: float = 600.0
@export var debug_draw: bool = false
@export var focal_offset: Vector2 = Vector2(0, 100)

var fl: AnimatedSprite2D = null              # optional focal animation

# Debug drawing
var _dbg_lines: Array = []
var _dbg_points: Array = []

func _ready() -> void:
	# simple translucent visual for the lens
	var visual_polygon := Polygon2D.new()
	add_child(visual_polygon)
	visual_polygon.polygon = collision_polygon.polygon
	visual_polygon.transform = collision_polygon.transform
	visual_polygon.color = Color(0.3, 0.7, 1.0, 0.3)
	visual_polygon.scale = collision_polygon.scale
	visual_polygon.z_index = 1
	input_pickable = true

	# First focal mark
	focalMark = Marker2D.new()
	collision_polygon.add_child(focalMark)
	focalMark.position = focal_offset

	# Second focal mark
	focalMark2 = Marker2D.new()
	collision_polygon.add_child(focalMark2)
	focalMark2.position = -focal_offset

	# Optional: animated focal sprite
	fl = AnimatedSprite2D.new()
	focalMark.add_child(fl)
	fl.visible = false
	fl.sprite_frames = preload("res://assets/animations/convexLight.tres")

func _input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Input.is_key_pressed(KEY_SHIFT):
				rotating = true
				dragging = false
				var mouse_angle := (get_global_mouse_position() - global_position).angle()
				rotation_offset = global_rotation - mouse_angle
			else:
				dragging = true
				rotating = false
				drag_offset = global_position - get_global_mouse_position()
		else:
			dragging = false
			rotating = false

func _process(_delta: float) -> void:
	# allow switching drag/rotate mid-drag via Shift
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var shift_down := Input.is_key_pressed(KEY_SHIFT)
		if shift_down and dragging:
			dragging = false
			rotating = true
			var mouse_angle := (get_global_mouse_position() - global_position).angle()
			rotation_offset = global_rotation - mouse_angle
		elif (not shift_down) and rotating:
			rotating = false
			dragging = true
			drag_offset = global_position - get_global_mouse_position()

	# motion
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
	elif rotating:
		var mouse_angle := (get_global_mouse_position() - global_position).angle()
		global_rotation = rotation_offset + mouse_angle

	_dbg_lines.clear()
	_dbg_points.clear()
	queue_redraw()

func _draw() -> void:
	if not debug_draw:
		return

	for seg in _dbg_lines:
		draw_line(
			to_local(seg["a"]),
			to_local(seg["b"]),
			seg["color"],
			seg["w"],
			true
		)
	for dot in _dbg_points:
		draw_circle(to_local(dot["p"]), dot["r"], dot["color"])

func _dbg_add_line(a: Vector2, b: Vector2, color: Color, w: float = 2.0) -> void:
	if not debug_draw:
		return
	_dbg_lines.append({"a": a, "b": b, "color": color, "w": w})

func _dbg_add_point(p: Vector2, r: float = 4.0, color: Color = Color(1, 0, 0)) -> void:
	if not debug_draw:
		return
	_dbg_points.append({"p": p, "r": r, "color": color})

# --------------------------------------------------------------------
# Batch stats from emitter: called once per frame if this lens was hit
# --------------------------------------------------------------------
func on_ray_batch_stats(stats: Dictionary) -> void:
	var count: int = stats["count"]
	var positions: Array = stats["positions"]

	var active := count >= ray_threshold
# 	_set_lens_active(active)

# func _set_lens_active(active: bool) -> void:
# 	if fl == null:
# 		return
# 	fl.visible = active
# 	if active:
# 		fl.play()
# 	else:
# 		fl.stop()

# --------------------------------------------------------------------
# Per-ray logic: how the lens transforms the incoming ray
# --------------------------------------------------------------------
func interact_with_ray(
	hit_pos: Vector2,
	incoming_dir: Vector2,
	_ray: RayState,
	_surface_normal: Vector2
) -> Dictionary:
	# Basic convex lens: bend ray toward the appropriate focal point based on hit side (top/bottom)
	var local_hit = to_local(hit_pos)
	var focal_pos: Vector2
	if local_hit.y <= 0:
		focal_pos = focalMark.global_position
	else:
		focal_pos = focalMark2.global_position
	var out_dir: Vector2 = (focal_pos - hit_pos).normalized()

	_dbg_add_line(hit_pos, focal_pos, Color(0.3, 0.7, 1.0), 2.0)
	_dbg_add_point(hit_pos, 4.0, Color(1, 0.5, 0.2))

	var seg_len := beam_length

	return {
		"segments": [
			{
				"start": hit_pos,
				"end": hit_pos + out_dir * seg_len,
				"color": Color(0.3, 0.7, 1.0)
			}
		],
		"rays": [
			{
				"origin": hit_pos,
				"dir": out_dir,
				"color": Color(0.3, 0.7, 1.0),
				"offset_depth": 1
			}
		]
	}
