#res://scripts/ai/DefenderAI.gd
# res://scripts/ai/DefenderAI.gd
class_name DefenderAI
extends AttackAI

# Configuration
@export var guard_radius: float = 300.0
@export var return_speed: float = 100.0

# State
var guard_post: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	if parent_node:
		guard_post = parent_node.global_position
	
	# --- FIX: Widen Vision Mask ---
	# Binary 3 = 0011 (Layer 1 + Layer 2)
	set_target_mask(3) 
	
	# Force ON by default
	set_process(true)
	set_physics_process(true)

func _on_attack_timer_timeout() -> void:
	# 1. Check Leash
	var dist_from_post = parent_node.global_position.distance_to(guard_post)
	
	if dist_from_post > guard_radius:
		# Too far! Abandon chase and return.
		_stop_attacking()
		current_target = null
		_return_to_post()
		return
		
	# 2. Standard Attack Logic
	super._on_attack_timer_timeout()

func _return_to_post() -> void:
	# Access parent FSM to order a move
	if parent_node is BaseUnit and parent_node.fsm:
		parent_node.fsm.command_move_to(guard_post)

func configure_guard_post(pos: Vector2) -> void:
	guard_post = pos
