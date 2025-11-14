# res://scripts/units/Base_Unit.gd
class_name BaseUnit
extends CharacterBody2D

signal destroyed
signal fsm_ready(unit)

@export var data: UnitData
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
const STATE_COLORS := {
	UnitAIConstants.State.IDLE: Color(0.3, 0.6, 1.0),     # Blue
	UnitAIConstants.State.MOVING: Color(0.4, 1.0, 0.4),   # Green
	UnitAIConstants.State.FORMATION_MOVING: Color(0.4, 1.0, 0.4), # Green
	UnitAIConstants.State.ATTACKING: Color(1.0, 0.3, 0.3) # Red
}
const ERROR_COLOR := Color(0.7, 0.3, 1.0)

# --- Collision Layer Constants ---
const LAYER_ENV = 1
const LAYER_PLAYER_UNIT = 2
const LAYER_ENEMY_UNIT = 4
const LAYER_ENEMY_BLDG = 8

func _ready() -> void:
	if not data:
		push_warning("BaseUnit: Node '%s' is missing its 'UnitData' resource. Cannot initialize." % name)
		return
	
	current_health = data.max_health
	_apply_texture_and_scale()
	
	# --- NEW: Setup Dynamic Collision Logic ---
	_setup_collision_logic()
	# ----------------------------------------
	
	call_deferred("_deferred_setup")
	
	sprite.modulate = STATE_COLORS.get(UnitAIConstants.State.IDLE, Color.WHITE)
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		area_shape.shape.radius = separation_radius
	else:
		push_warning("'%s' has no 'SeparationArea/CollisionShape2D' with a CircleShape!" % name)

func _setup_collision_logic() -> void:
	"""
	Configures physics and separation masks based on whether this is a Player or Enemy unit.
	Note: _ready() runs after the spawner has set 'collision_layer', so we can rely on it here.
	"""
	
	# 1. Define Masks
	var physics_mask = 0
	var separation_mask = 0
	
	# Determine Faction based on Layer
	var is_player = (collision_layer & LAYER_PLAYER_UNIT) != 0
	var is_enemy = (collision_layer & LAYER_ENEMY_UNIT) != 0
	
	if is_player:
		# Player Physics: Walls (L1) + Enemies (L3) + Enemy Buildings (L4)
		# Note: We exclude Friendlies (L2) from hard physics to prevent getting stuck, rely on separation.
		physics_mask = LAYER_ENV | LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG
		
	elif is_enemy:
		# Enemy Physics: Walls (L1) + Players (L2) + Enemy Buildings (L4)
		# Note: Enemy Buildings are L4. Enemy units should probably stop at them too.
		physics_mask = LAYER_ENV | LAYER_PLAYER_UNIT | LAYER_ENEMY_BLDG
		
	else:
		# Fallback for test units or misconfigured layers
		physics_mask = LAYER_ENV | LAYER_PLAYER_UNIT | LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG

	# 2. Apply Physics Mask (Movement)
	self.collision_mask = physics_mask
	
	# 3. Apply Separation Mask (Spacing)
	# Units should separate from ALL other moving units to avoid stacking "deathballs".
	separation_mask = LAYER_PLAYER_UNIT | LAYER_ENEMY_UNIT
	
	if separation_area:
		separation_area.collision_mask = separation_mask
	
	# Debug output to verify
	# print("Unit %s (%s) Masks Set -> Phys: %d, Sep: %d" % [name, "Player" if is_player else "Enemy", physics_mask, separation_mask])

func _deferred_setup() -> void:
	"""Initializes AttackAI and FSM after all children are guaranteed to be in the tree."""
	
	_create_unit_hitbox()
	
	if data.ai_component_scene:
		attack_ai = data.ai_component_scene.instantiate() as AttackAI
		if attack_ai:
			add_child(attack_ai)
			attack_ai.configure_from_data(data)
			
			var target_mask = 0
			
			if self.collision_layer & LAYER_PLAYER_UNIT: # Player unit
				# Target Enemy Units (L3) & Enemy Buildings (L4)
				target_mask = LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG
				
			elif self.collision_layer & LAYER_ENEMY_UNIT: # Enemy unit
				# Target Player Buildings (L1) & Player Units (L2)
				target_mask = LAYER_ENV | LAYER_PLAYER_UNIT
			
			if target_mask == 0:
				push_warning("BaseUnit: '%s' is on an unhandled collision layer (%s). AI will not target anything." % [name, self.collision_layer])
			
			attack_ai.set_target_mask(target_mask)
		else:
			push_error("BaseUnit: Failed to instantiate ai_component_scene for %s" % data.display_name)
	
	fsm = UnitFSM.new(self, attack_ai)
	fsm_ready.emit(self)
	
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
	if fsm and fsm.current_state == UnitAIConstants.State.MOVING:
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
	
	if fsm and (fsm.current_state == UnitAIConstants.State.MOVING or fsm.current_state == UnitAIConstants.State.FORMATION_MOVING):
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
	# We use get_overlapping_bodies, which respects the collision_mask we set in _setup_collision_logic
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

func on_state_changed(state: UnitAIConstants.State) -> void:
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

func take_damage(amount: int, attacker: Node2D = null) -> void:
	current_health = max(0, current_health - amount)
	
	if fsm and is_instance_valid(attacker):
		fsm.command_defensive_attack(attacker)
	
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

func _create_unit_hitbox() -> void:
	var hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	
	# --- LAYER DEBUGGING ---
	var layer_value = 0
	
	# Player (Layer 2) -> Hitbox Layer 2 (Value 2)
	if self.collision_layer & LAYER_PLAYER_UNIT: 
		layer_value = LAYER_PLAYER_UNIT
	# Enemy (Layer 3) -> Hitbox Layer 3 (Value 4)
	elif self.collision_layer & LAYER_ENEMY_UNIT:
		layer_value = LAYER_ENEMY_UNIT
	else:
		layer_value = LAYER_PLAYER_UNIT # Fallback
		
	hitbox_area.collision_layer = layer_value
	# -------------------------
	
	hitbox_area.collision_mask = 0  # Hitboxes don't scan; they get scanned
	hitbox_area.monitorable = true 
	hitbox_area.monitoring = false
	
	# --- SHAPE FIX: Force a new unique shape ---
	var hitbox_shape = CollisionShape2D.new()
	var shape_to_use
	
	# Try to copy parent shape, but ensure it's unique
	if collision_shape and collision_shape.shape:
		shape_to_use = collision_shape.shape.duplicate()
	else:
		# Fallback if parent shape is missing
		shape_to_use = CircleShape2D.new()
		shape_to_use.radius = 15.0 # Standard unit radius
	
	hitbox_shape.shape = shape_to_use
	# ------------------------------------------
	
	hitbox_area.add_child(hitbox_shape)
	add_child(hitbox_area)
	
	# print("Unit %s created Hitbox on Layer Value: %d" % [name, layer_value])
