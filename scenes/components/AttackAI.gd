# res://scenes/components/AttackAI.gd
class_name AttackAI
extends Node2D

signal attack_started(target: Node2D)
signal attack_stopped()
signal about_to_attack(target: Node2D, damage: int)

enum AI_Mode { DEFAULT, DEFENSIVE_SIEGE }
@export var ai_mode: AI_Mode = AI_Mode.DEFAULT
@export var great_hall_los_range: float = 600.0

@export var attack_damage: int = 10
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0 
@export var projectile_scene: PackedScene
# --- RESTORED ---
var building_attack_range: float = 45.0
# ----------------

var target_collision_mask: int = 0
var projectile_speed: float = 400.0

@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

var parent_node: Node2D
var current_target: Node2D = null
var targets_in_range: Array[Node2D] = []
var is_attacking: bool = false

func _ready() -> void:
	parent_node = get_parent() as Node2D
	if not parent_node: return
	_setup_ai()

func _setup_ai() -> void:
	if detection_area:
		detection_area.collision_layer = 0
		detection_area.collision_mask = target_collision_mask
		if detection_area.get_child(0) is CollisionShape2D:
			var s = detection_area.get_child(0) as CollisionShape2D
			if s.shape is CircleShape2D: (s.shape as CircleShape2D).radius = attack_range
		detection_area.body_entered.connect(_on_target_entered)
		detection_area.area_entered.connect(_on_target_entered)
		detection_area.body_exited.connect(_on_target_exited)
		detection_area.area_exited.connect(_on_target_exited)
	
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		if attack_speed > 0: attack_timer.wait_time = 1.0 / attack_speed

func configure_from_data(data) -> void:
	if not data: return
	if "attack_damage" in data: attack_damage = data.attack_damage
	if "attack_range" in data: attack_range = data.attack_range
	# --- RESTORED ---
	if "building_attack_range" in data: building_attack_range = data.building_attack_range
	# ----------------
	if "attack_speed" in data: attack_speed = data.attack_speed
	if "projectile_scene" in data: projectile_scene = data.projectile_scene
	if "projectile_speed" in data: projectile_speed = data.projectile_speed
	
	if attack_timer and attack_speed > 0: attack_timer.wait_time = 1.0 / attack_speed

func set_target_mask(mask: int) -> void:
	target_collision_mask = mask
	if detection_area: detection_area.collision_mask = mask

func force_target(target: Node2D) -> void:
	if not is_instance_valid(target): return
	if target is BaseBuilding and target.has_node("Hitbox"): current_target = target.get_node("Hitbox")
	else: current_target = target
	if current_target not in targets_in_range: targets_in_range.append(current_target)
	_start_attacking()

func stop_attacking() -> void:
	current_target = null
	_stop_attacking()

func _on_target_entered(body: Node2D) -> void:
	#Ignore targets if Brain is disabled (Pillaging) ---
	if not is_processing(): return
	
	if body not in targets_in_range: targets_in_range.append(body)
	if not current_target: _select_target()

func _on_target_exited(body: Node2D) -> void:
	targets_in_range.erase(body)
	if current_target == body:
		current_target = null
		_select_target()

func _select_target() -> void:
	# --- FIX: Don't pick targets if disabled (Pillaging) ---
	if not is_processing(): return
	# -------------------------------------------
	
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
	
	# Priority: Units First
	var search_list = unit_targets if not unit_targets.is_empty() else building_targets
	
	for target in search_list:
		# Use Smart Range (Edge-to-Edge)
		var dist_center = parent_node.global_position.distance_to(target.global_position)
		var radius = _get_target_radius(target)
		var distance = max(0, dist_center - radius)
		
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
	# The FSM holds the "Main Objective" target
	var great_hall = unit_parent.fsm.objective_target
	if is_instance_valid(great_hall):
		var hall_pos = great_hall.global_position
		var distance_to_hall = parent_node.global_position.distance_to(hall_pos)
		
		# If the Great Hall is within "Line of Sight", ignore everything else
		if distance_to_hall <= great_hall_los_range:
			current_target = great_hall
			_start_attacking()
			return

	# 2. Find Closest Building (Priority 2)
	# If we can't see the Hall, attack whatever building is closest
	var closest_building: Node2D = null
	var closest_distance: float = INF
	
	for target in targets_in_range:
		if not is_instance_valid(target):
			targets_in_range.erase(target)
			continue
			
		if not (target.collision_layer & target_collision_mask):
			continue
		
		# Check if it's a Building (Layer 1 or 4 typically)
		# 9 = Binary 1001 (Layer 1 + Layer 4)
		if target.collision_layer & 9: 
			# Use Smart Range (Edge-to-Edge)
			var dist_center = parent_node.global_position.distance_to(target.global_position)
			var radius = _get_target_radius(target)
			var distance = max(0, dist_center - radius)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_building = target
	
	current_target = closest_building
	
	if current_target:
		_start_attacking()
	else:
		_stop_attacking()

# --- HELPER: Get Target Radius ---
func _get_target_radius(target: Node2D) -> float:
	"""
	Estimates the radius of the target for accurate distance checks.
	Crucial for large buildings.
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

func _start_attacking() -> void:
	if not is_attacking:
		is_attacking = true
		attack_started.emit(current_target)
	_on_attack_timer_timeout()
	if attack_timer and attack_timer.is_stopped(): attack_timer.start()

func _stop_attacking() -> void:
	if is_attacking:
		is_attacking = false
		attack_stopped.emit()
	if attack_timer: attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if not is_processing(): 
		_stop_attacking()
		return
		
	if not is_instance_valid(current_target):
		_stop_attacking()
		return
		
	# --- RESTORED: Smart Range Logic ---
	var limit = attack_range
	if current_target is BaseBuilding or (current_target.name == "Hitbox" and current_target.get_parent() is BaseBuilding):
		limit = building_attack_range
		
	var dist = parent_node.global_position.distance_to(current_target.global_position)
	var r_target = _get_target_radius(current_target)
	var r_self = 15.0 # Approx unit radius
	var surface_dist = max(0, dist - r_target - r_self)
	
	if surface_dist > limit + 10.0:
		_stop_attacking()
		return
	# -----------------------------------

	about_to_attack.emit(current_target, attack_damage)
	
	if projectile_scene:
		_spawn_projectile(current_target.global_position)
	else:
		var t = current_target
		if t.name == "Hitbox": t = t.get_parent()
		if t.has_method("take_damage"): t.take_damage(attack_damage, parent_node)

func _spawn_projectile(target_pos: Vector2) -> void:
	if not projectile_scene: return
	var p = ProjectilePoolManager.get_projectile()
	if p: 
		p.firer = parent_node
		p.setup(parent_node.global_position, target_pos, attack_damage, projectile_speed, target_collision_mask)
