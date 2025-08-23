extends Node2D

@export var projectile_scene: PackedScene
@export var spawn_point: Node2D
@export var cooldown := 0.2

var _can_shoot := true

func try_shoot(facing: int) -> void:
	print(spawn_point)
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
