extends Area2D

## Minimum number of rays required to trigger the detector
@export var required_ray_count: int = 10
## List of light source IDs that this detector responds to (empty = all sources)
@export var allowed_source_ids: Array[int] = []
## Whether the detector is currently active (has enough rays hitting it)
var is_active: bool = false

signal activated
signal deactivated

func _ready() -> void:
	# Ensure we have a collision shape
	if not has_node("CollisionShape2D"):
		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(50, 50)
		add_child(shape)

	# Ensure the indicator exists (scene supplies one); if not, create a fallback
	if not has_node("Indicator"):
		var poly = Polygon2D.new()
		poly.name = "Indicator"
		poly.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
		poly.color = Color(1, 0, 0, 0.8)
		add_child(poly)

	# Align the indicator to the CollisionShape2D (position & size)
	_align_indicator_to_shape()

	add_to_group("detectors")

func interact_with_ray(_hit_pos: Vector2, _incoming_dir: Vector2, _ray: RayState, _surface_normal: Vector2) -> Dictionary:
	# Detector absorbs rays - no reflection or refraction
	return {}

func on_ray_batch_stats(stats: Dictionary) -> void:
	var total_ray_count = 0
	if allowed_source_ids.is_empty():
		# Count rays from all sources
		for source_stats in stats.values():
			total_ray_count += source_stats.get("count", 0)
	else:
		# Count rays only from allowed sources
		for source_id in allowed_source_ids:
			if stats.has(source_id):
				total_ray_count += stats[source_id].get("count", 0)

	var was_active = is_active
	is_active = total_ray_count >= required_ray_count

	if is_active and not was_active:
		activated.emit()
		_set_indicator(true)
	elif not is_active and was_active:
		deactivated.emit()
		_set_indicator(false)


func _set_indicator(active: bool) -> void:
	var ind = get_node_or_null("Indicator")
	if ind and ind is Polygon2D:
		if active:
			ind.color = Color(0, 1, 0, 0.8)
		else:
			ind.color = Color(1, 0, 0, 0.8)


func _align_indicator_to_shape() -> void:
	var ind = get_node_or_null("Indicator")
	var cs = get_node_or_null("CollisionShape2D")
	if not ind or not cs:
		return

	# Position the indicator where the collision shape is placed
	ind.position = cs.position

	# Try to read a rectangular size from the shape (supporting either 'size' or 'extents')
	var shape = cs.shape
	var rect_size := Vector2(32, 32)
	if shape:
		var maybe_size = shape.get("size") if shape.has_method("get") else null
		if typeof(maybe_size) == TYPE_VECTOR2:
			rect_size = maybe_size
		else:
			var maybe_extents = shape.get("extents") if shape.has_method("get") else null
			if typeof(maybe_extents) == TYPE_VECTOR2:
				rect_size = maybe_extents * 2

	# Build a rectangle polygon centered at origin with the detected size
	var half = rect_size * 0.5
	ind.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
