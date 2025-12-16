# res://scripts/units/Base_Unit.gd
class_name BaseUnit
extends CharacterBody2D

signal destroyed
signal fsm_ready(unit)

@export var data: UnitData
var unit_identity: String = ""
var warband_ref: WarbandData

var fsm
var current_health: int = 50
var attack_ai: AttackAI = null

# Node refs
@onready var attack_timer: Timer = $AttackTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var separation_area: Area2D = $SeparationArea

# --- VISUAL SYSTEM UPDATE ---
@onready var sprite_2d: Sprite2D = $Sprite2D
# Note: Add 'AnimatedSprite2D' to your scene in the Editor!
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

# We track which node is actually being used
var _active_visual: Node2D = null
# -----------------------------

@export_group("AI")
@export var separation_enabled: bool = true
@export var separation_force: float = 30.0
@export var separation_radius: float = 40.0

var _color_tween: Tween
const STATE_COLORS := {
	UnitAIConstants.State.IDLE: Color(0.3, 0.6, 1.0),
	UnitAIConstants.State.MOVING: Color(0.4, 1.0, 0.4),
	UnitAIConstants.State.FORMATION_MOVING: Color(0.4, 1.0, 0.4),
	UnitAIConstants.State.ATTACKING: Color(1.0, 0.3, 0.3)
}
const ERROR_COLOR := Color(0.7, 0.3, 1.0)

const LAYER_ENV = 1
const LAYER_PLAYER_UNIT = 2
const LAYER_ENEMY_UNIT = 4
const LAYER_ENEMY_BLDG = 8

var _is_dying: bool = false

signal inventory_updated(current_load: int, max_load: int)
var inventory: Dictionary[String, int] = {} 
var current_loot_weight: int = 0

func _ready() -> void:
	if not data:
		Loggie.msg("BaseUnit: Node '%s' is missing 'UnitData'." % name).domain(LogDomains.UNIT).error()
		return
	
	_setup_visuals()
	
	var hp_mult = 1.0
	var dmg_mult = 1.0
	
	if is_in_group("player_units") and DynastyManager.active_year_modifiers.has("BLOT_THOR"):
		dmg_mult *= 1.10
	
	if warband_ref:
		var level_mult = warband_ref.get_stat_multiplier()
		hp_mult *= level_mult
		dmg_mult *= level_mult
		
		hp_mult *= warband_ref.get_gear_health_mult()
		dmg_mult *= warband_ref.get_gear_damage_mult()
		
		if unit_identity == "":
			unit_identity = DynastyGenerator.get_random_viking_name()
			
	current_health = int(data.max_health * hp_mult)
	
	_setup_collision_logic()
	call_deferred("_deferred_setup", dmg_mult)
	
	# Initial state color/animation
	on_state_changed(UnitAIConstants.State.IDLE)
		
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		area_shape.shape.radius = separation_radius

func _setup_visuals() -> void:
	# Priority 1: SCENE CONFIGURATION (Editor Handling)
	# If you set up an AnimatedSprite2D in the scene and gave it frames, we use that.
	if animated_sprite and animated_sprite.sprite_frames:
		_active_visual = animated_sprite
		animated_sprite.visible = true
		if sprite_2d: sprite_2d.visible = false
		Loggie.msg("Unit %s using Scene-Based Animations" % name).domain(LogDomains.UNIT).debug()
		
	# Priority 2: STATIC FALLBACK (Data Handling)
	# If no animations are set up, we fall back to the static texture from UnitData.
	elif data.visual_texture and sprite_2d:
		_active_visual = sprite_2d
		sprite_2d.texture = data.visual_texture
		sprite_2d.visible = true
		if animated_sprite: animated_sprite.visible = false
		
	else:
		_active_visual = sprite_2d # Ultimate fallback
		
	# Apply Scaling (Optional: Only if target_pixel_size is set in UnitData)
	if _active_visual and data.target_pixel_size.x > 0:
		var tex_size = Vector2.ONE
		if _active_visual is Sprite2D and _active_visual.texture:
			tex_size = _active_visual.texture.get_size()
		elif _active_visual is AnimatedSprite2D and _active_visual.sprite_frames:
			# Grab size of the first frame of 'idle' or 'default'
			var anim = "idle" if _active_visual.sprite_frames.has_animation("idle") else "default"
			if _active_visual.sprite_frames.has_animation(anim):
				var texture = _active_visual.sprite_frames.get_frame_texture(anim, 0)
				if texture: tex_size = texture.get_size()
			
		if tex_size.x > 0 and tex_size.y > 0:
			_active_visual.scale = data.target_pixel_size / tex_size

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
	
	if data.ai_component_scene:
		attack_ai = data.ai_component_scene.instantiate() as AttackAI
		if attack_ai:
			add_child(attack_ai)
			attack_ai.configure_from_data(data)
			attack_ai.attack_damage = int(attack_ai.attack_damage * damage_mult)
			
			var target_mask = 0
			if self.collision_layer & LAYER_PLAYER_UNIT: 
				target_mask = LAYER_ENEMY_UNIT | LAYER_ENEMY_BLDG
			elif self.collision_layer & LAYER_ENEMY_UNIT: 
				target_mask = LAYER_ENV | LAYER_PLAYER_UNIT
			
			attack_ai.set_target_mask(target_mask)
	
	fsm = UnitFSM.new(self, attack_ai)
	fsm_ready.emit(self)

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
	
	if fsm_velocity.length_squared() > 0.1:
		velocity = velocity.lerp(fsm_velocity, data.acceleration * delta)
		
		# --- FLIP LOGIC ---
		# Flip the active visual based on movement direction
		if _active_visual:
			if fsm_velocity.x < -0.1: 
				_active_visual.flip_h = true
			elif fsm_velocity.x > 0.1: 
				_active_visual.flip_h = false
		# ------------------
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
	# 1. Color Feedback (Kept for debug/status clarity)
	var to_color: Color = STATE_COLORS.get(state, Color.WHITE)
	_tween_color(to_color, 0.2)
	
	# 2. Animation Handling (The Editor Way)
	if _active_visual is AnimatedSprite2D:
		var anim_name = "idle"
		
		match state:
			UnitAIConstants.State.IDLE:
				anim_name = "idle"
			UnitAIConstants.State.MOVING, UnitAIConstants.State.FORMATION_MOVING:
				anim_name = "walk"
			UnitAIConstants.State.ATTACKING:
				anim_name = "attack"
			# Add 'work' case here later if needed
			
		# Safe play: check if animation exists in the SpriteFrames
		if (_active_visual as AnimatedSprite2D).sprite_frames.has_animation(anim_name):
			(_active_visual as AnimatedSprite2D).play(anim_name)
		else:
			# Fallback if "attack" or "walk" is missing
			if (_active_visual as AnimatedSprite2D).sprite_frames.has_animation("idle"):
				(_active_visual as AnimatedSprite2D).play("idle")

func flash_error_color() -> void:
	if not _active_visual: return
	var back_color: Color = STATE_COLORS.get(fsm.current_state, Color.WHITE)
	var t := create_tween()
	t.tween_property(_active_visual, "modulate", ERROR_COLOR, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_active_visual, "modulate", back_color, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tween_color(to_color: Color, duration: float = 0.2) -> void:
	if not _active_visual: return
	if _color_tween and _color_tween.is_running():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(_active_visual, "modulate", to_color, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dying: return
	current_health = max(0, current_health - amount)
	
	if fsm and is_instance_valid(attacker):
		fsm.command_defensive_attack(attacker)
	
	if current_health == 0:
		_is_dying = true
		call_deferred("die")

func die() -> void:
	# Optional: Play death animation before freeing
	# if _active_visual is AnimatedSprite2D and has "die": 
	#    await animation_finished
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
	if fsm: fsm.command_retreat(target_pos)

func command_start_working(target_building: BaseBuilding, target_node: ResourceNode) -> void:
	if fsm and fsm.has_method("command_start_cycle"):
		fsm.command_start_cycle(target_building, target_node)

func add_loot(resource_type: String, amount: int) -> int:
	if not data: return 0
	var cap = data.max_loot_capacity if "max_loot_capacity" in data else 0
	var space_left = cap - current_loot_weight
	if space_left <= 0: return 0
	var actual_amount = min(amount, space_left)
	if not inventory.has(resource_type): inventory[resource_type] = 0
	inventory[resource_type] += actual_amount
	current_loot_weight += actual_amount
	inventory_updated.emit(current_loot_weight, cap)
	return actual_amount

func get_speed_multiplier() -> float:
	if not data: return 1.0
	var cap = data.max_loot_capacity if "max_loot_capacity" in data else 0
	if cap <= 0: return 1.0
	var penalty = data.encumbrance_speed_penalty if "encumbrance_speed_penalty" in data else 0.0
	var ratio = float(current_loot_weight) / float(cap)
	return 1.0 - (ratio * penalty)
