# res://scripts/ai/UnitFSM.gd
class_name UnitFSM

# Unit References
var unit 
var attack_ai: AttackAI 

# State Data
var current_state: UnitAIConstants.State = UnitAIConstants.State.IDLE
var stance: UnitAIConstants.Stance = UnitAIConstants.Stance.DEFENSIVE
var path: Array = []
var stuck_timer: float = 0.0

var los_range: float = 450.0

# Target Data
var target_position: Vector2 = Vector2.ZERO
var move_command_position: Vector2 = Vector2.ZERO

var objective_target: Node2D = null 
var current_target: Node2D = null 

# Add variable to track pillage timer
var _pillage_accumulator: float = 0.0

func _init(p_unit, p_attack_ai: AttackAI) -> void:
	unit = p_unit
	attack_ai = p_attack_ai
	
	if attack_ai:
		attack_ai.attack_started.connect(_on_ai_attack_started)
		attack_ai.attack_stopped.connect(_on_ai_attack_stopped)

func change_state(new_state: UnitAIConstants.State) -> void:
	if current_state == new_state: return
	
	_exit_state(current_state)
	current_state = new_state
	
	# Notify Unit (Trigger visual changes / Squad Orders)
	if is_instance_valid(unit):
		if unit.has_method("on_state_changed"):
			unit.on_state_changed(current_state)
	
	_enter_state(current_state)

func _enter_state(state: UnitAIConstants.State) -> void:
	match state:
		UnitAIConstants.State.IDLE:
			unit.velocity = Vector2.ZERO
		UnitAIConstants.State.MOVING, UnitAIConstants.State.INTERACTING:
			_recalculate_path()
		UnitAIConstants.State.RETREATING:
			_recalculate_path()
		UnitAIConstants.State.ATTACKING:
			unit.velocity = Vector2.ZERO
			
			# Ensure the AI is actually running!
			if attack_ai:
				attack_ai.set_process(true)
				attack_ai.set_physics_process(true)
				
				if is_instance_valid(current_target):
					attack_ai.force_target(current_target)
		UnitAIConstants.State.INTERACTING:
			_recalculate_path()
			if attack_ai: 
				attack_ai.stop_attacking()
				attack_ai.set_process(false) # Brain off
				attack_ai.set_physics_process(false)
func _exit_state(state: UnitAIConstants.State) -> void:
	match state:
		UnitAIConstants.State.MOVING, UnitAIConstants.State.INTERACTING:
			path.clear()
			stuck_timer = 0.0
		UnitAIConstants.State.FORMATION_MOVING:
			path.clear()
		UnitAIConstants.State.RETREATING:
			path.clear()
			stuck_timer = 0.0
		UnitAIConstants.State.ATTACKING:
			if attack_ai:
				attack_ai.stop_attacking()
			current_target = null
		UnitAIConstants.State.INTERACTING:
			path.clear()
			if attack_ai:
				attack_ai.set_process(true) # Brain on
				attack_ai.set_physics_process(true)

func _recalculate_path() -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target
	
	if is_instance_valid(target_node):
		target_position = target_node.global_position
	elif target_position == Vector2.ZERO:
		change_state(UnitAIConstants.State.IDLE)
		return
	
	var start_pos = unit.global_position
	# Allow partial path if we have a solid target node (like a building)
	var allow_partial = is_instance_valid(target_node)
	
	path = SettlementManager.get_astar_path(start_pos, target_position, allow_partial)
	
	if path.is_empty():
		# FORCE move if very close (A* sometimes fails on short distances inside cell boundaries)
		if start_pos.distance_to(target_position) < 150.0:
			path = [target_position] 
		else:
			if unit.has_method("flash_error_color"):
				unit.flash_error_color()
			change_state(UnitAIConstants.State.IDLE)

# --- RTS COMMANDS ---

func command_defensive_attack(attacker: Node2D) -> void:
	if current_state == UnitAIConstants.State.RETREATING: return
	
	if not is_instance_valid(attacker): return
	if current_state == UnitAIConstants.State.ATTACKING and current_target == attacker: return
	current_target = attacker 
	change_state(UnitAIConstants.State.ATTACKING)

func command_attack_obstruction(target: Node2D) -> void:
	if current_state == UnitAIConstants.State.RETREATING: return
	if not is_instance_valid(target): return
	
	current_target = target
	change_state(UnitAIConstants.State.ATTACKING)

func command_move_to_formation_pos(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	current_target = null 
	objective_target = null
	if attack_ai: attack_ai.stop_attacking()
	path.clear()
	path.append(target_pos)
	change_state(UnitAIConstants.State.FORMATION_MOVING)

func command_move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	current_target = null
	objective_target = null
	if attack_ai: attack_ai.stop_attacking()
	change_state(UnitAIConstants.State.MOVING)

func command_attack(target: Node2D) -> void:
	if not is_instance_valid(target): return
	objective_target = target
	current_target = target
	target_position = target.global_position
	
	# Immediate check if already in range
	var radius = _get_target_radius(target)
	var dist = unit.global_position.distance_to(target.global_position) - radius
	
	if dist <= unit.data.attack_range + 10.0:
		change_state(UnitAIConstants.State.ATTACKING)
	else:
		change_state(UnitAIConstants.State.MOVING)

func command_retreat(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	current_target = null
	objective_target = null
	if attack_ai: attack_ai.stop_attacking()
	change_state(UnitAIConstants.State.RETREATING)

func command_interact_move(target: Node2D) -> void:
	if not is_instance_valid(target): return
	objective_target = target
	current_target = null
	target_position = target.global_position
	if attack_ai: attack_ai.stop_attacking()
	change_state(UnitAIConstants.State.INTERACTING)

# --- UPDATE LOOP ---

func update(delta: float) -> void:
	match current_state:
		UnitAIConstants.State.IDLE:
			_idle_state(delta)
		UnitAIConstants.State.MOVING:
			_move_state(delta)
		UnitAIConstants.State.FORMATION_MOVING:
			_formation_move_state(delta)
		UnitAIConstants.State.RETREATING:
			_retreat_state(delta)
		UnitAIConstants.State.ATTACKING:
			_attack_state(delta)
		UnitAIConstants.State.INTERACTING:
			_interact_state(delta)
		UnitAIConstants.State.COLLECTING:
			_collect_state(delta)
		UnitAIConstants.State.ESCORTING:
			_escort_state(delta)
		UnitAIConstants.State.REGROUPING:
			_regroup_state(delta)
# --- STATE LOGIC ---

func _collect_state(delta: float) -> void:
	if is_instance_valid(objective_target):
		_simple_move_to(objective_target.global_position, delta)
		if unit.has_method("process_collecting_logic"):
			unit.process_collecting_logic(delta)
	else:
		change_state(UnitAIConstants.State.IDLE)

func _escort_state(delta: float) -> void:
	if is_instance_valid(objective_target):
		_simple_move_to(objective_target.global_position, delta)
		
		# Arrival check (Retreat Zone)
		if unit.global_position.distance_to(objective_target.global_position) < 50.0:
			if unit.has_method("complete_escort"):
				unit.complete_escort()
	else:
		change_state(UnitAIConstants.State.IDLE)

func _regroup_state(delta: float) -> void:
	if unit.has_method("process_regroup_logic"):
		unit.process_regroup_logic(delta)
		if move_command_position != Vector2.ZERO:
			_simple_move_to(move_command_position, delta)

func _idle_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO

func _formation_move_state(_delta: float) -> void:
	if path.is_empty():
		change_state(UnitAIConstants.State.IDLE)
		return

	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
	
	unit.velocity = velocity
	
	if unit.global_position.distance_to(next_waypoint) < 8.0:
		path.pop_front()
		if path.is_empty():
			change_state(UnitAIConstants.State.IDLE)

func _move_state(delta: float) -> void:
	if path.is_empty():
		change_state(UnitAIConstants.State.IDLE)
		return

	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var distance_to_waypoint = unit.global_position.distance_to(next_waypoint)

	# [NEW] Apply Encumbrance Logic Here
	# We fetch the multiplier (e.g., 0.5) from the Unit and apply it to the base stat
	var speed_mult = unit.get_speed_multiplier()
	var final_speed = unit.data.move_speed * speed_mult

	# Apply velocity
	unit.velocity = direction * final_speed
	
	# Standard Waypoint Logic (Preserved from standard RTS logic)
	if distance_to_waypoint < 10.0: # Threshold to reach point
		path.remove_at(0)
		if path.is_empty():
			# If we were moving to a specific target (like a building), switch to Interact/Attack
			if is_instance_valid(objective_target):
				 # Simple check to decide next state based on target type
				if objective_target is BaseBuilding:
					change_state(UnitAIConstants.State.INTERACTING) # Pillage
				else:
					change_state(UnitAIConstants.State.ATTACKING)
			else:
				change_state(UnitAIConstants.State.IDLE)

func _interact_state(delta: float) -> void:
	if not is_instance_valid(objective_target):
		change_state(UnitAIConstants.State.IDLE)
		return

	# 1. Move to Target (Existing Logic)
	var distance_to_target = UnitAIConstants.get_surface_distance(unit, objective_target)
	var interact_range = 25.0 # Close range for pillaging
	
	if distance_to_target > interact_range:
		# Use pathfinding if far
		if not path.is_empty():
			var next = path[0]
			var dir = (next - unit.global_position).normalized()
			unit.velocity = dir * unit.data.move_speed
			unit.move_and_slide()
			
			if unit.global_position.distance_to(next) < 8.0:
				path.pop_front()
		else:
			# Direct approach for last mile
			var dir = (objective_target.global_position - unit.global_position).normalized()
			unit.velocity = dir * unit.data.move_speed
			unit.move_and_slide()
	else:
		# 2. Arrived -> Perform Pillage
		unit.velocity = Vector2.ZERO
		
		# Only Pillage if it's an Enemy Building
		if objective_target is BaseBuilding and objective_target.collision_layer != 1:
			_process_pillage_tick(delta)

func _process_pillage_tick(delta: float) -> void:
	_pillage_accumulator += delta
	if _pillage_accumulator >= 1.0: # Tick once per second
		_pillage_accumulator = 0.0
		
		if not is_instance_valid(objective_target):
			change_state(UnitAIConstants.State.IDLE)
			return

		var building = objective_target as BaseBuilding
		
		# 1. Check Capacity BEFORE stealing
		if unit.current_loot_weight >= unit.data.max_loot_capacity:
			# Visual Feedback for "Full"
			EventBus.floating_text_requested.emit("FULL!", unit.global_position, Color.YELLOW)
			# Optional: Auto-stop or keep burning? 
			# For now, we stop stealing but stay in state (player must move them)
			return

		# 2. Steal
		var amount_to_take = unit.data.pillage_speed
		var stolen_amount = building.steal_resources(amount_to_take)
		
		if stolen_amount > 0:
			# 3. Pocket the loot
			unit.add_loot("gold", stolen_amount)
			
			# Juice
			EventBus.floating_text_requested.emit("+%d" % stolen_amount, unit.global_position, Color.GOLD)
		else:
			# Building empty
			EventBus.floating_text_requested.emit("Empty", unit.global_position, Color.GRAY)
			change_state(UnitAIConstants.State.IDLE)

func _retreat_state(delta: float) -> void:
	if not path.is_empty():
		var next_waypoint: Vector2 = path[0]
		var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
		
		unit.velocity = velocity
		unit.move_and_slide()
		
		if unit.global_position.distance_to(next_waypoint) < 8.0:
			path.pop_front()
		return

	# The Last Mile for Retreat
	var dist_to_final = unit.global_position.distance_to(target_position)
	if dist_to_final > 5.0:
		var direction = (target_position - unit.global_position).normalized()
		unit.velocity = direction * unit.data.move_speed
		unit.move_and_slide()
	else:
		unit.velocity = Vector2.ZERO

func _attack_state(_delta: float) -> void:
	if not is_instance_valid(current_target):
		_resume_objective()
		return
	
	# Check if target moved out of range
	var radius = _get_target_radius(current_target)
	var dist = unit.global_position.distance_to(current_target.global_position) - radius
	
	# Use max range (Buildings are bigger)
	var max_range = max(unit.data.attack_range, unit.data.building_attack_range)
	
	if dist > max_range + 10:
		_resume_objective()
		return
	
	unit.velocity = Vector2.ZERO

func _resume_objective() -> void:
	current_target = null
	if is_instance_valid(objective_target):
		current_target = objective_target
		change_state(UnitAIConstants.State.MOVING)
	else:
		# Auto-acquire new targets if idle
		if attack_ai and attack_ai.ai_mode == AttackAI.AI_Mode.DEFAULT:
			var new_target = _find_closest_enemy_in_los()
			if is_instance_valid(new_target):
				command_attack(new_target)
			else:
				change_state(UnitAIConstants.State.IDLE)
		else:
			change_state(UnitAIConstants.State.IDLE)

func _find_closest_enemy_in_los() -> Node2D:
	# Simple fallback to find nearby enemies
	var enemies = unit.get_tree().get_nodes_in_group("enemy_units")
	var closest: Node2D = null
	var min_dist = los_range
	
	for e in enemies:
		var d = unit.global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			closest = e
	return closest

# --- SIGNAL CALLBACKS ---

func _on_ai_attack_started(target: Node2D) -> void:
	if current_state != UnitAIConstants.State.IDLE: return
	if current_state == UnitAIConstants.State.ATTACKING and target == current_target: return
	if current_state == UnitAIConstants.State.RETREATING: return 
	if current_state == UnitAIConstants.State.INTERACTING: return 
	
	current_target = target
	change_state(UnitAIConstants.State.ATTACKING)

func _on_ai_attack_stopped() -> void:
	if current_state == UnitAIConstants.State.ATTACKING:
		# --- FIX: Anti-Flicker Guard ---
		# If the AI stopped, but we are still in range and the target is alive,
		# ignore the signal. This prevents the infinite loop.
		if is_instance_valid(current_target):
			var limit = unit.data.attack_range
			if current_target is BaseBuilding or (current_target.name == "Hitbox" and current_target.get_parent() is BaseBuilding):
				limit = unit.data.building_attack_range
			
			var radius = _get_target_radius(current_target)
			var dist = unit.global_position.distance_to(current_target.global_position) - radius
			
			# If we are still comfortably in range, assume AI is just cycling/reloading
			if dist <= limit + 5.0:
				return
		# -------------------------------
		
		_resume_objective()

# --- HELPER: Geometry Math ---
func _get_target_radius(target: Node2D) -> float:
	if not is_instance_valid(target): return 0.0
	
	# 1. Check for Building Hitbox
	if target.name == "Hitbox" and target.get_parent() is BaseBuilding:
		var b = target.get_parent() as BaseBuilding
		if b.data:
			var size = min(b.data.grid_size.x, b.data.grid_size.y)
			return (size * 32.0) / 2.0
	
	# 2. Check for BaseBuilding directly
	if target is BaseBuilding and target.data:
		var size = min(target.data.grid_size.x, target.data.grid_size.y)
		return (size * 32.0) / 2.0

	# 3. Check for Unit
	if target is BaseUnit:
		return 15.0
		
	# 4. Fallback: Collision Shape
	var col = target.get_node_or_null("CollisionShape2D")
	if col:
		if col.shape is CircleShape2D: return col.shape.radius
		if col.shape is RectangleShape2D: return min(col.shape.size.x, col.shape.size.y) / 2.0
		
	return 0.0
	
func command_pillage(target: Node2D) -> void:
	if not is_instance_valid(target): return
	
	# Pillage uses the same movement logic as interacting
	objective_target = target
	current_target = null
	target_position = target.global_position
	
	if attack_ai: attack_ai.stop_attacking()
	
	# We reuse INTERACTING state for now. 
	# In Batch B, we will add specific logic inside _interact_state to drain resources.
	change_state(UnitAIConstants.State.INTERACTING)

func _simple_move_to(target: Vector2, _delta: float) -> void:
	var dir = (target - unit.global_position).normalized()
	
	var speed_mult = unit.get_speed_multiplier() if unit.has_method("get_speed_multiplier") else 1.0
	var final_speed = unit.data.move_speed * speed_mult
	
	unit.velocity = dir * final_speed
	# Note: BaseUnit._physics_process is responsible for calling move_and_slide()
