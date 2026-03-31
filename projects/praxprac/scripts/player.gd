extends CharacterBody2D

#Movement
const RIGHT_STICK_X = 2
const RIGHT_STICK_Y = 3
const SPEED = 120.0
const JUMP_VELOCITY = -350.0

#Shooting
@onready var anim: AnimatedSprite2D = $Anim2D
@onready var spawn_point := $lightSpawn
@onready var projectile_scene := preload("res://scenes/shootLight.tscn")
@export var shoot_cooldown := 0.2
var _can_shoot := true
var facing := 1
@export var default_spawn_offset := 24.0
var _spawn_offset_x := 0.0

#Throwing
var OBJECT_THROW_STRENGTH: float = 150.0
var object_hovering: Array[Node2D] = []
var held_object: Node2D = null
var look_dir_x: int = 1
@onready var pillar_detect: Area2D = $pillarDetect

func _get_aim_direction() -> Vector2:
	var rx = Input.get_action_strength("aim_right") - Input.get_action_strength("aim_left")
	var ry = Input.get_action_strength("aim_down") - Input.get_action_strength("aim_up")
	var dir = Vector2(rx, ry)
	if dir.length() > 0.01:
		return dir.normalized()
	# Final fallback (no input)
	return Vector2(facing, 0)

func _get_throw_direction() -> Vector2:
	# Check right stick input for 360-degree aiming
	var rx = Input.get_action_strength("aim_right") - Input.get_action_strength("aim_left")
	var ry = Input.get_action_strength("aim_down") - Input.get_action_strength("aim_up")
	var dir = Vector2(rx, ry)  # Negate y so up is negative (standard screen coords)
	
	if dir.length() > 0.01:
		return dir.normalized()
	# Fallback to last movement direction if no right stick input
	return Vector2(look_dir_x, 0)

func _physics_process(delta: float) -> void:

	# light shooting
	if Input.is_action_pressed("shoot") and _can_shoot:
		if projectile_scene != null and spawn_point != null:
			var p = projectile_scene.instantiate()
			p.global_position = spawn_point.global_position
			# Add immediately so the projectile's get_tree() is valid when set_direction runs
			get_tree().current_scene.add_child(p)
			if p.has_method("set_direction"):
				p.set_direction(_get_aim_direction())
			
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("spacebar") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, replace UI actions with custom gameplay actions.
	
	# Movement and look direction (use input for immediate responsiveness)
	var direction := Input.get_axis("move_left", "move_right")
	# Prefer input direction so look_dir_x updates instantly when the player taps a direction
	if direction:
		look_dir_x = sign(direction)
	elif velocity.x != 0:
		look_dir_x = sign(velocity.x)
	# Movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

	# Sync object_hovering with what's currently overlapping the detection area
	if pillar_detect:
		var overlapping_bodies = pillar_detect.get_overlapping_bodies()
		# Add any new bodies that are in group "can_pickup" and not held
		for body in overlapping_bodies:
			if body.is_in_group("can_pickup") and body != held_object:
				if not object_hovering.has(body):
					object_hovering.push_front(body)
		# Remove any bodies that are no longer overlapping
		for body in object_hovering:
			if not overlapping_bodies.has(body):
				object_hovering.erase(body)

	# On ground: run vs idle
	if velocity.x > 0:
		facing = 1
		_play_loop("moveRight")
	elif velocity.x < 0:
		facing = -1
		_play_loop("moveLeft")
	else:
		_play_loop("idle")

	#Pickup pillar logic
	if Input.is_action_just_pressed("pickUp"):
		if object_hovering.size() > 0:
			var object = object_hovering[0]
			if not held_object: # Empty hands, pick up object
				held_object = object
				object_hovering.erase(object)
				object.get_node("throwLogic").pickup(self)
			elif held_object and object != held_object: # swap objects
				held_object.get_node("throwLogic").drop(global_position)
				held_object = object
				object_hovering.erase(object)
				object.get_node("throwLogic").pickup(self)
		else:
			# No object under player. If we're holding one, drop or throw it.
			if held_object:
				if Input.is_action_pressed("doNotThrow"):
					held_object.get_node("throwLogic").drop(global_position)
					held_object = null
				else:
					# throw with 360-degree aiming
					var throw_direction = _get_throw_direction()
					var throw_velocity = throw_direction * OBJECT_THROW_STRENGTH
					print("PLAYER: throwing held object", held_object.name, "throw=", throw_velocity)
					held_object.get_node("throwLogic").throw(throw_velocity.x, throw_velocity.y)
					held_object = null

	# Down d-pad "doNotThrow" drops block
	if Input.is_action_just_pressed("doNotThrow"):
		if held_object:
			held_object.get_node("throwLogic").drop(global_position)
			held_object = null

	# Update spawn marker local X based on facing
	if spawn_point != null:
		spawn_point.position = Vector2(_spawn_offset_x * facing, spawn_point.position.y)

func _play_loop(loopName: String) -> void:
	if anim.animation != loopName or not anim.is_playing():
		anim.play(loopName)

func _play_once(onceName: String) -> void:
	if anim.animation != onceName or not anim.is_playing():
		anim.play(onceName)  # if your "jump" is non-looping in the SpriteFrames, this will play once

## Death border trigger
#func _on_area_2d_body_entered(body: Node2D) -> void:
	#get_tree().reload_current_scene()

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


func _on_pillar_detect_body_entered(body: Node2D) -> void:
	# Handled by continuous sync in _physics_process now, but keep for backwards compatibility
	if body.is_in_group("can_pickup"):
		print("PILLAR ENTERED:", body.name, "in_group_can_pickup=", body.is_in_group("can_pickup"))

func _on_pillar_detect_body_exited(body: Node2D) -> void:
	# Handled by continuous sync in _physics_process now
	if body.is_in_group("can_pickup"):
		print("PILLAR EXITED:", body.name)
