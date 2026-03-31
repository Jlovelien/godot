extends RefCounted
class_name RayState

var origin: Vector2
var dir: Vector2
var color: Color
var depth: int
var idx: int
var angle: float
var source_id: int
var interacted_objects: Array[Object] = []

func _init(
	origin: Vector2,
	dir: Vector2,
	color: Color,
	depth: int,
	idx: int,
	angle: float,
	source_id: int
) -> void:
	self.origin = origin
	self.dir = dir
	self.color = color
	self.depth = depth
	self.idx = idx
	self.angle = angle
	self.source_id = source_id
	self.interacted_objects = []
