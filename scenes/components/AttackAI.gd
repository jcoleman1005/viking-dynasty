# res://scenes/components/AttackAI.gd
#
# A modular AI component that provides attack behavior for any unit or building.
# Simply instance this as a child of units or buildings that need to attack.
class_name AttackAI
extends Node2D

## Emitted when this AI starts attacking a target
signal attack_started(target: Node2D)
## Emitted when this AI stops attacking (no targets)
signal attack_stopped()
## Emitted just before firing a projectile or dealing damage
signal about_to_attack(target: Node2D, damage: int)

# --- NEW: AI Behavior Modes ---
enum AI_Mode {
	DEFAULT,         # Default behavior: Prioritize closest enemy units, then buildings.
	DEFENSIVE_SIEGE  # Enemy AI behavior: Prioritize Great Hall, then closest building.
}
@export var ai_mode: AI_Mode = AI_Mode.DEFAULT
@export var great_hall_los_range: float = 600.0 # Arbitrary LOS value
# --- END NEW ---

# Configuration - set these from the parent
@export var attack_damage: int = 10
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0  # attacks per second
@export var projectile_scene: PackedScene

var target_collision_mask: int = 0
var projectile_speed: float = 400.0

# Node references
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

# AI state
var parent_node: Node2D
var current_target: Node2D = null
var targets_in_range: Array[Node2D] = []
var is_attacking: bool = false

func _ready() -> void:
	parent_node = get_parent() as Node2D
	if not parent_node:
		push_error("AttackAI: Parent must be a Node2D")
		return
	
	_setup_ai()

func _setup_ai() -> void:
	"""Initialize the AI components"""
	if detection_area:
		detection_area.collision_layer = 0
		detection_area.collision_mask = target_collision_mask
		
		if detection_area.get_child(0) is CollisionShape2D:
			var detection_shape = detection_area.get_child(0) as CollisionShape2D
			if detection_shape.shape is CircleShape2D:
				(detection_shape.shape as CircleShape2D).radius = attack_range
		
		detection_area.body_entered.connect(_on_target_entered)
		detection_area.area_entered.connect(_on_target_entered)
		detection_area.body_exited.connect(_on_target_exited)
		detection_area.area_exited.connect(_on_target_exited)
	
	if attack_timer:
		if attack_speed > 0:
			attack_timer.wait_time = 1.0 / attack_speed
		else:
			attack_timer.wait_time = 999.0
	
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func configure_from_data(data_resource) -> void:
	if not data_resource:
		return
	
	if "attack_damage" in data_resource:
		attack_damage = data_resource.attack_damage
	if "attack_range" in data_resource:
		attack_range = data_resource.attack_range
	if "attack_speed" in data_resource:
		attack_speed = data_resource.attack_speed
	if "projectile_scene" in data_resource:
		projectile_scene = data_resource.projectile_scene
	if "projectile_speed" in data_resource:
		projectile_speed = data_resource.projectile_speed
	
	if attack_timer:
		if attack_speed > 0:
			attack_timer.wait_time = 1.0 / attack_speed
		else:
			attack_timer.wait_time = 999.0
	
	if detection_area and detection_area.get_child(0) is CollisionShape2D:
		var detection_shape = detection_area.get_child(0) as CollisionShape2D
		if detection_shape.shape is CircleShape2D:
			(detection_shape.shape as CircleShape2D).radius = attack_range

func set_target_mask(mask: int) -> void:
	target_collision_mask = mask
	if detection_area:
		detection_area.collision_mask = mask

func force_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	
	if target is BaseBuilding and target.has_node("Hitbox"):
		current_target = target.get_node("Hitbox")
	else:
		current_target = target
	
	if current_target not in targets_in_range:
		targets_in_range.append(current_target)
	
	_start_attacking()

func stop_attacking() -> void:
	current_target = null
	_stop_attacking()

func _on_target_entered(body: Node2D) -> void:
	if body not in targets_in_range:
		targets_in_range.append(body)
	
	if not current_target and targets_in_range.size() > 0:
		_select_target()

func _on_target_exited(body: Node2D) -> void:
	targets_in_range.erase(body)
	
	if current_target == body:
		current_target = null
		_select_target()

func _select_target() -> void:
	"""Selects a target based on the current AI_Mode."""
	match ai_mode:
		AI_Mode.DEFAULT:
			_select_target_default()
		AI_Mode.DEFENSIVE_SIEGE:
			_select_target_defensive_siege()

func _select_target_default() -> void:
	"""Select the closest valid target, prioritizing units over buildings."""
	if targets_in_range.is_empty():
		current_target = null
		_stop_attacking()
		return
	
	var unit_targets: Array[Node2D] = []
	var building_targets: Array[Node2D] = []

	for target in targets_in_range:
		if not is_instance_valid(target):
			targets_in_range.erase(target)
			continue
		
		# --- FIX: Enforce Collision Mask ---
		# This prevents Friendly Fire. We check if the target matches our allowed mask.
		if not (target.collision_layer & target_collision_mask):
			continue
		# -----------------------------------

		# Determine type based on layer
		# Units: Layer 2 (Player) or Layer 3 (Enemy) -> Binary 0110 -> 6
		if target.collision_layer & 6: 
			unit_targets.append(target)
		# Buildings: Layer 1 (Player) or Layer 4 (Enemy) -> Binary 1001 -> 9
		elif target.collision_layer & 9: 
			building_targets.append(target)

	var closest_target: Node2D = null
	var closest_distance: float = INF
	
	# Prioritize Units over Buildings
	if not unit_targets.is_empty():
		for target in unit_targets:
			var distance = parent_node.global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
	elif not building_targets.is_empty():
		for target in building_targets:
			var distance = parent_node.global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
	
	current_target = closest_target
	
	if current_target:
		_start_attacking()
	else:
		_stop_attacking()

# --- NEW SIEGE AI LOGIC ---
func _select_target_defensive_siege() -> void:
	"""
	Enemy AI logic:
	1. Prioritize the Great Hall if it's in LOS.
	2. Otherwise, attack the closest building.
	"""
	# Only access FSM if parent is a BaseUnit
	var unit_parent = parent_node as BaseUnit
	if not is_instance_valid(unit_parent) or not unit_parent.fsm:
		_stop_attacking()
		return

	# 1. Check for Great Hall (Priority 1)
	var great_hall = unit_parent.fsm.objective_target
	if is_instance_valid(great_hall):
		var hall_pos = great_hall.global_position
		var distance_to_hall = parent_node.global_position.distance_to(hall_pos)
		
		if distance_to_hall <= great_hall_los_range:
			# If Hall is in LOS, override all other targets
			current_target = great_hall
			_start_attacking()
			return # Found our priority target

	# 2. Find Closest Building (Priority 2)
	var closest_building: Node2D = null
	var closest_distance: float = INF
	
	for target in targets_in_range:
		if not is_instance_valid(target):
			targets_in_range.erase(target)
			continue
			
		# --- FIX: Enforce Collision Mask ---
		if not (target.collision_layer & target_collision_mask):
			continue
		# -----------------------------------
		
		# Target Layer 1 (Player Buildings) or Layer 4 (Enemy Buildings)
		if target.collision_layer & 9: 
			var distance = parent_node.global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_building = target
	
	current_target = closest_building
	
	if current_target:
		_start_attacking()
	else:
		# No buildings in range, stop attacking
		_stop_attacking()
# --- END NEW ---

func _start_attacking() -> void:
	if not is_attacking:
		is_attacking = true
		attack_started.emit(current_target)
	
	# Fire the first attack immediately instead of waiting for the timer.
	_on_attack_timer_timeout()
	
	if attack_timer and attack_timer.is_stopped():
		attack_timer.start()

func _stop_attacking() -> void:
	if is_attacking:
		is_attacking = false
		attack_stopped.emit()
	
	if attack_timer:
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	"""Called when the attack timer fires"""
	if not current_target:
		# If our target is null, we should stop attacking
		_stop_attacking()
		return
	
	# Verify target is still valid and in range
	if not is_instance_valid(current_target):
		_select_target()
		return
	
	var distance_to_target = parent_node.global_position.distance_to(current_target.global_position)
	
	# Added a +10 buffer to prevent units from stopping if target is *just* at the edge
	if distance_to_target > attack_range + 10.0:
		_stop_attacking() 
		return
	
	# Emit signal before attacking
	about_to_attack.emit(current_target, attack_damage)
	
	# Attack the target
	if projectile_scene:
		# RANGED: Spawn projectile
		_spawn_projectile(current_target.global_position)
	else:
		# MELEE: Direct damage
		var target_to_damage = current_target
		
		if target_to_damage.name == "Hitbox":
			target_to_damage = target_to_damage.get_parent()
		
		if target_to_damage.has_method("take_damage"):
			# Pass parent_node as the attacker for retaliation logic
			target_to_damage.take_damage(attack_damage, parent_node)

func _spawn_projectile(target_position_world: Vector2) -> void:
	"""Spawn a projectile towards the target position"""
	if not projectile_scene:
		push_warning("AttackAI: No projectile scene assigned. Cannot fire.")
		return
	
	# 1. Get a projectile from the pool
	var projectile: Projectile = ProjectilePoolManager.get_projectile()
	if not projectile:
		push_error("AttackAI: ProjectilePoolManager failed to provide a projectile.")
		return
	
	# We set our new 'firer' variable instead of the 'owner' property
	projectile.firer = parent_node
	
	projectile.setup(
		parent_node.global_position,  # start position
		target_position_world,        # target position
		attack_damage,                # damage
		projectile_speed,             # Use configured speed
		target_collision_mask         # what to hit
	)
