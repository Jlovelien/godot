extends Area2D

## Minimum number of rays required to trigger the detector
@export var required_ray_count: int = 5
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
		print("Detector activated!")
		activated.emit()
	elif not is_active and was_active:
		print("Detector deactivated!")
		deactivated.emit()
