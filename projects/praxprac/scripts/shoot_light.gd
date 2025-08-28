extends Node2D

@export var projectile_scene: PackedScene
@export var spawn_point: Node2D

# Export_range Adds a UI slider you can adjust
@export_range(0.0, 2.0, 0.01) var cooldown := 0.2
@export_range(0.0, 1200.0, 1.0) var speed := 200.0
@export_range(0.1, 10.0, 0.1) var lifetime := 1.0

var _can_shoot := true

# velocity for instances that are used as projectiles
var _velocity: Vector2 = Vector2.ZERO

func try_shoot(facing: int) -> void:
	# spawn a projectile (projectile_scene should be a PackedScene)
	if not _can_shoot or projectile_scene == null:
		return
	_can_shoot = false
	var p := projectile_scene.instantiate()
	var start := (spawn_point if spawn_point else self)
	p.global_position = start.global_position
	if p.has_method("set_direction"):
		p.set_direction(Vector2(facing, 0))
	get_tree().current_scene.add_child(p)
	# cooldown
	await get_tree().create_timer(cooldown).timeout
	_can_shoot = true

func set_direction(dir: Vector2) -> void:
	# Configure this instance as a moving projectile
	_velocity = dir.normalized() * speed
	# schedule free after lifetime using SceneTree timer (already started and in tree)
	_schedule_free()

func _schedule_free() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if _velocity != Vector2.ZERO:
		position += _velocity * delta
