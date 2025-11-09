func _on_target_entered(body: Node2D) -> void:
	"""Called when a potential target enters detection range"""
	if not data.is_defensive_structure:
		return
	
	# Add to targets list
	if body not in targets_in_range:
		targets_in_range.append(body)
	
	# If we don't have a current target, start attacking this one
	if not current_target and targets_in_range.size() > 0:
		_select_target()

func _on_target_exited(body: Node2D) -> void:
	"""Called when a target leaves detection range"""
	# Remove from targets list
	targets_in_range.erase(body)
	
	# If this was our current target, find a new one
	if current_target == body:
		current_target = null
		_select_target()

func _select_target() -> void:
	"""Select the closest valid target from the targets_in_range array"""
	if targets_in_range.is_empty():
		current_target = null
		attack_timer.stop()
		return
	
	# Find closest target
	var closest_target: Node2D = null
	var closest_distance: float = INF
	
	for target in targets_in_range:
		if is_instance_valid(target):
			var distance = global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
		else:
			# Remove invalid targets
			targets_in_range.erase(target)
	
	current_target = closest_target
	if current_target:
		# Start attacking
		if attack_timer.is_stopped():
			attack_timer.start()

func _on_attack_timer_timeout() -> void:
	"""Called when the attack timer fires"""
	if not data.is_defensive_structure or not current_target:
		return
	
	# Verify target is still valid and in range
	if not is_instance_valid(current_target):
		_select_target()
		return
	
	var distance_to_target = global_position.distance_to(current_target.global_position)
	if distance_to_target > data.attack_range:
		_select_target()
		return
	
	# Attack the target
	if data.projectile_scene:
		# RANGED: Spawn projectile
		_spawn_projectile(current_target.global_position)
	else:
		# MELEE: Direct damage (buildings shouldn't typically do this, but included for completeness)
		if current_target.has_method("take_damage"):
			current_target.take_damage(data.attack_damage)

func _spawn_projectile(target_position_world: Vector2) -> void:
	"""Spawn a projectile towards the target position"""
	if not data.projectile_scene:
		print("Error: No projectile scene assigned to %s" % data.display_name)
		return
	
	# Create the projectile
	var projectile: Projectile = data.projectile_scene.instantiate()
	if not projectile:
		print("Error: Failed to instantiate projectile for %s" % data.display_name)
		return
	
	# Add projectile to the current scene
	get_tree().current_scene.add_child(projectile)
	
	# Set up collision mask to hit player units (Layer 2)
	var player_collision_mask: int = 1 << 1  # Layer 2 (bit position 1)
	
	# Initialize the projectile
	projectile.setup(
		global_position,        # start position
		target_position_world,  # target position
		data.attack_damage,     # damage
		400.0,                  # projectile speed
		player_collision_mask   # what to hit
	)
