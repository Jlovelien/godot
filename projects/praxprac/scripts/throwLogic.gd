extends Node
class_name throwLogic

@export var friction_lerp_weight: float = 30.0
@export var position_lerp_weight: float = 200.0
@export var gravity: float = 500.0
@export var bounce_amt: float = 20.0
@export var total_bounces: int = 1
@export var hold_offset: Vector2 = Vector2(0, -17)  # Visible offset for sprite/collider when held

var y_velocity: float = 0.0
var x_velocity: float = 0.0
var held_by: Node2D = null

# runtime reparenting support for visual alignment
var _sprite_orig_parent: Node = null
var _sprite_orig_local_pos: Vector2 = Vector2.ZERO
var _sprite_visual_anchor: Node2D = null
var _printed_hold_once: bool = false
var _collider_orig_local_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	var parent = get_parent()
	parent.add_to_group("can_pickup")
	
func _physics_process(delta: float) -> void:
	if held_by:
		get_parent().velocity = Vector2.ZERO
		var target_pos: Vector2 = held_by.global_position + hold_offset
		var sprite := get_parent().get_node_or_null("pillarSprite")
		var collider := get_parent().get_node_or_null("pillarCollide")
		var t: float = clamp(position_lerp_weight * delta, 0.0, 1.0)
		print("HOLD:", get_parent().name, "parent_pos=", get_parent().global_position, "->", target_pos, "t=", t, "holder_pos=", held_by.global_position, "sprite_global=", sprite.global_position if sprite else null, "collider_global=", collider.global_position if collider else null)
		# one-shot misalignment debug
		if not _printed_hold_once:
			var child_global: Vector2 = sprite.global_position if sprite else (collider.global_position if collider else get_parent().global_position)
		get_parent().global_position = get_parent().global_position.lerp(target_pos, t)
	else:
		get_parent().velocity.x = lerp(get_parent().velocity.x, x_velocity, friction_lerp_weight*delta)
		get_parent().velocity.y += gravity * delta
		get_parent().move_and_slide()
		
		if get_parent().is_on_floor(): #bounce on ground
			if y_velocity > 0.0:
				y_velocity -= bounce_amt / total_bounces
				get_parent().velocity.y = -y_velocity
			else:
				x_velocity = 0.0
		elif get_parent().is_on_wall(): #bounce on wall (CHANGED TO 0)
			x_velocity = 0
		
		if get_parent().is_on_floor() and get_parent().velocity.length() < 5.0:
			y_velocity = 0.0
			x_velocity = 0.0
	
func pickup(holder: Node2D) -> void:
	held_by = holder
	get_parent().velocity = Vector2.ZERO
	var sprite := get_parent().get_node_or_null("pillarSprite")
	var collider := get_parent().get_node_or_null("pillarCollide")
	var desired_global: Vector2 = holder.global_position + hold_offset
	print("PICKUP BEFORE: parent=", get_parent().name, "parent_pos=", get_parent().global_position, "sprite_global=", sprite.global_position if sprite else null, "collider_global=", collider.global_position if collider else null, "desired_global=", desired_global)
	# Move parent and adjust sprite so the visible sprite lands at desired_global
	if sprite:
		# Save original local position and snap sprite to local (0,0) so its global is the parent's global
		_sprite_orig_local_pos = sprite.position
		sprite.position = Vector2.ZERO
		get_parent().global_position = desired_global
		get_parent().z_index = holder.z_index + 1
		sprite.visible = true
	elif collider:
		var delta: Vector2 = desired_global - collider.global_position
		get_parent().global_position += delta
	else:
		get_parent().global_position = desired_global
	# save and move collider so it stays under the visible sprite while held
	if collider:
		_collider_orig_local_pos = collider.position
		collider.position = Vector2.ZERO
	print("PICKUP AFTER: parent_pos=", get_parent().global_position, "sprite_global=", sprite.global_position if sprite else null, "collider_global=", collider.global_position if collider else null, "holder_pos=", holder.global_position)
	
func drop(global_pos: Vector2) -> void:
	held_by = null
	# restore visual sprite parent if we reparented it
	if _sprite_visual_anchor:
		var sprite_in_anchor := _sprite_visual_anchor.get_node_or_null("pillarSprite")
		if sprite_in_anchor and _sprite_orig_parent:
			_sprite_visual_anchor.remove_child(sprite_in_anchor)
			_sprite_orig_parent.add_child(sprite_in_anchor)
			sprite_in_anchor.position = _sprite_orig_local_pos
		# remove anchor
		_sprite_visual_anchor.queue_free()
		_sprite_visual_anchor = null
		_sprite_orig_parent = null
		_sprite_orig_local_pos = Vector2.ZERO

	var pos_tween: Tween = create_tween().set_trans(Tween.TRANS_SINE) #SINE is a "smooth" transition. Change options as needed
	pos_tween.tween_property(get_parent(), "global_position", global_pos, 0.05)  #Tweak to change increase animation time
	# When the tween finishes, align & enable collider at the final global position
	pos_tween.tween_callback(Callable(self, "_on_drop_tween_finished"))
	get_parent().velocity = Vector2.ZERO
	var sprite := get_parent().get_node_or_null("pillarSprite")
	var collider := get_parent().get_node_or_null("pillarCollide")
	if sprite:
		# Reset sprite to center and keep collider aligned with parent
		sprite.position = Vector2.ZERO
		_sprite_orig_local_pos = Vector2.ZERO
		# Shift collider down by half sprite height to keep pillar on ground
		if collider and sprite.texture:
			var sprite_height = sprite.texture.get_height() * sprite.scale.y
			collider.position.y = sprite_height / 2.0
		print("DROP: sprite_global=", sprite.global_position, "visible=", sprite.visible)
	
func throw(throw_x: float, throw_height: float) -> void:
	# restore visuals/collider similar to drop
	held_by = null
	# restore visual sprite parent if we had an anchor
	if _sprite_visual_anchor:
		var sprite_in_anchor := _sprite_visual_anchor.get_node_or_null("pillarSprite")
		if sprite_in_anchor and _sprite_orig_parent:
			_sprite_visual_anchor.remove_child(sprite_in_anchor)
			_sprite_orig_parent.add_child(sprite_in_anchor)
			sprite_in_anchor.position = _sprite_orig_local_pos
		# remove anchor
		_sprite_visual_anchor.queue_free()
		_sprite_visual_anchor = null
		_sprite_orig_parent = null
		_sprite_orig_local_pos = Vector2.ZERO

	var sprite := get_parent().get_node_or_null("pillarSprite")
	var collider := get_parent().get_node_or_null("pillarCollide")
	# align collider now so it doesn't fall through on throw
	if collider:
		collider.position = Vector2.ZERO
		collider.disabled = false
	if sprite:
		# keep the sprite centered on the pillar at throw (don't restore original offset immediately)
		sprite.position = Vector2.ZERO
		_sprite_orig_local_pos = Vector2.ZERO

	# apply throw velocity
	get_parent().velocity = Vector2(throw_x, throw_height)
	y_velocity = bounce_amt
	x_velocity = throw_x

func _on_drop_tween_finished() -> void:
	var collider := get_parent().get_node_or_null("pillarCollide")
	if collider:
		# Keep collider aligned with parent global position
		collider.position = Vector2.ZERO
		
#func _debug_state(prefix: String = "") -> void:
