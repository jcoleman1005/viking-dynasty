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
		
		# Enforce Collision Mask
		if not (target.collision_layer & target_collision_mask):
			continue

		# Determine type based on layer
		if target.collision_layer & 6: # Layer 2 or 3 (Units)
			unit_targets.append(target)
		elif target.collision_layer & 9: # Layer 1 or 4 (Buildings)
			building_targets.append(target)

	var closest_target: Node2D = null
	var closest_distance: float = INF
	
	# Prioritize Units over Buildings
	if not unit_targets.is_empty():
		for target in unit_targets:
			# Use simple distance for units (usually small)
			var distance = parent_node.global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
	elif not building_targets.is_empty():
		for target in building_targets:
			# --- FIX: Edge-to-Edge Distance logic for selection ---
			var dist_center = parent_node.global_position.distance_to(target.global_position)
			var radius = _get_target_radius(target)
			var distance = max(0, dist_center - radius)
			# ------------------------------------------------------
			
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
	
	current_target = closest_target
	
	if current_target:
		_start_attacking()
	else:
		_stop_attacking()

func _select_target_defensive_siege() -> void:
	"""
	Enemy AI logic: Prioritize Great Hall, then closest building.
	"""
	var unit_parent = parent_node as BaseUnit
	if not is_instance_valid(unit_parent) or not unit_parent.fsm:
		_stop_attacking()
		return

	# 1. Check for Great Hall (Priority 1)
	var great_hall = unit_parent.fsm.objective_target
	if is_instance_valid(great_hall):
		var hall_pos = great_hall.global_position
		# Use center distance for LOS check (simple)
		var distance_to_hall = parent_node.global_position.distance_to(hall_pos)
		
		if distance_to_hall <= great_hall_los_range:
			current_target = great_hall
			_start_attacking()
			return

	# 2. Find Closest Building (Priority 2)
	var closest_building: Node2D = null
	var closest_distance: float = INF
	
	for target in targets_in_range:
		if not is_instance_valid(target):
			targets_in_range.erase(target)
			continue
			
		if not (target.collision_layer & target_collision_mask):
			continue
		
		if target.collision_layer & 9: # Buildings
			# --- FIX: Edge-to-Edge Distance logic for selection ---
			var dist_center = parent_node.global_position.distance_to(target.global_position)
			var radius = _get_target_radius(target)
			var distance = max(0, dist_center - radius)
			# ------------------------------------------------------
			
			if distance < closest_distance:
				closest_distance = distance
				closest_building = target
	
	current_target = closest_building
	
	if current_target:
		_start_attacking()
	else:
		_stop_attacking()

func _start_attacking() -> void:
	if not is_attacking:
		is_attacking = true
		attack_started.emit(current_target)
	
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
		_stop_attacking()
		return
	
	if not is_instance_valid(current_target):
		_select_target()
		return
	
	var distance_to_target = parent_node.global_position.distance_to(current_target.global_position)
	
	# --- FIX: Subtract Target Radius for Large Buildings ---
	var target_radius = _get_target_radius(current_target)
	var effective_distance = max(0, distance_to_target - target_radius)
	
	# Tolerance: Range + 10 buffer
	if effective_distance > attack_range + 10.0:
		_stop_attacking() 
		return
	# -----------------------------------------------------
	
	about_to_attack.emit(current_target, attack_damage)
	
	if projectile_scene:
		_spawn_projectile(current_target.global_position)
	else:
		var target_to_damage = current_target
		
		if target_to_damage.name == "Hitbox":
			target_to_damage = target_to_damage.get_parent()
		
		if target_to_damage.has_method("take_damage"):
			target_to_damage.take_damage(attack_damage, parent_node)

func _spawn_projectile(target_position_world: Vector2) -> void:
	if not projectile_scene: return
	
	var projectile: Projectile = ProjectilePoolManager.get_projectile()
	if not projectile: return
	
	projectile.firer = parent_node
	
	projectile.setup(
		parent_node.global_position,
		target_position_world,
		attack_damage,
		projectile_speed,
		target_collision_mask
	)

# --- NEW HELPER: Get Target Radius ---
func _get_target_radius(target: Node2D) -> float:
	"""
	Estimates the radius of the target.
	Crucial for attacking large buildings (Great Hall).
	"""
	# 1. Check if it's a Building Hitbox
	if target.name == "Hitbox" and target.get_parent() is BaseBuilding:
		var building = target.get_parent() as BaseBuilding
		if building.data:
			# Approximate radius as half the smallest side of the building
			# (32 is standard cell size)
			var size = min(building.data.grid_size.x, building.data.grid_size.y)
			return (size * 32.0) / 2.0
			
	# 2. Check if it's a Unit (BaseUnit)
	if target is BaseUnit:
		return 15.0 # Standard unit radius
		
	# 3. Fallback: Check for CollisionShape
	var col = target.get_node_or_null("CollisionShape2D")
	if col:
		if col.shape is CircleShape2D:
			return col.shape.radius
		elif col.shape is RectangleShape2D:
			var extents = col.shape.size / 2.0
			return min(extents.x, extents.y)
			
	return 0.0
