extends Node2D

@onready var mirrorFront: StaticBody2D = $mirrorFront
@onready var mirrorBack: StaticBody2D = $mirrorBack

@export var segment_length: float = 400.0

func _process(_delta: float) -> void:
	# Turn mirror 90 degrees right / left
	if Input.is_action_just_pressed("rotateRight"):
		rotation_degrees += 90.0
	if Input.is_action_just_pressed("rotateLeft"):
		rotation_degrees -= 90.0
