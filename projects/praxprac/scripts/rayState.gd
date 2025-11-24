extends RefCounted
class_name RayState

var origin: Vector2
var dir: Vector2
var color: Color
var depth: int
var idx: int
var angle: float

func _init(
	origin: Vector2,
	dir: Vector2,
	color: Color,
	depth: int,
	idx: int,
	angle: float
) -> void:
	self.origin = origin
	self.dir = dir
	self.color = color
	self.depth = depth
	self.idx = idx
	self.angle = angle
