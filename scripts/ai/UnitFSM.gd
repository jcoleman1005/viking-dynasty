# res://scripts/ai/UnitFSM.gd
# Refactored UnitFSM for Phase 3 RTS commands
# Now uses modular AttackAI component for attacking behavior
#
# --- REFACTORED ---
# Fixed Friendly Fire bug in _find_closest_blocking_building.
# Units now respect their collision mask when looking for obstructions.
# ------------------

class_name UnitFSM

# Enums are now defined in UnitAIConstants.gd to break circular dependency

# Unit References
var unit # Type hint removed to break circular dependency
var attack_ai: AttackAI  # Reference to the AttackAI component

# State Data
var current_state: UnitAIConstants.State = UnitAIConstants.State.IDLE
var stance: UnitAIConstants.Stance = UnitAIConstants.Stance.DEFENSIVE
var path: Array = []
var stuck_timer: float = 0.0

var los_range: float = 450.0 # Player unit "Line of Sight"

# Target Data
var target_position: Vector2 = Vector2.ZERO
var move_command_position: Vector2 = Vector2.ZERO

var objective_target: Node2D = null # The long-term goal (e.g., Great Hall)
var current_target: Node2D = null # The immediate threat (e.g., nearby unit)

func _init(p_unit, p_attack_ai: AttackAI) -> void:
	unit = p_unit
	attack_ai = p_attack_ai
	
	if attack_ai:
		attack_ai.attack_started.connect(_on_ai_attack_started)
		attack_ai.attack_stopped.connect(_on_ai_attack_stopped)

func change_state(new_state: UnitAIConstants.State) -> void:
	if current_state == new_state:
		return
	
	_exit_state(current_state)
	current_state = new_state
	
	if is_instance_valid(unit):
		unit.call("on_state_changed", current_state)
	
	_enter_state(current_state)

func _enter_state(state: UnitAIConstants.State) -> void:
	match state:
		UnitAIConstants.State.IDLE:
			unit.velocity = Vector2.ZERO
			
		UnitAIConstants.State.MOVING:
			_recalculate_path() 
		
		UnitAIConstants.State.FORMATION_MOVING:
			pass
		
		UnitAIConstants.State.ATTACKING:
			unit.velocity = Vector2.ZERO
			if attack_ai and is_instance_valid(current_target):
				attack_ai.force_target(current_target)

func _exit_state(state: UnitAIConstants.State) -> void:
	match state:
		UnitAIConstants.State.MOVING:
			path.clear()
			stuck_timer = 0.0
		UnitAIConstants.State.FORMATION_MOVING:
			path.clear()
		
		UnitAIConstants.State.ATTACKING:
			if attack_ai:
				attack_ai.stop_attacking()
			# Clear the *current* target, but not the objective
			current_target = null

func _recalculate_path() -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target
	
	if not is_instance_valid(target_node):
		change_state(UnitAIConstants.State.IDLE)
		return
		
	target_position = target_node.global_position
	var allow_partial = is_instance_valid(target_node)
	
	path = SettlementManager.get_astar_path(unit.global_position, target_position, allow_partial)
	
	if path.is_empty():
		push_warning("Unit at %s failed to find a path to %s." % [unit.global_position, target_position])
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()

# --- Find Obstruction (FIXED) ---
func _find_closest_blocking_building() -> Node2D:
	var mission_node = unit.get_parent()
	if not is_instance_valid(mission_node) or not mission_node.has_node("BuildingContainer"):
		return null

	var building_container = mission_node.get_node("BuildingContainer")
	var buildings = building_container.get_children()
	
	var closest_building: Node2D = null
	var min_dist_sq = INF
	
	# Use the mask from AttackAI to determine what we are allowed to attack
	var valid_mask = 0
	if attack_ai:
		valid_mask = attack_ai.target_collision_mask
	
	var unit_pos = unit.global_position

	for building in buildings:
		if not building is BaseBuilding:
			continue
		
		# --- FIX: Check if this is a valid target ---
		# If the building's layer is not in our target mask, ignore it.
		# This prevents Player Units (Target Mask L3+L4) from attacking Player Buildings (L1)
		if not (building.collision_layer & valid_mask):
			continue
		# -------------------------------------------
			
		var dist_sq = unit_pos.distance_squared_to(building.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_building = building
				
	return closest_building
# --- END FIX ---


# --- RTS Command Functions ---

func command_defensive_attack(attacker: Node2D) -> void:
	if not is_instance_valid(attacker):
		return
	
	if current_state == UnitAIConstants.State.ATTACKING and current_target == attacker:
		return
	
	current_target = attacker 
	change_state(UnitAIConstants.State.ATTACKING)

func command_attack_obstruction(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
		
	current_target = target
	target_position = target.global_position
	
	var distance: float = unit.global_position.distance_to(target.global_position)
	
	if distance <= unit.data.attack_range:
		change_state(UnitAIConstants.State.ATTACKING)
	else:
		change_state(UnitAIConstants.State.MOVING)

func command_move_to_formation_pos(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	
	current_target = null 
	objective_target = null
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	path.clear()
	path.append(target_pos)
	
	change_state(UnitAIConstants.State.FORMATION_MOVING)

func command_move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos

	current_target = null
	objective_target = null
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	change_state(UnitAIConstants.State.MOVING)

func command_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		return
	
	objective_target = target
	current_target = target
	target_position = target.global_position
	
	var distance: float = unit.global_position.distance_to(target.global_position)
	
	if distance <= unit.data.attack_range:
		change_state(UnitAIConstants.State.ATTACKING)
	else:
		change_state(UnitAIConstants.State.MOVING)

# --- State Machine Update ---

func update(delta: float) -> void:
	match current_state:
		UnitAIConstants.State.IDLE:
			_idle_state(delta)
		UnitAIConstants.State.MOVING:
			_move_state(delta)
		UnitAIConstants.State.FORMATION_MOVING:
			_formation_move_state(delta)
		UnitAIConstants.State.ATTACKING:
			_attack_state(delta)

# --- State Logic Functions ---

func _idle_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO

func _formation_move_state(delta: float) -> void:
	if path.is_empty():
		change_state(UnitAIConstants.State.IDLE)
		return

	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
	
	unit.velocity = velocity
	unit.move_and_slide()
	
	var arrival_radius: float = 8.0 
	if unit.global_position.distance_to(next_waypoint) < arrival_radius:
		path.pop_front()
		
		if path.is_empty():
			change_state(UnitAIConstants.State.IDLE)

func _move_state(delta: float) -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target

	if not is_instance_valid(target_node):
		change_state(UnitAIConstants.State.IDLE)
		return
	
	var distance_to_target: float = unit.global_position.distance_to(target_node.global_position)
	if distance_to_target <= unit.data.attack_range:
		change_state(UnitAIConstants.State.ATTACKING)
		return
	
	if not path.is_empty():
		var next_waypoint: Vector2 = path[0]
		var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
		
		unit.velocity = velocity
		unit.move_and_slide()
		
		var arrival_radius: float = 8.0 
		if unit.global_position.distance_to(next_waypoint) < arrival_radius:
			path.pop_front()
		
		# Stuck Timer Logic
		if unit.velocity.length_squared() < 1.0:
			stuck_timer += delta
			if stuck_timer > 1.5: # Stuck for 1.5 seconds
				var blocking_building = _find_closest_blocking_building()
				if is_instance_valid(blocking_building):
					# Found a VALID obstruction (Enemy)
					# push_warning("Unit is stuck. Attacking obstruction: %s" % blocking_building.name)
					command_attack_obstruction(blocking_building)
				else:
					# No valid obstruction (or it's friendly), so just give up
					change_state(UnitAIConstants.State.IDLE) 
				stuck_timer = 0.0 
		else:
			stuck_timer = 0.0 
			
		return
	
	# Path is empty logic
	if target_node == objective_target and is_instance_valid(objective_target):
		var blocking_building = _find_closest_blocking_building()
		if is_instance_valid(blocking_building):
			command_attack_obstruction(blocking_building)
		else:
			change_state(UnitAIConstants.State.IDLE)
	else:
		var direction: Vector2 = (target_node.global_position - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
		unit.velocity = velocity
		unit.move_and_slide()
		
		if unit.velocity.length_squared() < 1.0:
			stuck_timer += delta
			if stuck_timer > 0.5:
				change_state(UnitAIConstants.State.IDLE)
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0

func _attack_state(_delta: float) -> void:
	if not is_instance_valid(current_target):
		_resume_objective()
		return
	
	var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
	if distance_to_target > unit.data.attack_range + 10:
		_resume_objective()
		return
	
	unit.velocity = Vector2.ZERO

func _resume_objective() -> void:
	current_target = null
		
	if is_instance_valid(objective_target):
		current_target = objective_target
		change_state(UnitAIConstants.State.MOVING)
	else:
		if attack_ai and attack_ai.ai_mode == AttackAI.AI_Mode.DEFAULT:
			var new_target = _find_closest_enemy_in_los()
			if is_instance_valid(new_target):
				command_attack(new_target)
			else:
				change_state(UnitAIConstants.State.IDLE)
		else:
			change_state(UnitAIConstants.State.IDLE)

func _find_closest_enemy_in_los() -> Node2D:
	var mission_node = unit.get_parent()
	if not is_instance_valid(mission_node):
		return null

	var closest_target: Node2D = null
	var min_dist_sq = los_range * los_range
	var unit_pos = unit.global_position

	# 1. Check Enemy Buildings
	var building_container = mission_node.get_node_or_null("BuildingContainer")
	if is_instance_valid(building_container):
		for building in building_container.get_children():
			if not building is BaseBuilding or not (building.collision_layer & (1 << 3)):
				continue
				
			var dist_sq = unit_pos.distance_squared_to(building.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_target = building

	# 2. Check Enemy Units
	var enemy_units = unit.get_tree().get_nodes_in_group("enemy_units")
	for enemy_unit in enemy_units:
		if not is_instance_valid(enemy_unit) or not enemy_unit is Node2D:
			continue

		var dist_sq = unit_pos.distance_squared_to(enemy_unit.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_target = enemy_unit
			
	return closest_target

func _on_ai_attack_started(target: Node2D) -> void:
	if current_state != UnitAIConstants.State.IDLE:
		return
		
	if current_state == UnitAIConstants.State.ATTACKING and target == current_target:
		return
		
	if attack_ai.ai_mode == AttackAI.AI_Mode.DEFENSIVE_SIEGE:
		return
		
	current_target = target
	change_state(UnitAIConstants.State.ATTACKING)

func _on_ai_attack_stopped() -> void:
	if current_state == UnitAIConstants.State.ATTACKING:
		_resume_objective()
