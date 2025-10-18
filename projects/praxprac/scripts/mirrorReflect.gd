extends Area2D

func _process(_delta):
	# Turn mirror 90 degrees right
	if Input.is_action_just_pressed("rotateRight"):
		self.rotation_degrees += 90
	if Input.is_action_just_pressed("rotateLeft"):
		self.rotation_degrees -= 90
		
		
		
		#var shift_down := Input.is_key_pressed(KEY_SHIFT)
		#if shift_down and dragging:
			## switch to rotate
			#dragging = false
			#rotating = true
			#var mouse_angle := (get_global_mouse_position() - global_position).angle()
			#rotation_offset = global_rotation - mouse_angle
			#
			#
		#elif (not shift_down) and rotating:
			## switch back to translate
			#rotating = false
			#dragging = true
			#drag_offset = global_position - get_global_mouse_position()
	## --- DEBUG: clear last frame ---
	#_dbg_lines.clear()
	#_dbg_points.clear()
	#if (lightDirection(light_pos, polySide.global_position, collision_polygon) == true):
		#focalMark.position.y = greenLight
	#else:
		#focalMark.position.y = redLight
	#queue_redraw()
	## --------------------------------
	## (rest of your _process stays the same)
#
	## Apply motion
	#if dragging:
		#global_position = get_global_mouse_position() + drag_offset
	#elif rotating:
		#var mouse_angle := (get_global_mouse_position() - global_position).angle()
		#global_rotation = rotation_offset + mouse_angle
#
	#for node in get_tree().get_nodes_in_group("rays"):
		#if node.has_method("getResult"):
			#var results = node.getResult()
			#lensActive(colCount(results))
#
	#if focal_positions.is_empty():
		#return
	#var domSide: Vector2 = Vector2.ZERO
	#for side in side_dirs:
		#domSide += side
	#domSide = domSide.normalized()
#
	#var domPositions: Array = []
	#for i in range(focal_positions.size()):
		#var dir = side_dirs[i]
		#if dir.dot(domSide) > 0.4:
			#domPositions.append(focal_positions[i])
#
	#if domPositions.size() > 0:
		#var avgPosition: Vector2 = Vector2.ZERO
		#for pos in domPositions:
			#avgPosition += pos
		#focalMark.global_position = avgPosition / domPositions.size()
	#focal_positions.clear()
	#side_dirs.clear()

#TODO calculate mirror angle
func interact_with_ray(hit_pos: Vector2, incoming_dir: Vector2, rayIdx: int, angle: float) -> Dictionary:
	
	var surface_normal = Vector2(cos(angle + PI/2), sin(angle + PI/2))
	
	var in_dir := incoming_dir.normalized()
	var normal := surface_normal.normalized()
	
	# Make sure the normal faces against the incoming ray
	if in_dir.dot(normal) > 0.0:
		normal = -normal
		
	# Reflect the ray using the built-in bounce() method
	var reflected_dir := in_dir.bounce(normal)
	
		# Choose how far to draw/trace the reflected beam
	var reflection_length := 400.0
	var end_point := hit_pos + reflected_dir * reflection_length

	return {
		"start": hit_pos,
		"end": end_point,
		"color": Color(0.3, 0.7, 1)
	}
