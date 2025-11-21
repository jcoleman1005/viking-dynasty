class_name BaseBuilding
extends StaticBody2D

signal building_destroyed(building: BaseBuilding)
signal construction_completed(building: BaseBuilding)

enum BuildingState { 
	BLUEPRINT, 
	UNDER_CONSTRUCTION, 
	ACTIVE 
}

@export var data: BuildingData
var current_health: int = 100
var current_state: BuildingState = BuildingState.ACTIVE 
var construction_progress: int = 0

# Node refs
var background: ColorRect
var sprite: Sprite2D
var label: Label
var collision_shape: CollisionShape2D
var hitbox_area: Area2D
var health_bar: ProgressBar
var border_rect: ColorRect
var attack_ai: Node = null 

# StyleBox references for dynamic coloring
var style_fill: StyleBoxFlat
var style_bg: StyleBoxFlat

func _ready() -> void:
	if not data: return
	
	current_health = data.max_health
	
	# --- Create core nodes ---
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	add_child(collision_shape)
	
	background = ColorRect.new()
	label = Label.new()
	background.add_child(label)
	add_child(background)
	
	# Create sprite for building texture
	if data.building_texture:
		sprite = Sprite2D.new()
		sprite.texture = data.building_texture
		add_child(sprite)
		# Position sprite behind other elements but above background
		move_child(sprite, 1)
	# -------------------------
	
	input_pickable = true
	_create_hitbox()
	_apply_data_and_scale()
	_create_dev_visuals() 
	_setup_defensive_ai()
	
	# Apply the initial state visual
	_update_visual_state()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.building_right_clicked.emit(self)

func set_state(new_state: BuildingState) -> void:
	var old_state = current_state
	current_state = new_state
	_update_visual_state()
	_update_logic_state()
	
	if current_state == BuildingState.ACTIVE and old_state != BuildingState.ACTIVE:
		construction_completed.emit(self)
		if SettlementManager and SettlementManager.has_method("complete_building_construction"):
			SettlementManager.complete_building_construction(self)

func _update_visual_state() -> void:
	if not background: return

	match current_state:
		BuildingState.BLUEPRINT:
			# Ghostly Blue
			self.modulate = Color(0.4, 0.6, 1.0, 0.5)
			background.color = Color.WHITE
			background.color.a = 0.5 
			if label: label.text = "%s\n(Blueprint)" % data.display_name
			if health_bar: health_bar.hide()
			
		BuildingState.UNDER_CONSTRUCTION:
			# Dark Foundation, Opaque
			self.modulate = Color.WHITE 
			background.color = Color(0.2, 0.2, 0.2, 0.9) 
			
			# --- CONSTRUCTION BAR CONFIG ---
			if health_bar: 
				health_bar.show()
				# Set correct range
				var max_effort = max(1, data.construction_effort_required)
				health_bar.max_value = max_effort
				health_bar.value = construction_progress
				
				# Set Colors Directly on StyleBox (Blue)
				if style_fill: style_fill.bg_color = Color(0.2, 0.6, 1.0) # Bright Blue
				
				# Reset modulation (don't tint the black background)
				health_bar.modulate = Color.WHITE 
			
			_update_percentage_label()
			
		BuildingState.ACTIVE:
			# Standard Colors
			self.modulate = Color.WHITE
			_apply_color_coding() 
			# Only override alpha if we don't have a sprite (color_coding handles sprite case)
			if not (sprite and sprite.texture):
				background.color.a = 1.0
			if label: label.text = data.display_name
			
			# --- HEALTH BAR CONFIG ---
			if health_bar:
				health_bar.max_value = data.max_health
				health_bar.value = current_health
				
				# Set Colors Directly on StyleBox (Green)
				if style_fill: style_fill.bg_color = Color(0.2, 0.8, 0.2) # Green
				
				health_bar.modulate = Color.WHITE
				health_bar.show()

func _update_logic_state() -> void:
	match current_state:
		BuildingState.BLUEPRINT, BuildingState.UNDER_CONSTRUCTION:
			if collision_shape: collision_shape.disabled = true
			if hitbox_area: hitbox_area.monitorable = false
			if attack_ai:
				attack_ai.process_mode = Node.PROCESS_MODE_DISABLED
				if attack_ai.has_method("stop_attacking"):
					attack_ai.stop_attacking()
			EventBus.building_state_changed.emit(self, current_state)
			
		BuildingState.ACTIVE:
			if collision_shape: collision_shape.disabled = false
			if hitbox_area: hitbox_area.monitorable = true
			if attack_ai: attack_ai.process_mode = Node.PROCESS_MODE_INHERIT
			EventBus.building_state_changed.emit(self, current_state)

func add_construction_progress(amount: int) -> void:
	if current_state == BuildingState.ACTIVE: return
	
	# Auto-transition state on first progress
	if current_state == BuildingState.BLUEPRINT:
		set_state(BuildingState.UNDER_CONSTRUCTION)
		
	construction_progress += amount
	Loggie.msg("Building %s progress: %d / %d" % [name, construction_progress, data.construction_effort_required]).domain("BUILDING").info()
	
	# Update the bar immediately
	if health_bar:
		health_bar.value = construction_progress
		
	_update_percentage_label()
	
	# Auto-complete
	if construction_progress >= data.construction_effort_required:
		# Handled by Manager, but ensures local state is correct
		pass 

func _update_percentage_label() -> void:
	if label and data.construction_effort_required > 0:
		var percent = int((float(construction_progress) / data.construction_effort_required) * 100)
		label.text = "%s\n(%d%%)" % [data.display_name, percent]

func _create_hitbox() -> void:
	hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	if self.collision_layer & 1: hitbox_area.collision_layer = 1
	elif self.collision_layer & 8: hitbox_area.collision_layer = 8
	else: hitbox_area.collision_layer = 1
	hitbox_area.collision_mask = 0
	hitbox_area.monitorable = true
	var s = CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	hitbox_area.add_child(s)
	add_child(hitbox_area)

func _apply_data_and_scale() -> void:
	if not SettlementManager: return
	var cell = SettlementManager.get_active_grid_cell_size()
	var size = Vector2(data.grid_size) * cell
	background.custom_minimum_size = size
	background.position = -size / 2.0
	
	# Scale sprite to match building size
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		sprite.scale = size / texture_size
		sprite.position = Vector2.ZERO  # Center the sprite
	
	label.text = data.display_name
	label.custom_minimum_size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	_apply_color_coding()
	
	if collision_shape: collision_shape.shape.size = size
	if hitbox_area: hitbox_area.get_child(0).shape.size = size

func _apply_color_coding() -> void:
	var c = Color.GRAY
	if data.dev_color != Color.TRANSPARENT and data.dev_color != Color.GRAY: c = data.dev_color
	elif data.is_defensive_structure: c = Color.CRIMSON * 0.8
	elif data.is_player_buildable: c = Color.ROYAL_BLUE * 0.8
	
	# If we have a building texture, make background more transparent to show the sprite
	if sprite and sprite.texture:
		c.a = 0.2  # Make background mostly transparent
	
	background.color = c

func _create_dev_visuals() -> void:
	var cell = SettlementManager.get_active_grid_cell_size()
	var size = Vector2(data.grid_size) * cell
	if data.is_defensive_structure:
		border_rect = ColorRect.new()
		border_rect.color = Color.DARK_RED
		border_rect.custom_minimum_size = size + Vector2(4,4)
		border_rect.position = -border_rect.custom_minimum_size/2.0
		add_child(border_rect)
		move_child(border_rect, 0)
	
	# --- UPDATED BAR CREATION ---
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(size.x * 0.9, 10) # 90% width, 10px height
	health_bar.position = Vector2(-size.x * 0.45, -size.y/2 - 15) # Centered above
	health_bar.max_value = data.max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	
	# Create StyleBox Resources
	style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0, 0, 0, 1) # Black Background
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(1, 1, 1, 1) # White (Default, changed in update)
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	add_child(health_bar)

func _setup_defensive_ai() -> void:
	if not data or not data.is_defensive_structure or not data.ai_component_scene: return
	attack_ai = data.ai_component_scene.instantiate()
	add_child(attack_ai)
	if attack_ai.has_method("configure_from_data"): attack_ai.configure_from_data(data)
	if attack_ai.has_method("set_target_mask"): attack_ai.set_target_mask(1 << 1)

func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if current_state != BuildingState.ACTIVE: return
	current_health = max(0, current_health - amount)
	
	if health_bar: health_bar.value = current_health
	
	if current_health == 0: die()

func die() -> void:
	building_destroyed.emit(self)
	queue_free()
