# res://scripts/units/Base_Unit.gd
#
# --- MODIFIED: Reads movement physics from UnitData resource ---

class_name BaseUnit
extends CharacterBody2D

signal destroyed

## Unit configuration resource containing stats, textures, and movement physics.
## Movement physics (acceleration, linear_damping) are read from this resource:
## • acceleration: How quickly unit reaches target speed (5-20 typical range)
## • linear_damping: How quickly unit stops when no input (1-10 typical range)
@export var data: UnitData : set = set_unit_data
var fsm: UnitFSM
var current_health: int = 50

# Node refs
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var separation_area: Area2D = $SeparationArea

@export_group("AI")
## Enable/disable automatic unit separation to prevent overlap
@export var separation_enabled: bool = true

## How strongly units push away from each other. Higher = more aggressive separation.
## • 1000-2000: Gentle nudging, units can still overlap slightly
## • 3000-5000: Firm separation, good for most units
## • 6000+: Strong repulsion, units bounce off each other noticeably
@export var separation_force: float = 3000.0

## Detection radius for nearby units to separate from (in pixels).
## • 20-30: Tight formations, units must be very close to separate
## • 40-60: Balanced spacing, good for most RTS units  
## • 80+: Wide berth, units maintain large personal space
@export var separation_radius: float = 40.0
# --- REMOVED: Movement Physics Exports ---
# @export var acceleration: float = 10.0
# @export var linear_damping: float = 5.0
# ----------------------------------------

# Color tweening
var _color_tween: Tween
const STATE_COLORS := {
	UnitFSM.State.IDLE: Color(0.3, 0.6, 1.0),     # Blue
	UnitFSM.State.MOVING: Color(0.4, 1.0, 0.4),   # Green
	UnitFSM.State.FORMATION_MOVING: Color(0.4, 1.0, 0.4), # Green
	UnitFSM.State.ATTACKING: Color(1.0, 0.3, 0.3) # Red
}
const ERROR_COLOR := Color(0.7, 0.3, 1.0)         # Purple

func _ready() -> void:
	if not data:
		push_warning("BaseUnit: Node is missing its 'UnitData' resource. Cannot initialize.")
		return
	
	current_health = data.max_health
	
	# --- MODIFIED: Read damping from data resource ---
	# Note: CharacterBody2D doesn't have built-in linear_damp
	# We'll implement manual damping in _physics_process
	# -------------------------------------------------
	
	_apply_texture_and_scale()
	
	# Pass the timer reference to the FSM
	fsm = UnitFSM.new(self, attack_timer)
	
	# Initialize visual to current state color (IDLE by default)
	sprite.modulate = STATE_COLORS.get(UnitFSM.State.IDLE, Color.WHITE)
	
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	# Set separation radius from export
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		area_shape.shape.radius = separation_radius
	else:
		push_warning("'%s' has no 'SeparationArea/CollisionShape2D' with a CircleShape!" % name)

func _apply_texture_and_scale() -> void:
	"""
	Applies the texture from 'data' and scales both the
	sprite and collision shape to match the 'data.target_pixel_size'.
	"""
	
	# 1. Validate the target size
	if data.target_pixel_size.x <= 0 or data.target_pixel_size.y <= 0:
		push_warning("BaseUnit: '%s' has a target_pixel_size of %s, which is invalid." % [data.display_name, data.target_pixel_size])
		return
		
	var target_size: Vector2 = data.target_pixel_size

	# 2. Apply and Scale the Sprite
	if data.visual_texture:
		sprite.texture = data.visual_texture
		var texture_size: Vector2 = sprite.texture.get_size()
		
		if texture_size.x > 0 and texture_size.y > 0:
			# Non-uniform scaling to fill the target size
			var new_scale: Vector2 = target_size / texture_size
			sprite.scale = new_scale
		else:
			push_warning("BaseUnit: Texture for '%s' has an invalid size of %s. Cannot scale sprite." % [data.display_name, texture_size])
	else:
		push_warning("BaseUnit: '%s' is missing its 'visual_texture'. Sprite will be blank or use placeholder." % data.display_name)
		
	# 3. Scale the Collision Shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = target_size
	else:
		push_warning("BaseUnit: '%s' is missing its CollisionShape2D node or its shape is not a RectangleShape2D. Collision will not match visuals." % data.display_name)

func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_grid_pos: Vector2i) -> void:
	if fsm and fsm.current_state == UnitFSM.State.MOVING:
		fsm._recalculate_path()

func _physics_process(delta: float) -> void:
	var fsm_velocity = Vector2.ZERO
	if fsm:
		fsm.update(delta)
		# FSM sets velocity on 'self' (the unit)
		# We grab it, then reset it
		fsm_velocity = velocity
		velocity = Vector2.ZERO # FSM no longer directly controls velocity
	
	var target_velocity = Vector2.ZERO
	
	# 1. FSM "wish"
	if fsm and (fsm.current_state == UnitFSM.State.MOVING or fsm.current_state == UnitFSM.State.FORMATION_MOVING):
		target_velocity = fsm_velocity
	
	# 2. Separation "push"
	if separation_enabled:
		var separation_velocity = _calculate_separation_velocity()
		target_velocity += separation_velocity
	
	# --- MODIFIED: Read acceleration from data resource ---
	# Instead of setting velocity instantly, we interpolate.
	velocity = velocity.lerp(target_velocity, data.acceleration * delta)
	
	# Apply Manual Damping
	# When target_velocity is zero (unit should stop), apply damping
	if target_velocity.is_zero_approx():
		velocity = velocity * exp(-data.linear_damping * delta)
	# ----------------------------------------------------

	move_and_slide()

func _calculate_separation_velocity() -> Vector2:
	var push_vector = Vector2.ZERO
	var neighbors = separation_area.get_overlapping_bodies()
	if neighbors.is_empty():
		return Vector2.ZERO
		
	for neighbor in neighbors:
		if neighbor == self or not neighbor is CharacterBody2D:
			continue
			
		var away_vector = global_position - neighbor.global_position
		
		var distance_sq = away_vector.length_squared()
		
		if distance_sq > 0.01:
			push_vector += away_vector / (distance_sq)
			
	return push_vector * separation_force

# --- Visual State Hooks ---
func on_state_changed(state: UnitFSM.State) -> void:
	var to_color: Color = STATE_COLORS.get(state, Color.WHITE)
	_tween_color(to_color, 0.2)

func flash_error_color() -> void:
	# Quick flash to purple, then return to current state color
	var back_color: Color = STATE_COLORS.get(fsm.current_state, Color.WHITE)
	var t := create_tween()
	t.tween_property(sprite, "modulate", ERROR_COLOR, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate", back_color, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tween_color(to_color: Color, duration: float = 0.2) -> void:
	if _color_tween and _color_tween.is_running():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(sprite, "modulate", to_color, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been killed." % data.display_name)
	destroyed.emit()
	queue_free()

# --- RTS Command Interface ---

func command_move_to(target_pos: Vector2) -> void:
	"""Command this unit to move to a position"""
	if fsm:
		fsm.command_move_to(target_pos)

func command_attack(target: Node2D) -> void:
	"""Command this unit to attack a target"""
	if fsm:
		fsm.command_attack(target)

# --- Selection System ---

var is_selected: bool = false

func set_selected(selected: bool) -> void:
	"""Set the unit's selection state"""
	is_selected = selected
	
	if is_selected:
		_show_selection_indicator()
	else:
		_hide_selection_indicator()

func _show_selection_indicator() -> void:
	"""Show visual selection indicator"""
	queue_redraw()

func _hide_selection_indicator() -> void:
	"""Hide visual selection indicator"""
	queue_redraw()

func _draw() -> void:
	"""Draw unit-specific visuals"""
	if is_selected:
		# Draw selection circle around the unit
		var radius = 25.0
		var color = Color.YELLOW
		color.a = 0.8
		draw_circle(Vector2.ZERO, radius, color, false, 3.0)

# --- Data Setter ---
func set_unit_data(new_data: UnitData) -> void:
	"""Setter for unit data - updates visuals and physics when changed"""
	data = new_data
	if data and is_inside_tree():
		current_health = data.max_health
		_apply_texture_and_scale()
