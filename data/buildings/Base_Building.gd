# res://data/buildings/Base_Building.gd
#
# This script is attached to the Base_Building.tscn scene.
# It procedurally creates its own visual nodes
# and instances its AI component from its 'data' resource.
class_name BaseBuilding
extends StaticBody2D

signal building_destroyed(building: BaseBuilding)

@export var data: BuildingData
var current_health: int = 100

# Node refs (will be created in _ready)
var background: ColorRect
var label: Label
var collision_shape: CollisionShape2D
var hitbox_area: Area2D # --- NEW ---

# Development visual enhancements
var health_bar: ProgressBar
var border_rect: ColorRect

# AI component (optional)
var attack_ai: Node = null # Use generic Node, could be AttackAI or DefensiveAI

func _ready() -> void:
	if not data:
		push_warning("BaseBuilding: Node is missing its 'BuildingData' resource. Cannot initialize.")
		return
	
	# --- DEBUGGING ---
	print("--- BaseBuilding DEBUG ---")
	print("'%s' SPAWNED. Collision Layer: %s, Collision Mask: %s" % [name, collision_layer, collision_mask])
	print("--------------------------")
	
	current_health = data.max_health
	
	# --- Create core nodes ---
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	add_child(collision_shape)
	
	background = ColorRect.new()
	label = Label.new()
	background.add_child(label)
	add_child(background)
	# -------------------------
	
	# --- NEW: Create the Hitbox ---
	_create_hitbox()
	# --- END NEW ---
	
	_apply_data_and_scale()
	_create_dev_visuals()
	_setup_defensive_ai()

	# --- REMOVED ---
	# connect("area_entered", _on_area_entered) # This was incorrect
	# --- END REMOVED ---

# --- NEW FUNCTION ---
func _create_hitbox() -> void:
	"""Creates an Area2D child to act as a detectable hitbox for projectiles."""
	hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	
	# This is the "Player Buildings" layer (Layer 1)
	hitbox_area.collision_layer = 1
	hitbox_area.collision_mask = 0 # Doesn't need to detect anything
	
	hitbox_area.monitoring = false # Doesn't need to detect bodies or areas
	hitbox_area.monitorable = true # CAN BE detected by other areas (projectiles)
	
	# Create a shape for the hitbox
	var hitbox_shape = CollisionShape2D.new()
	hitbox_shape.shape = RectangleShape2D.new()
	hitbox_area.add_child(hitbox_shape)
	
	add_child(hitbox_area)
	print("'%s' created Area2D Hitbox on Layer %s" % [name, hitbox_area.collision_layer])
# --- END NEW FUNCTION ---

# --- REMOVED ---
# func _on_area_entered(area: Area2D) -> void: ...
# --- END REMOVED ---

func _apply_data_and_scale() -> void:
	if not SettlementManager:
		push_error("BaseBuilding: SettlementManager not ready. Cannot scale '%s'." % data.display_name)
		return
	
	var cell_size: Vector2 = SettlementManager.get_active_grid_cell_size()
	if cell_size.x <= 0 or cell_size.y <= 0:
		push_error("BaseBuilding: SettlementManager returned invalid cell_size (%s). Cannot scale '%s'." % [cell_size, data.display_name])
		return
		
	var target_size: Vector2 = Vector2(data.grid_size) * cell_size
	
	if target_size.x <= 0 or target_size.y <= 0:
		push_warning("BaseBuilding: '%s' has a grid_size of %s, resulting in an invalid target_size." % [data.display_name, data.grid_size])
		return

	background.custom_minimum_size = target_size
	background.position = -target_size / 2.0
	
	_apply_visual_styling(target_size)

	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = target_size
	
	# --- NEW: Scale the hitbox shape ---
	if hitbox_area:
		var hitbox_shape = hitbox_area.get_child(0) as CollisionShape2D
		if hitbox_shape and hitbox_shape.shape is RectangleShape2D:
			hitbox_shape.shape.size = target_size
	# --- END NEW ---

func take_damage(amount: int) -> void:
	# --- DEBUGGING ---
	print("'%s' TOOK %d DAMAGE. Health: %d/%d" % [name, amount, current_health - amount, data.max_health])
	# --- END DEBUGGING ---
	
	current_health = max(0, current_health - amount)
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been destroyed." % data.display_name)
	
	_show_destruction_effect()
	
	building_destroyed.emit(self)
	
	remove_from_group("enemy_buildings")
	
	print("Building %s queued for removal from scene" % data.display_name)
	queue_free()

func _show_destruction_effect() -> void:
	var tween = create_tween()
	
	tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.parallel().tween_property(self, "rotation", randf() * TAU, 0.3)

func _apply_visual_styling(target_size: Vector2) -> void:
	label.text = data.display_name
	label.custom_minimum_size = target_size
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if target_size.x < 64:
		label.add_theme_font_size_override("font_size", 10)
	elif target_size.x < 128:
		label.add_theme_font_size_override("font_size", 12)
	else:
		label.add_theme_font_size_override("font_size", 14)
	
	_apply_color_coding()

func _apply_color_coding() -> void:
	var base_color: Color
	
	if data.dev_color != Color.TRANSPARENT and data.dev_color != Color.GRAY:
		base_color = data.dev_color
	else:
		if data.is_defensive_structure:
			base_color = Color.CRIMSON * 0.8
		elif data.is_player_buildable:
			base_color = Color.ROYAL_BLUE * 0.8
		else:
			base_color = Color.GRAY * 0.8
	
	background.color = base_color

func _create_dev_visuals() -> void:
	if not data:
		return
		
	var target_size: Vector2 = Vector2(data.grid_size) * SettlementManager.get_active_grid_cell_size()
	
	if data.is_defensive_structure:
		_create_border(target_size)
	
	_create_health_bar(target_size)

func _create_border(target_size: Vector2) -> void:
	border_rect = ColorRect.new()
	border_rect.color = Color.DARK_RED
	border_rect.custom_minimum_size = target_size + Vector2(4, 4)
	border_rect.position = -border_rect.custom_minimum_size / 2.0
	add_child(border_rect)
	move_child(border_rect, 0)

func _create_health_bar(target_size: Vector2) -> void:
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(target_size.x, 6)
	health_bar.position = Vector2(-target_size.x/2, -target_size.y/2 - 10)
	health_bar.max_value = data.max_health
	health_bar.value = current_health
	
	health_bar.modulate = Color.WHITE
	add_child(health_bar)

# === DEFENSIVE AI SETUP ===

func _setup_defensive_ai() -> void:
	"""Initialize AI systems for defensive buildings"""
	if not data or not data.is_defensive_structure:
		return
	
	# --- MODIFIED: Load AI from data, not hard-coded ---
	if not data.ai_component_scene:
		print("BaseBuilding: '%s' is defensive but has no ai_component_scene assigned." % data.display_name)
		return
		
	attack_ai = data.ai_component_scene.instantiate()
	if not attack_ai:
		push_error("BaseBuilding: Failed to instantiate ai_component_scene for %s" % data.display_name)
		return
	# --- END MODIFICATION ---
	
	add_child(attack_ai)
	
	# Configure AI from building data
	# We must check for methods/properties since attack_ai is a generic Node
	if attack_ai.has_method("configure_from_data"):
		attack_ai.configure_from_data(data)
	
	# --- DEBUGGING ---
	# For defensive buildings, the target mask is set in Base_Building.gd
	var player_collision_mask: int = 1 << 1  # Layer 2 (bit position 1)
	print("'%s' (Defensive) AI: Setting target mask to %s (Player Units)" % [name, player_collision_mask])
	# --- END DEBUGGING ---
	
	if attack_ai.has_method("set_target_mask"):
		attack_ai.set_target_mask(player_collision_mask)
	
	# Connect AI signals for feedback (optional)
	if attack_ai.has_signal("attack_started"):
		attack_ai.attack_started.connect(_on_ai_attack_started)
	if attack_ai.has_signal("attack_stopped"):
		attack_ai.attack_stopped.connect(_on_ai_attack_stopped)

func _on_ai_attack_started(_target: Node2D) -> void:
	pass

func _on_ai_attack_stopped() -> void:
	pass
