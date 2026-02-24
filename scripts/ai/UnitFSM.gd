#res://scripts/ai/UnitFSM.gd
extends Node
class_name UnitFSM

# Unit References
var unit 
var attack_ai: AttackAI 

# State Data
var current_state: UnitAIConstants.State = UnitAIConstants.State.IDLE
var stance: UnitAIConstants.Stance = UnitAIConstants.Stance.DEFENSIVE
# CHANGED: Strict typing for performance and compatibility with NavigationManager
var path: PackedVector2Array = []
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
		UnitAIConstants.State.ALARMED:
			# Raise alarm immediately
			if unit.has_method("emit_alarm"):
				unit.emit_alarm()

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
	
	if RaidNavigationManager.is_raid_active:
		# During raids, use NavigationAgent2D
		unit.set_movement_target(target_position)
		# Build a simple path from nav_agent for external compatibility
		if unit.nav_agent:
			path = PackedVector2Array([unit.nav_agent.get_next_path_position()])
		else:
			path = PackedVector2Array([target_position])
	else:
		# Settlement mode: use AStarGrid2D
		path = NavigationManager.get_astar_path(start_pos, target_position, allow_partial)
	
	if path.is_empty():
		# FORCE move if very close (A* sometimes fails on short distances inside cell boundaries)
		if start_pos.distance_to(target_position) < 150.0:
			path = PackedVector2Array([target_position]) 
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

# NEW: Explicit Collect Command (Harvesting)
func command_collect(target: Node2D) -> void:
	if not is_instance_valid(target): return
	objective_target = target
	current_target = null
	target_position = target.global_position
	
	if attack_ai: attack_ai.stop_attacking()
	
	change_state(UnitAIConstants.State.COLLECTING)

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
	
	# CRITICAL FIX: Interruption Logic
	if current_state == UnitAIConstants.State.MOVING:
		# If already moving, FORCE a path update immediately.
		_recalculate_path()
	else:
		change_state(UnitAIConstants.State.MOVING)

func command_attack(target: Node2D) -> void:
	if not is_instance_valid(target): return
	
	# SMART OVERRIDE: If target is a Resource, Harvest instead of Attack
	# Uses the group name defined in ResourceNode.gd
	if target.is_in_group("resource_nodes"):
		command_collect(target)
		return
	
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
		UnitAIConstants.State.UNAWARE:
			_unaware_state(delta)
		UnitAIConstants.State.ALARMED:
			_alarmed_state(delta)
		UnitAIConstants.State.FLEEING:
			_fleeing_state(delta)

# --- STATE LOGIC ---

func _collect_state(delta: float) -> void:
	if not is_instance_valid(objective_target):
		change_state(UnitAIConstants.State.IDLE)
		return

	# 1. Define Work Range (e.g., 50 pixels from the resource center)
	var work_range = 50.0 
	var dist = unit.global_position.distance_to(objective_target.global_position)

	if dist > work_range:
		# PHASE A: APPROACH
		# Use simple movement to get close
		_simple_move_to(objective_target.global_position, delta)
	else:
		# PHASE B: WORK
		# Stop moving!
		unit.velocity = Vector2.ZERO
		
		# --- TODO: FUTURE ECONOMY LOGIC ---
		# 1. Capacity Check:
		#    Example: if unit.current_resources >= unit.max_capacity_without_building: return
		
		# 2. Turn-Based / Tick Logic:
		#    If the game is turn-based, you might only want to run this logic 
		#    when a specific "Turn Tick" signal is received, rather than every delta frame.
		
		# Delegate actual gathering to the Unit's script
		if unit.has_method("process_collecting_logic"):
			unit.process_collecting_logic(delta)

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
	if RaidNavigationManager.is_raid_active:
		unit.set_movement_target(target_position)
		var next_pos = unit.nav_agent.get_next_path_position()
		var direction = (next_pos - unit.global_position).normalized()
		unit.velocity = direction * unit.data.move_speed
		
		if unit.nav_agent.is_navigation_finished():
			change_state(UnitAIConstants.State.IDLE)
		return

	if path.is_empty():
		change_state(UnitAIConstants.State.IDLE)
		return

	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
	
	unit.velocity = velocity
	
	if unit.global_position.distance_to(next_waypoint) < 8.0:
		path.remove_at(0) # FIXED: Compatible with PackedVector2Array
		if path.is_empty():
			change_state(UnitAIConstants.State.IDLE)

func _move_state(delta: float) -> void:
	if RaidNavigationManager.is_raid_active:
		# Check arrival FIRST before updating nav target
		if is_instance_valid(objective_target):
			var dist = UnitAIConstants.get_surface_distance(unit, objective_target)
			# TODO: Large building alignment — the get_surface_distance() < 30.0 threshold may need tuning upward for larger buildings, or a per-building override
			if dist < 30.0:
				if objective_target is BaseBuilding:
					change_state(UnitAIConstants.State.INTERACTING)
				else:
					change_state(UnitAIConstants.State.ATTACKING)
				return
		elif unit.nav_agent.is_navigation_finished():
			change_state(UnitAIConstants.State.IDLE)
			return
		
		unit.set_movement_target(target_position)
		var next_pos = unit.nav_agent.get_next_path_position()
		var direction = (next_pos - unit.global_position).normalized()
		var speed_mult = unit.get_speed_multiplier()
		unit.velocity = direction * unit.data.move_speed * speed_mult
		return

	if path.is_empty():
		change_state(UnitAIConstants.State.IDLE)
		return

	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var distance_to_waypoint = unit.global_position.distance_to(next_waypoint)

	# [NEW] Apply Encumbrance Logic Here
	var speed_mult = unit.get_speed_multiplier()
	# TODO: Ensure get_speed_multiplier() connects to Inventory Weight (Unit.inventory_weight)
	var final_speed = unit.data.move_speed * speed_mult

	# Apply velocity
	unit.velocity = direction * final_speed
	
	# [NEW] Stuck Safety Check
	# If we are supposed to be moving but velocity is tiny for too long
	if unit.velocity.length_squared() < 100.0:
		stuck_timer += delta
		if stuck_timer > 1.0:
			# Try re-pathing
			stuck_timer = 0.0
			_recalculate_path()
	else:
		stuck_timer = 0.0
	
	# Standard Waypoint Logic
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
		if RaidNavigationManager.is_raid_active:
			unit.set_movement_target(objective_target.global_position)
			var next_pos = unit.nav_agent.get_next_path_position()
			var dir = (next_pos - unit.global_position).normalized()
			unit.velocity = dir * unit.data.move_speed
		elif not path.is_empty():
			var next = path[0]
			var dir = (next - unit.global_position).normalized()
			unit.velocity = dir * unit.data.move_speed
			if unit.global_position.distance_to(next) < 8.0:
				path.remove_at(0)
		else:
			var dir = (objective_target.global_position - unit.global_position).normalized()
			unit.velocity = dir * unit.data.move_speed
	else:
		# 2. Arrived -> Perform Pillage
		unit.velocity = Vector2.ZERO
		
		# Only Pillage if it's an Enemy Building
		if objective_target is BaseBuilding:
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
			return

		# 2. Steal
		var amount_to_take = unit.data.pillage_speed
		var stolen_amount = building.steal_resources(amount_to_take)
		
		if stolen_amount > 0:
			# 3. Pocket the loot
			# TODO: [Refactor] Consider unifying this with Resource Gathering logic (EconomyManager)
			unit.add_loot("gold", stolen_amount)
			
			# Juice
			EventBus.floating_text_requested.emit("+%d" % stolen_amount, unit.global_position, Color.GOLD)
		else:
			# Building empty
			EventBus.floating_text_requested.emit("Empty", unit.global_position, Color.GRAY)
			change_state(UnitAIConstants.State.IDLE)

func _retreat_state(delta: float) -> void:
	if RaidNavigationManager.is_raid_active:
		if unit.nav_agent.is_navigation_finished():
			unit.velocity = Vector2.ZERO
			return
		else:
			var next_pos = unit.nav_agent.get_next_path_position()
			var direction = (next_pos - unit.global_position).normalized()
			unit.velocity = direction * unit.data.move_speed
			unit.move_and_slide()
			return
			
	if not path.is_empty():
		var next_waypoint: Vector2 = path[0]
		var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
		
		unit.velocity = velocity
		unit.move_and_slide()
		
		if unit.global_position.distance_to(next_waypoint) < 8.0:
			path.remove_at(0) # FIXED: Compatible with PackedVector2Array
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
		# --- Anti-Flicker Guard ---
		if is_instance_valid(current_target):
			var limit = unit.data.attack_range
			if current_target is BaseBuilding or (current_target.name == "Hitbox" and current_target.get_parent() is BaseBuilding):
				limit = unit.data.building_attack_range
			
			var radius = _get_target_radius(current_target)
			var dist = unit.global_position.distance_to(current_target.global_position) - radius
			
			# If we are still comfortably in range, assume AI is just cycling/reloading
			if dist <= limit + 5.0:
				return
		
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
	# TODO: Consolidate with command_interact_move if pillaging becomes standard interaction.
	change_state(UnitAIConstants.State.INTERACTING)

func _simple_move_to(target: Vector2, _delta: float) -> void:
	var dir = (target - unit.global_position).normalized()
	
	var speed_mult = unit.get_speed_multiplier() if unit.has_method("get_speed_multiplier") else 1.0
	var final_speed = unit.data.move_speed * speed_mult
	
	unit.velocity = dir * final_speed
	# Note: BaseUnit._physics_process is responsible for calling move_and_slide()

func _unaware_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO
	if not RaidNavigationManager.is_raid_active:
		return
	var player_units = unit.get_tree().get_nodes_in_group("player_units")
	for player_unit in player_units:
		if not is_instance_valid(player_unit):
			continue
		var distance = unit.global_position.distance_to(player_unit.global_position)
		if distance < unit.data.detection_range:
			var space = unit.get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(
				unit.global_position,
				player_unit.global_position)
			var result = space.intersect_ray(query)
			if result and result.collider == player_unit:
				change_state(UnitAIConstants.State.ALARMED)
				return

func _alarmed_state(_delta: float) -> void:
	if not RaidNavigationManager.is_raid_active:
		return
	if not unit.has_meta("alarm_spread_done"):
		unit.set_meta("alarm_spread_done", true)
		var nearby = unit.get_tree().get_nodes_in_group("enemy_units")
		for enemy in nearby:
			if not is_instance_valid(enemy): continue
			if enemy == unit: continue
			var dist = unit.global_position.distance_to(enemy.global_position)
			if dist < 200.0 and enemy.has_method("get_fsm"):
				var fsm_ref = enemy.get_fsm()
				if fsm_ref and fsm_ref.current_state == UnitAIConstants.State.UNAWARE:
					fsm_ref.change_state(UnitAIConstants.State.ALARMED)
		unit.set_movement_target(_get_hall_position())

	var next_pos = unit.nav_agent.get_next_path_position()
	var direction = (next_pos - unit.global_position).normalized()
	unit.velocity = direction * unit.data.move_speed

	# Check arrival at Hall using surface distance
	var hall_pos = _get_hall_position()
	if unit.global_position.distance_to(hall_pos) < 60.0:
		change_state(UnitAIConstants.State.IDLE)

func _fleeing_state(_delta: float) -> void:
	if not RaidNavigationManager.is_raid_active:
		unit.velocity = Vector2.ZERO
		return
		
	# Update flee target periodically (every 60 frames approx)
	var update_flee = false
	if not unit.has_meta("flee_target_set"):
		unit.set_meta("flee_target_set", true)
		unit.set_meta("flee_update_timer", 0)
		update_flee = true
	else:
		var timer = unit.get_meta("flee_update_timer") + 1
		if timer >= 60:
			update_flee = true
			unit.set_meta("flee_update_timer", 0)
		else:
			unit.set_meta("flee_update_timer", timer)
			
	if update_flee:
		var nearest = _get_nearest_player_unit()
		if nearest:
			var flee_dir = (unit.global_position - nearest.global_position).normalized()
			var base_angle = flee_dir.angle()
			var panic_offset = randf_range(-PI / 2, PI / 2)  # Random ±90 degrees for panic arc
			var panic_dir = Vector2.from_angle(base_angle + panic_offset)
			var flee_target_pos = unit.global_position + panic_dir * 800.0
			unit.set_movement_target(flee_target_pos)
			# TODO: [AI Phase 6] Add LOS check before fleeing — civilian should only react to player
			# units they can see. Use PhysicsDirectSpaceState2D raycast against Environment layer.
			# This creates realistic "information gap" — a civilian around a corner shouldn't panic.
	
	var next_pos = unit.nav_agent.get_next_path_position()
	var direction = (next_pos - unit.global_position).normalized()
	unit.velocity = direction * unit.data.move_speed

	if unit.nav_agent.is_navigation_finished() and unit.global_position != Vector2.ZERO:
		if unit.has_method("emit_alarm"):
			unit.emit_alarm()
		change_state(UnitAIConstants.State.IDLE)
func _get_hall_position() -> Vector2:
	var buildings = unit.get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if is_instance_valid(building) and building.data and building.data.is_territory_hub:
			return building.global_position
	# Fallback to map center if Hall not found
	var bounds = RaidNavigationManager.map_bounds
	return bounds.get_center()

func _get_nearest_player_unit() -> Node:
	var player_units = unit.get_tree().get_nodes_in_group("player_units")
	var nearest = null
	var nearest_dist = INF
	for u in player_units:
		if not is_instance_valid(u): continue
		var d = unit.global_position.distance_to(u.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = u
	return nearest
