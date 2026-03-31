extends CharacterBody2D

@onready var pillSpri: Sprite2D = $pillarSprite
@onready var pillCol: CollisionShape2D = $pillarCollide
@export var growth_factor: float = 0.25  # Additive growth per press

var _initial_spri_scale: Vector2
var _initial_col_scale: Vector2
var _scale_ratio: float
var _is_detected: bool = false

func _ready() -> void:
	_initial_spri_scale = pillSpri.scale
	_initial_col_scale = pillCol.scale
	_scale_ratio = _initial_col_scale.y / _initial_spri_scale.y  # Ratio of their Y scales

func _is_detected_by_player() -> bool:
	# Find the Player node directly (it's nested in the scene tree)
	var player = get_tree().root.find_child("Player", true, false)
	if player and "object_hovering" in player:
		return self in player.object_hovering
	return false

func _physics_process(delta: float) -> void:
	# Update detection status every frame
	_is_detected = _is_detected_by_player()
	
	#Grow pillar logic
	if Input.is_action_just_pressed("grow") and _is_detected:
		pillSpri.scale.y += growth_factor
		pillCol.scale.y += growth_factor * _scale_ratio  # Scale growth by the ratio
		# Move parent up by half the height change to anchor growth at the bottom
		var height_change = growth_factor * pillSpri.get_rect().size.y
		global_position.y -= height_change / 2
	if Input.is_action_just_pressed("shrink") and _is_detected:
		pillSpri.scale.y -= growth_factor
		pillCol.scale.y -= growth_factor * _scale_ratio  # Scale growth by the ratio
		# Move parent down by half the height change
		var height_change = growth_factor * pillSpri.get_rect().size.y
		global_position.y += height_change / 2
		
