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
	if body not in targets_in_range: targets_in_range.append(body)
	if not current_target: _select_target()

func _on_target_exited(body: Node2D) -> void:
	targets_in_range.erase(body)
	if current_target == body:
		current_target = null
		_select_target()

func _select_target() -> void:
	# Simplified selection logic for brevity - prioritizing closest
	if targets_in_range.is_empty():
		_stop_attacking()
		return
		
	var closest: Node2D = null
	var min_dist = INF
	
	for t in targets_in_range:
		if not is_instance_valid(t): continue
		if not (t.collision_layer & target_collision_mask): continue
		
		var dist = parent_node.global_position.distance_to(t.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = t
			
	current_target = closest
	if current_target: _start_attacking()
	else: _stop_attacking()

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

func _get_target_radius(target: Node2D) -> float:
	if target.name == "Hitbox" and target.get_parent() is BaseBuilding:
		var b = target.get_parent()
		if b.data: return (min(b.data.grid_size.x, b.data.grid_size.y) * 32.0) / 2.0
	if target is BaseBuilding and target.data:
		return (min(target.data.grid_size.x, target.data.grid_size.y) * 32.0) / 2.0
	return 15.0
