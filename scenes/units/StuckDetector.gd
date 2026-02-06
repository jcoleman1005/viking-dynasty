#res://scenes/units/StuckDetector.gd
extends Node

# --- CONFIG ---
@export var parent_unit: CharacterBody2D
@export var check_interval: float = 0.5
@export var stuck_limit: int = 2
@export var unit_layer_index: int = 2 

# --- STATE ---
var last_dist_to_target: float = 99999.0
var timer: float = 0.0
var stuck_count: int = 0
var is_phasing: bool = false
var cached_mask: int = 0 

func _ready() -> void:
	if not parent_unit: parent_unit = get_parent()
	await get_tree().process_frame
	if _has_target():
		last_dist_to_target = parent_unit.global_position.distance_to(parent_unit.formation_target)

func _physics_process(delta: float) -> void:
	if not _is_trying_to_move(): 
		_reset_stuck_status()
		return

	timer += delta
	if timer < check_interval: return
	
	# --- CHECK PROGRESS (Every 0.5s) ---
	timer = 0.0
	
	# Calculate current distance to the goal
	var current_dist = 0.0
	if _has_target():
		current_dist = parent_unit.global_position.distance_to(parent_unit.formation_target)
	else:
		_reset_stuck_status()
		return
		
	# DID WE IMPROVE?
	# We expect to move at least 10 pixels CLOSER to the target in 0.5s
	var progress = last_dist_to_target - current_dist
	last_dist_to_target = current_dist
	
	# If we improved by less than 10 pixels (even if we slid 50 pixels sideways), we are stuck.
	if progress < 10.0:
		stuck_count += 1
		if stuck_count >= stuck_limit and not is_phasing:
			_set_phasing(true)
	else:
		# We are making real progress -> CLEAR
		stuck_count = 0
		if is_phasing:
			_set_phasing(false)

func _set_phasing(active: bool) -> void:
	is_phasing = active
	if active:
		cached_mask = parent_unit.collision_mask
		parent_unit.collision_mask = 0  # Phase through everything
		parent_unit.modulate.a = 0.5
	else:
		parent_unit.collision_mask = cached_mask
		parent_unit.modulate.a = 1.0

func _is_trying_to_move() -> bool:
	if "velocity" in parent_unit and parent_unit.velocity.length_squared() > 100.0:
		return true
	return false

func _has_target() -> bool:
	return "formation_target" in parent_unit and parent_unit.formation_target != Vector2.ZERO

func _reset_stuck_status() -> void:
	stuck_count = 0
	timer = 0.0
	if is_phasing: _set_phasing(false)
	# Reset distance tracker so we don't trigger immediately on next move
	if _has_target():
		last_dist_to_target = parent_unit.global_position.distance_to(parent_unit.formation_target)
