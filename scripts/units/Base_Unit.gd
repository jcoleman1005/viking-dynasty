# res://scripts/units/Base_Unit.gd
# Base unit class for all units in the Viking Dynasty RTS

class_name BaseUnit
extends CharacterBody2D

signal destroyed

@export var data: UnitData
# Removed the : UnitFSM type hint to break the circular dependency.
var fsm
var current_health: int = 50
var attack_ai: AttackAI = null

# Node refs
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var separation_area: Area2D = $SeparationArea

@export_group("AI")
@export var separation_enabled: bool = true
@export var separation_force: float = 30.0
@export var separation_radius: float = 40.0

# Visual state system
var _color_tween: Tween
# --- THIS IS THE FIX ---
# Changed all references from UnitFSM.State to UnitAIConstants.State
const STATE_COLORS := {
	UnitAIConstants.State.IDLE: Color(0.3, 0.6, 1.0),     # Blue
	UnitAIConstants.State.MOVING: Color(0.4, 1.0, 0.4),   # Green
	UnitAIConstants.State.FORMATION_MOVING: Color(0.4, 1.0, 0.4), # Green
	UnitAIConstants.State.ATTACKING: Color(1.0, 0.3, 0.3) # Red
}
# --- END FIX ---
const ERROR_COLOR := Color(0.7, 0.3, 1.0)

func _ready() -> void:
	if not data:
		push_warning("BaseUnit: Node '%s' is missing its 'UnitData' resource. Cannot initialize." % name)
		return
	
	current_health = data.max_health
	_apply_texture_and_scale()
	
	if data.ai_component_scene:
		attack_ai = data.ai_component_scene.instantiate() as AttackAI
		if attack_ai:
			add_child(attack_ai)
			attack_ai.configure_from_data(data)
			
			var target_mask = 0
			if self.collision_layer & 2: # Player unit (Layer 2)
				target_mask = (1 << 2) | (1 << 3) # Target Enemy Units (L3) & Enemy Buildings (L4)
			elif self.collision_layer & 4: # Enemy unit (Layer 3)
				target_mask = (1 << 0) | (1 << 1) # Target Player Buildings (L1) & Player Units (L2)
			
			if target_mask == 0:
				push_warning("BaseUnit: '%s' is on an unhandled collision layer (%s). AI will not target anything." % [name, self.collision_layer])
			
			attack_ai.set_target_mask(target_mask)
		else:
			push_error("BaseUnit: Failed to instantiate ai_component_scene for %s" % data.display_name)
	
	fsm = UnitFSM.new(self, attack_ai)
	
	# --- THIS IS THE FIX ---
	sprite.modulate = STATE_COLORS.get(UnitAIConstants.State.IDLE, Color.WHITE)
	# --- END FIX ---
	
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	separation_area.collision_mask = 2
	
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		area_shape.shape.radius = separation_radius
	else:
		push_warning("'%s' has no 'SeparationArea/CollisionShape2D' with a CircleShape!" % name)

func _apply_texture_and_scale() -> void:
	if data.target_pixel_size.x <= 0 or data.target_pixel_size.y <= 0:
		push_warning("BaseUnit: '%s' has a target_pixel_size of %s, which is invalid." % [data.display_name, data.target_pixel_size])
		return
		
	var target_size: Vector2 = data.target_pixel_size

	if data.visual_texture:
		sprite.texture = data.visual_texture
		var texture_size: Vector2 = sprite.texture.get_size()
		
		if texture_size.x > 0 and texture_size.y > 0:
			var new_scale: Vector2 = target_size / texture_size
			sprite.scale = new_scale
		else:
			push_warning("BaseUnit: Texture for '%s' has an invalid size of %s. Cannot scale sprite." % [data.display_name, texture_size])
	else:
		push_warning("BaseUnit: '%s' is missing its 'visual_texture'. Sprite will be blank or use placeholder." % data.display_name)
		
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = target_size
	else:
		push_warning("BaseUnit: '%s' is missing its CollisionShape2D node or its shape is not a RectangleShape2D. Collision will not match visuals." % data.display_name)

func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_grid_pos: Vector2i) -> void:
	# --- THIS IS THE FIX ---
	if fsm and fsm.current_state == UnitAIConstants.State.MOVING:
	# --- END FIX ---
		fsm._recalculate_path()

func _physics_process(delta: float) -> void:
	if not data:
		return

	var fsm_velocity = Vector2.ZERO
	if fsm:
		fsm.update(delta)
		fsm_velocity = velocity
		velocity = Vector2.ZERO 
	
	var target_fsm_velocity = Vector2.ZERO
	
	# --- THIS IS THE FIX ---
	if fsm and (fsm.current_state == UnitAIConstants.State.MOVING or fsm.current_state == UnitAIConstants.State.FORMATION_MOVING):
	# --- END FIX ---
		target_fsm_velocity = fsm_velocity
	
	if target_fsm_velocity.length() > 0.1:
		velocity = velocity.lerp(target_fsm_velocity, data.acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, data.linear_damping * delta)
	
	if separation_enabled:
		var separation_push = _calculate_separation_push(delta)
		velocity += separation_push

	move_and_slide()

func _calculate_separation_push(delta: float) -> Vector2:
	var push_vector = Vector2.ZERO
	var neighbors = separation_area.get_overlapping_bodies()
	if neighbors.is_empty():
		return Vector2.ZERO
		
	for neighbor in neighbors:
		if neighbor == self or not neighbor is CharacterBody2D:
			continue
			
		var away_vector = global_position - neighbor.global_position
		var distance_sq = away_vector.length_squared()
		
		if distance_sq > 0.01 and distance_sq < separation_radius * separation_radius:
			var push_strength = 1.0 - (sqrt(distance_sq) / separation_radius)
			push_vector += away_vector.normalized() * push_strength
			
	return push_vector * separation_force * delta

# --- THIS IS THE FIX ---
func on_state_changed(state: UnitAIConstants.State) -> void:
# --- END FIX ---
	var to_color: Color = STATE_COLORS.get(state, Color.WHITE)
	_tween_color(to_color, 0.2)

func flash_error_color() -> void:
	var back_color: Color = STATE_COLORS.get(fsm.current_state, Color.WHITE)
	var t := create_tween()
	t.tween_property(sprite, "modulate", ERROR_COLOR, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate", back_color, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tween_color(to_color: Color, duration: float = 0.2) -> void:
	if _color_tween and _color_tween.is_running():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(sprite, "modulate", to_color, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- MODIFIED: Added attacker parameter ---
func take_damage(amount: int, attacker: Node2D = null) -> void:
	current_health = max(0, current_health - amount)
	
	# --- NEW: Retaliation Logic ---
	if fsm and is_instance_valid(attacker):
		# Tell the FSM we are being attacked
		fsm.command_defensive_attack(attacker)
	# --- END NEW ---
	
	if current_health == 0:
		die()

func die() -> void:
	destroyed.emit()
	queue_free()

func command_move_to(target_pos: Vector2) -> void:
	if fsm:
		fsm.command_move_to(target_pos)

func command_attack(target: Node2D) -> void:
	if fsm:
		fsm.command_attack(target)

var is_selected: bool = false

func set_selected(selected: bool) -> void:
	is_selected = selected
	
	if is_selected:
		_show_selection_indicator()
	else:
		_hide_selection_indicator()

func _show_selection_indicator() -> void:
	queue_redraw()

func _hide_selection_indicator() -> void:
	queue_redraw()

func _draw() -> void:
	if is_selected:
		var radius = 25.0
		var color = Color.YELLOW
		color.a = 0.8
		draw_circle(Vector2.ZERO, radius, color, false, 3.0)
