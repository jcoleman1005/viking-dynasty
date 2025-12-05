# res://scripts/units/Base_Unit.gd
class_name BaseUnit
extends CharacterBody2D

signal destroyed
signal fsm_ready(unit)

@export var data: UnitData

# --- NEW: WARBAND IDENTITY ---
## The specific Warband this unit belongs to.
## If null, this unit is temporary/mercenary.
var warband_ref: WarbandData
# -----------------------------

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

# --- NEW: Death State Flag ---
var _is_dying: bool = false

func _ready() -> void:
	if not data:
		push_warning("BaseUnit: Node '%s' is missing 'UnitData'." % name)
		return
	
	var hp_mult = 1.0
	var dmg_mult = 1.0
	# Speed is handled by UnitData base, modified by Captains only for now
	# --- NEW: THOR MODIFIER ---
	# Global buff for all player units
	if is_in_group("player_units") and DynastyManager.active_year_modifiers.has("BLOT_THOR"):
		dmg_mult *= 1.10 # +10% Damage
	
	if warband_ref:
		# 1. Apply Veterancy (XP)
		var level_mult = warband_ref.get_stat_multiplier()
		hp_mult *= level_mult
		dmg_mult *= level_mult
		
		# 2. Apply Gear (Gold) - NEW
		hp_mult *= warband_ref.get_gear_health_mult()
		dmg_mult *= warband_ref.get_gear_damage_mult()
		# -----------------------------
		
		# 3. Apply Heir Leadership
		if warband_ref.assigned_heir_name != "":
			var heir = DynastyManager.find_heir_by_name(warband_ref.assigned_heir_name)
			if heir:
				if heir.prowess > 5:
					var p_bonus = 1.0 + ((heir.prowess - 5) * 0.10)
					dmg_mult *= p_bonus
				modulate = Color(1.2, 1.2, 0.8) 
				Loggie.msg("Unit %s buffed by Captain %s!" % [name, heir.display_name]).domain("UNIT").info()

	current_health = int(data.max_health * hp_mult)
	
	_apply_texture_and_scale()
	_setup_collision_logic()
	call_deferred("_deferred_setup", dmg_mult)
	
	sprite.modulate = STATE_COLORS.get(UnitAIConstants.State.IDLE, Color.WHITE)
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		area_shape.shape.radius = separation_radius
	else:
		push_warning("'%s' has no 'SeparationArea/CollisionShape2D' with a CircleShape!" % name)

func _setup_collision_logic() -> void:
	var physics_mask = 0
	var separation_mask = 0
	var is_player = (collision_layer & LAYER_PLAYER_UNIT) != 0
	var is_enemy = (collision_layer & LAYER_ENEMY_UNIT) != 0
	
	if is_player:
		physics_mask = LAYER_ENV | LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG
	elif is_enemy:
		physics_mask = LAYER_ENV | LAYER_PLAYER_UNIT | LAYER_ENEMY_BLDG
	else:
		physics_mask = LAYER_ENV | LAYER_PLAYER_UNIT | LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG

	self.collision_mask = physics_mask
	separation_mask = LAYER_PLAYER_UNIT | LAYER_ENEMY_UNIT
	
	if separation_area:
		separation_area.collision_mask = separation_mask

func _deferred_setup(damage_mult: float = 1.0) -> void:
	_create_unit_hitbox()
	
	if not data.ai_component_scene:
		push_error("CRITICAL CONFIG ERROR: Unit '%s' (%s) has NO 'ai_component_scene' assigned! It will be brainless." % [name, data.display_name])
		return
		
	if data.ai_component_scene:
		attack_ai = data.ai_component_scene.instantiate() as AttackAI
		if attack_ai:
			add_child(attack_ai)
			attack_ai.configure_from_data(data)
			
			# --- NEW: Apply Damage Buff ---
			attack_ai.attack_damage = int(attack_ai.attack_damage * damage_mult)
			
			var target_mask = 0
			if self.collision_layer & LAYER_PLAYER_UNIT: 
				target_mask = LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG
			elif self.collision_layer & LAYER_ENEMY_UNIT: 
				target_mask = LAYER_ENV | LAYER_PLAYER_UNIT
			
			attack_ai.set_target_mask(target_mask)
		else:
			push_error("BaseUnit: Failed to instantiate ai_component_scene for %s" % data.display_name)
	
	fsm = UnitFSM.new(self, attack_ai)
	fsm_ready.emit(self)
	
func _apply_texture_and_scale() -> void:
	if data.target_pixel_size.x <= 0 or data.target_pixel_size.y <= 0:
		return
	var target_size: Vector2 = data.target_pixel_size

	# 1. Apply Texture override from Data (if present)
	if data.visual_texture:
		sprite.texture = data.visual_texture
	
	# 2. Apply Scaling (Always runs, even if using the default Scene texture)
	if sprite.texture:
		var texture_size: Vector2 = sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			sprite.scale = target_size / texture_size
	
	# 3. Apply Collision Sizing
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = target_size

func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_grid_pos: Vector2i) -> void:
	if fsm and fsm.current_state == UnitAIConstants.State.MOVING:
		fsm._recalculate_path()

func _physics_process(delta: float) -> void:
	if not data: return

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

# --- FIX: Deferred Death Handling ---
func take_damage(amount: int, attacker: Node2D = null) -> void:
	# Prevent multiple damage sources triggering death in the same frame
	if _is_dying: return

	current_health = max(0, current_health - amount)
	
	if fsm and is_instance_valid(attacker):
		fsm.command_defensive_attack(attacker)
	
	if current_health == 0:
		_is_dying = true
		# Critical: Must use call_deferred to avoid modifying scene tree during physics callback
		call_deferred("die")
# ------------------------------------

func die() -> void:
	if is_in_group("player_units"):
		EventBus.player_unit_died.emit(self)
		
	destroyed.emit()
	queue_free()

func command_move_to(target_pos: Vector2) -> void:
	if fsm: fsm.command_move_to(target_pos)

func command_attack(target: Node2D) -> void:
	if fsm: fsm.command_attack(target)

var is_selected: bool = false

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _draw() -> void:
	if is_selected:
		var radius = 25.0
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 0, 0.8), false, 3.0)

func _create_unit_hitbox() -> void:
	var hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	
	var layer_value = 0
	if self.collision_layer & LAYER_PLAYER_UNIT: layer_value = LAYER_PLAYER_UNIT
	elif self.collision_layer & LAYER_ENEMY_UNIT: layer_value = LAYER_ENEMY_UNIT
	else: layer_value = LAYER_PLAYER_UNIT
		
	hitbox_area.collision_layer = layer_value
	hitbox_area.collision_mask = 0
	hitbox_area.monitorable = true 
	hitbox_area.monitoring = false
	
	var hitbox_shape = CollisionShape2D.new()
	var shape_to_use
	
	if collision_shape and collision_shape.shape:
		shape_to_use = collision_shape.shape.duplicate()
	else:
		shape_to_use = CircleShape2D.new()
		shape_to_use.radius = 15.0
	
	hitbox_shape.shape = shape_to_use
	hitbox_area.add_child(hitbox_shape)
	add_child(hitbox_area)
	
func command_retreat(target_pos: Vector2) -> void:
	if fsm:
		fsm.command_retreat(target_pos)

func command_start_working(target_building: BaseBuilding, target_node: ResourceNode) -> void:
	if fsm and fsm.has_method("command_start_cycle"):
		fsm.command_start_cycle(target_building, target_node)
	else:
		push_warning("Unit %s tried to start working, but FSM missing 'command_start_cycle'." % name)
