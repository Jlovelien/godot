extends CharacterBody2D


const SPEED = 120.0
const JUMP_VELOCITY = -350.0
@onready var anim: AnimatedSprite2D = $Anim2D
@onready var spawn_point := $lightSpawn
@onready var projectile_scene := preload("res://scenes/shootLight.tscn")
@export var shoot_cooldown := 0.2
var _can_shoot := true
var facing := 1
@export var default_spawn_offset := 24.0
var _spawn_offset_x := 0.0

func _physics_process(delta: float) -> void:

	# light shooting
	if Input.is_action_just_pressed("shoot") and _can_shoot:
		if projectile_scene != null and spawn_point != null:
			_can_shoot = false
			var p = projectile_scene.instantiate()
			p.global_position = spawn_point.global_position
			# Add immediately so the projectile's get_tree() is valid when set_direction runs
			get_tree().current_scene.add_child(p)
			if p.has_method("set_direction"):
				p.set_direction(Vector2(facing, 0))
			# cooldown
			await get_tree().create_timer(shoot_cooldown).timeout
			_can_shoot = true
			
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("spacebar") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

	# On ground: run vs idle
	if velocity.x > 0:
		facing = 1
		_play_loop("moveRight")
	elif velocity.x < 0:
		facing = -1
		_play_loop("moveLeft")
	else:
		_play_loop("idle")

	# Update spawn marker local X based on facing
	if spawn_point != null:
		spawn_point.position = Vector2(_spawn_offset_x * facing, spawn_point.position.y)

func _play_loop(name: String) -> void:
	if anim.animation != name or not anim.is_playing():
		anim.play(name)

func _play_once(name: String) -> void:
	if anim.animation != name or not anim.is_playing():
		anim.play(name)  # if your "jump" is non-looping in the SpriteFrames, this will play once

# Death border trigger
func _on_area_2d_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()

func _ready() -> void:
	# capture default spawn offset for flipping
	if spawn_point != null:
		_spawn_offset_x = spawn_point.position.x
		# If the spawn marker is at (0,0) in the player's local space, try deriving
		# an offset from global positions. Fall back to exported default if still 0.
		if abs(_spawn_offset_x) < 0.001:
			var derived: float = spawn_point.global_position.x - global_position.x
			if abs(derived) > 0.001:
				_spawn_offset_x = derived
			else:
				_spawn_offset_x = default_spawn_offset
		# ensure the marker starts on the correct side
		spawn_point.position = Vector2(_spawn_offset_x * facing, spawn_point.position.y)
