# res://scripts/ai/SentryAI.gd
# Simple Sentry AI for enemy defenders in Phase 3
# GDD Ref: Phase 3 - Enemy MVP (Simple Sentry AI)

extends Node2D
class_name SentryAI

@export var detection_radius: float = 80.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.5

var detection_area: Area2D
var attack_timer: float = 0.0
var current_target: Node2D = null

signal enemy_detected(target: Node2D)
signal attack_executed(target: Node2D, damage: int)

func _ready() -> void:
	_setup_detection_area()
	set_process(true)

func _setup_detection_area() -> void:
	"""Create detection area for sentry"""
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = detection_radius
	collision_shape.shape = circle_shape
	
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	# Connect signals
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	# Set collision mask to detect player units (layer 1)
	detection_area.collision_mask = 1

func _process(delta: float) -> void:
	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta
	
	# Check for and attack valid targets
	if current_target and is_instance_valid(current_target):
		if attack_timer <= 0:
			_attack_target(current_target)
			attack_timer = attack_cooldown
	else:
		current_target = null

func _on_body_entered(body: Node2D) -> void:
	"""Handle detection of player units"""
	if body.is_in_group("player_units") and not current_target:
		current_target = body
		enemy_detected.emit(body)
		print("%s detected enemy: %s" % [get_parent().name, body.name])

func _on_body_exited(body: Node2D) -> void:
	"""Handle player units leaving detection range"""
	if body == current_target:
		current_target = null
		print("%s lost target: %s" % [get_parent().name, body.name])

func _attack_target(target: Node2D) -> void:
	"""Execute attack on target"""
	if not target or not is_instance_valid(target):
		return
	
	# Check if target is still in range
	var distance = global_position.distance_to(target.global_position)
	if distance > detection_radius:
		current_target = null
		return
	
	print("%s attacking %s for %d damage" % [get_parent().name, target.name, attack_damage])
	
	# Apply damage if target has take_damage method
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	elif target.has_method("receive_damage"):
		target.receive_damage(attack_damage)
	else:
		# Fallback: just remove the target for demo purposes
		print("Target %s destroyed by sentry attack" % target.name)
		target.queue_free()
	
	attack_executed.emit(target, attack_damage)

func get_detection_radius() -> float:
	"""Get current detection radius"""
	return detection_radius

func set_detection_radius(new_radius: float) -> void:
	"""Update detection radius"""
	detection_radius = new_radius
	if detection_area:
		var collision_shape = detection_area.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = detection_radius

func is_actively_defending() -> bool:
	"""Check if sentry is currently engaged with a target"""
	return current_target != null and is_instance_valid(current_target)
