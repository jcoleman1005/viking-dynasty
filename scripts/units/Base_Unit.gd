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
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var separation_area: Area2D = $SeparationArea

@export_group("AI")
@export var separation_enabled: bool = true
@export var separation_force: float = 30.0
@export var separation_radius: float = 40.0
# --- NEW: Obstacle Avoidance ---
@export var avoidance_enabled: bool = true
@export var avoidance_force: float = 150.0 
@export var whisker_length: float = 40.0

# --- NEW: Hierarchy System ---
# Higher number = "I push you, you don't push me"
@export var avoidance_priority: int = 1
# -------------------------------

#Debug Toggle
@export var debug_avoidance_logs: bool = true
var _debug_log_timer: float = 0.0

# --- NEW: Control Protocol ---
# If true, child classes (SquadSoldier) control velocity directly.
# BaseUnit will skip FSM updates but still apply Separation/Avoidance.
var uses_external_steering: bool = false
var _last_avoid_dir: Vector2 = Vector2.ZERO
# -----------------------------

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
var inventory: Dictionary = {} 
var current_loot_weight: int = 0

func _ready() -> void:
	if not data:
		push_warning("BaseUnit: Node '%s' is missing 'UnitData'." % name)
		return
	
	var hp_mult = 1.0
	var dmg_mult = 1.0
	
	if is_in_group("player_units"):
	# Add the percentage (e.g., 0.10) to the base multiplier (1.0)
		dmg_mult += DynastyManager.active_year_modifiers.get("mod_unit_damage", 0.0)
	
	if warband_ref:
		var level_mult = warband_ref.get_stat_multiplier()
		hp_mult *= level_mult
		dmg_mult *= level_mult
		
		hp_mult *= warband_ref.get_gear_health_mult()
		dmg_mult *= warband_ref.get_gear_damage_mult()
		
		if warband_ref.assigned_heir_name != "":
			var heir = DynastyManager.find_heir_by_name(warband_ref.assigned_heir_name)
			if heir:
				if heir.prowess > 5:
					var p_bonus = 1.0 + ((heir.prowess - 5) * 0.10)
					dmg_mult *= p_bonus
				modulate = Color(1.2, 1.2, 0.8) 
				
		if unit_identity == "":
			unit_identity = DynastyGenerator.get_random_viking_name()
			
	current_health = int(data.max_health * hp_mult)
	
	_apply_texture_and_scale()
	_setup_collision_logic()
	call_deferred("_deferred_setup", dmg_mult)
	
	sprite.modulate = STATE_COLORS.get(UnitAIConstants.State.IDLE, Color.WHITE)
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		area_shape.shape.radius = separation_radius

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
	else:
		if not is_in_group("civilians"):
			push_error("Config Error: Unit '%s' missing AI." % name)

	fsm = UnitFSM.new(self, attack_ai)
	fsm_ready.emit(self)
	
func _apply_texture_and_scale() -> void:
	if data.target_pixel_size.x <= 0 or data.target_pixel_size.y <= 0: return
	var target_size: Vector2 = data.target_pixel_size

	if data.visual_texture: sprite.texture = data.visual_texture
	
	if sprite.texture:
		var texture_size: Vector2 = sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			sprite.scale = target_size / texture_size
	
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

	var desired_velocity = Vector2.ZERO
	
	# 1. Determine Input Velocity
	if uses_external_steering:
		# Trust that the child class (SquadSoldier) set 'velocity' correctly
		desired_velocity = velocity
	else:
		# Standard FSM Control
		if fsm:
			fsm.update(delta)
			desired_velocity = velocity 
	
	# 2. Context Steering: Add Forces (Shared by ALL units)
	var final_velocity = desired_velocity
	
	if separation_enabled:
		# Calculate separation (prevents stacking)
		final_velocity += calculate_separation_push(delta)
	
	if avoidance_enabled and final_velocity.length_squared() > 10.0:
		# Calculate whiskers (prevents corner stuck)
		final_velocity += _calculate_obstacle_avoidance()
	
	# 3. Inertia & Movement
	if final_velocity.length_squared() > 1.0:
		velocity = velocity.lerp(final_velocity, data.acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, data.linear_damping * delta)
	
	move_and_slide()
	
	# 4. Anti-Stuck Logic
	if not uses_external_steering and fsm and fsm.current_state == UnitAIConstants.State.MOVING:
		_check_stuck_timer(delta)
			
	_last_pos = global_position

func calculate_separation_push(delta: float) -> Vector2:
	var push_vector = Vector2.ZERO
	if not separation_area: return Vector2.ZERO
	
	var neighbors = separation_area.get_overlapping_bodies()
	if neighbors.is_empty(): return Vector2.ZERO
		
	for neighbor in neighbors:
		if neighbor == self: continue
		
		# Only push against units (CharacterBody2D)
		if neighbor is CharacterBody2D:
			var away_vector = global_position - neighbor.global_position
			var distance_sq = away_vector.length_squared()
			if distance_sq < 1.0: distance_sq = 1.0
			
			if distance_sq < separation_radius * separation_radius:
				var current_push_strength = 1.0 - (sqrt(distance_sq) / separation_radius)
				
				# --- ANCESTOR'S LEGACY FIX: Rank Check ---
				if neighbor is BaseUnit:
					# Case A: They are lower rank (Leader vs Soldier)
					# Result: I ignore them (or barely feel them). They will move instead.
					if neighbor.avoidance_priority < self.avoidance_priority:
						current_push_strength *= 0.1 # 90% resistance to being pushed by minions
					
					# Case B: They are higher rank (Soldier vs Leader)
					# Result: I get out of the way FAST.
					elif neighbor.avoidance_priority > self.avoidance_priority:
						current_push_strength *= 2.0 # Double panic to clear the path
				# -----------------------------------------
				
				push_vector += away_vector.normalized() * current_push_strength
	
	return push_vector * separation_force * 2.0

# --- NEW: Whisker Logic ---
func _calculate_obstacle_avoidance() -> Vector2:
	if velocity.length_squared() < 1.0: return Vector2.ZERO
	
	var space_state = get_world_2d().direct_space_state
	var speed_ratio = velocity.length() / max(data.move_speed, 1.0)
	var current_whisker_len = whisker_length * clamp(speed_ratio, 0.2, 1.2)
	
	var angles = [0.0, deg_to_rad(-35), deg_to_rad(35)]
	var hit_count = 0
	var total_escape_dir = Vector2.ZERO
	
	# Debug Data
	var log_hits = []
	
	for angle in angles:
		var dir = velocity.normalized().rotated(angle)
		var query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + (dir * current_whisker_len),
			LAYER_ENV
		)
		var result = space_state.intersect_ray(query)
		
		if result:
			hit_count += 1
			var hit_normal = result.normal
			
			# 1. Calculate Tangents
			var tangent_left = Vector2(-hit_normal.y, hit_normal.x)
			var tangent_right = Vector2(hit_normal.y, -hit_normal.x)
			
			# 2. Score Tangents
			var dot_left = tangent_left.dot(velocity)
			var dot_right = tangent_right.dot(velocity)
			var best_tangent = tangent_left
			
			if dot_right > dot_left:
				best_tangent = tangent_right
			
			# 3. Apply Force with "Anti-Brake" Logic
			var normal_influence = 0.05 # Default: Only 5% pushback, 95% slide
			
			# FIX: If Head-On (Center Ray), use 100% Slide (No Brake)
			if abs(angle) < 0.01: 
				normal_influence = 0.0
			
			var escape_dir = (best_tangent * (1.0 - normal_influence)) + (hit_normal * normal_influence)
			total_escape_dir += escape_dir.normalized()
			
			if debug_avoidance_logs:
				log_hits.append({"angle": rad_to_deg(angle), "normal": hit_normal, "escape": escape_dir})

	var final_steer = Vector2.ZERO
	if hit_count > 0:
		# FIX: Average the direction, don't sum the magnitude!
		# This ensures force remains constant (150) regardless of 1, 2, or 3 hits.
		var avg_dir = total_escape_dir / hit_count
		final_steer = avg_dir.normalized() * avoidance_force

	# --- DEBUG LOGGER ---
	if debug_avoidance_logs and hit_count > 0:
		_debug_log_timer += get_process_delta_time()
		if _debug_log_timer > 0.5:
			_debug_log_timer = 0.0
			print("\n[AVOIDANCE DEBUG] Unit: %s" % name)
			print(" -> Velocity: %s" % velocity)
			print(" -> Hits: %d | Final Steer: %s" % [hit_count, final_steer])
			print("------------------------------------------------")
			
	return final_steer

func _check_stuck_timer(delta: float) -> void:
	var distance_moved = global_position.distance_squared_to(_last_pos)
	if distance_moved < 1.0:
		_stuck_timer += delta
		if _stuck_timer > 1.5:
			_handle_stuck_unit()
	else:
		_stuck_timer = 0.0

func _handle_stuck_unit() -> void:
	if fsm:
		var random_nudge = Vector2(randf_range(-1,1), randf_range(-1,1)) * 10.0
		global_position += random_nudge
		fsm._recalculate_path()
		_stuck_timer = 0.0

func on_state_changed(state: UnitAIConstants.State) -> void:
	var to_color: Color = STATE_COLORS.get(state, Color.WHITE)
	_tween_color(to_color, 0.2)

func flash_error_color() -> void:
	var back_color: Color = STATE_COLORS.get(fsm.current_state, Color.WHITE)
	var t := create_tween()
	t.tween_property(sprite, "modulate", ERROR_COLOR, 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(sprite, "modulate", back_color, 0.18).set_trans(Tween.TRANS_SINE)

func _tween_color(to_color: Color, duration: float = 0.2) -> void:
	if _color_tween and _color_tween.is_running(): _color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(sprite, "modulate", to_color, duration).set_trans(Tween.TRANS_SINE)

func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dying: return
	current_health = max(0, current_health - amount)
	if fsm and is_instance_valid(attacker):
		fsm.command_defensive_attack(attacker)
	if current_health == 0:
		_is_dying = true
		call_deferred("die")

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
		draw_circle(Vector2.ZERO, 25.0, Color(1, 1, 0, 0.8), false, 3.0)

func _create_unit_hitbox() -> void:
	var hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	
	var layer_value = LAYER_PLAYER_UNIT
	if self.collision_layer & LAYER_ENEMY_UNIT: layer_value = LAYER_ENEMY_UNIT
	
	hitbox_area.collision_layer = layer_value
	hitbox_area.monitorable = true 
	hitbox_area.monitoring = false
	
	var hitbox_shape = CollisionShape2D.new()
	if collision_shape and collision_shape.shape:
		hitbox_shape.shape = collision_shape.shape.duplicate()
	else:
		hitbox_shape.shape = CircleShape2D.new()
		hitbox_shape.shape.radius = 15.0
	
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
