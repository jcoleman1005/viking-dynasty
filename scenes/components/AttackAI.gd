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

# Configuration - set these from the parent
@export var attack_damage: int = 10
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0  # attacks per second
@export var projectile_scene: PackedScene
@export var target_collision_mask: int = 0  # What layers to target

# --- NEW: Added projectile speed ---
var projectile_speed: float = 400.0
# ---------------------------------

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
	# Configure detection area
	if detection_area:
		detection_area.collision_layer = 0  # AI components don't need to be on any layer
		detection_area.collision_mask = target_collision_mask
		
		# Scale detection area to match attack range
		if detection_area.get_child(0) is CollisionShape2D:
			var detection_shape = detection_area.get_child(0) as CollisionShape2D
			if detection_shape.shape is CircleShape2D:
				(detection_shape.shape as CircleShape2D).radius = attack_range
		
		# Connect detection signals
		detection_area.body_entered.connect(_on_target_entered)
		detection_area.body_exited.connect(_on_target_exited)
	
	# Configure attack timer
	if attack_timer:
		attack_timer.wait_time = 1.0 / attack_speed
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func configure_from_data(data_resource) -> void:
	"""Configure the AI from a unit or building data resource"""
	if not data_resource:
		return
	
	# Extract common properties that both UnitData and BuildingData should have
	if "attack_damage" in data_resource:
		attack_damage = data_resource.attack_damage
	if "attack_range" in data_resource:
		attack_range = data_resource.attack_range
	if "attack_speed" in data_resource:
		attack_speed = data_resource.attack_speed
	if "projectile_scene" in data_resource:
		projectile_scene = data_resource.projectile_scene
	
	# --- NEW: Read projectile speed ---
	if "projectile_speed" in data_resource:
		projectile_speed = data_resource.projectile_speed
	# ----------------------------------
	
	# Update attack timer if it exists
	if attack_timer:
		if attack_speed > 0:
			attack_timer.wait_time = 1.0 / attack_speed
		else:
			attack_timer.wait_time = 999.0 # Effectively disable timer if speed is 0
	
	# Update detection radius if it exists
	if detection_area and detection_area.get_child(0) is CollisionShape2D:
		var detection_shape = detection_area.get_child(0) as CollisionShape2D
		if detection_shape.shape is CircleShape2D:
			(detection_shape.shape as CircleShape2D).radius = attack_range

func set_target_mask(mask: int) -> void:
	"""Set what collision layers this AI should target"""
	target_collision_mask = mask
	if detection_area:
		detection_area.collision_mask = mask

func force_target(target: Node2D) -> void:
	"""Force the AI to target a specific node (useful for player commands)"""
	if not is_instance_valid(target):
		return
	
	current_target = target
	if target not in targets_in_range:
		targets_in_range.append(target)
	
	_start_attacking()

func stop_attacking() -> void:
	"""Stop all attack behavior"""
	current_target = null
	targets_in_range.clear()
	_stop_attacking()

func _on_target_entered(body: Node2D) -> void:
	"""Called when a potential target enters detection range"""
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
		_stop_attacking()
		return
	
	# Find closest target
	var closest_target: Node2D = null
	var closest_distance: float = INF
	
	for target in targets_in_range:
		if is_instance_valid(target):
			var distance = parent_node.global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
		else:
			# Remove invalid targets
			targets_in_range.erase(target)
	
	current_target = closest_target
	if current_target:
		_start_attacking()

func _start_attacking() -> void:
	"""Begin attacking the current target"""
	if not is_attacking:
		is_attacking = true
		attack_started.emit(current_target)
	
	if attack_timer and attack_timer.is_stopped():
		attack_timer.start()

func _stop_attacking() -> void:
	"""Stop attacking"""
	if is_attacking:
		is_attacking = false
		attack_stopped.emit()
	
	if attack_timer:
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	"""Called when the attack timer fires"""
	if not current_target:
		return
	
	# Verify target is still valid and in range
	if not is_instance_valid(current_target):
		_select_target()
		return
	
	var distance_to_target = parent_node.global_position.distance_to(current_target.global_position)
	# Use a small buffer (e.g., 10 pixels) for range check
	if distance_to_target > attack_range + 10.0:
		_select_target()
		return
	
	# Emit signal before attacking
	about_to_attack.emit(current_target, attack_damage)
	
	# Attack the target
	if projectile_scene:
		# RANGED: Spawn projectile
		_spawn_projectile(current_target.global_position)
	else:
		# MELEE: Direct damage
		if current_target.has_method("take_damage"):
			current_target.take_damage(attack_damage)

func _spawn_projectile(target_position_world: Vector2) -> void:
	"""Spawn a projectile towards the target position"""
	if not projectile_scene:
		print("Error: No projectile scene assigned to AttackAI")
		return
	
	# Create the projectile
	var projectile: Projectile = projectile_scene.instantiate()
	if not projectile:
		print("Error: Failed to instantiate projectile for AttackAI")
		return
	
	# Add projectile to the current scene
	parent_node.get_tree().current_scene.add_child(projectile)
	
	# Initialize the projectile
	projectile.setup(
		parent_node.global_position,  # start position
		target_position_world,        # target position
		attack_damage,                # damage
		projectile_speed,             # --- MODIFIED: Use configured speed ---
		target_collision_mask         # what to hit
	)
