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
var label: Label
var collision_shape: CollisionShape2D
var hitbox_area: Area2D
var health_bar: ProgressBar
var border_rect: ColorRect
var attack_ai: Node = null 

func _ready() -> void:
	if not data: return
	
	current_health = data.max_health
	
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	add_child(collision_shape)
	
	background = ColorRect.new()
	label = Label.new()
	background.add_child(label)
	add_child(background)
	
	input_pickable = true
	_create_hitbox()
	_apply_data_and_scale()
	_create_dev_visuals()
	_setup_defensive_ai()
	
	# Force initial visual state
	_update_visual_state()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.building_right_clicked.emit(self)

func set_state(new_state: BuildingState) -> void:
	print("BaseBuilding: State change requested from %s to %s" % [current_state, new_state])
	var old_state = current_state
	current_state = new_state
	_update_visual_state()
	_update_logic_state()
	
	# Connect to SettlementManager for completion handling
	if current_state == BuildingState.ACTIVE and old_state != BuildingState.ACTIVE:
		construction_completed.emit(self)
		if SettlementManager and SettlementManager.has_method("complete_building_construction"):
			SettlementManager.complete_building_construction(self)

func _update_visual_state() -> void:
	if not background: return

	match current_state:
		BuildingState.BLUEPRINT:
			# Force Blue Tint and 50% Transparency
			self.modulate = Color(0.4, 0.6, 1.0, 0.5)
			background.color.a = 0.5 
			if label: label.text = "%s (Blueprint)" % data.display_name
			if health_bar: health_bar.hide()
			
		BuildingState.UNDER_CONSTRUCTION:
			self.modulate = Color(0.8, 0.8, 0.8, 0.8)
			background.color.a = 0.8
			if label: label.text = "%s (Building...)" % data.display_name
			if health_bar: health_bar.hide()
			
		BuildingState.ACTIVE:
			self.modulate = Color.WHITE
			background.color.a = 1.0
			if label: label.text = data.display_name
			if health_bar: health_bar.show()
			# Restore original color
			_apply_color_coding()

func _update_logic_state() -> void:
	match current_state:
		BuildingState.BLUEPRINT, BuildingState.UNDER_CONSTRUCTION:
			# Disable collision for units to walk through
			if collision_shape: collision_shape.disabled = true
			if hitbox_area: hitbox_area.monitorable = false
			# Disable attack AI completely
			if attack_ai:
				attack_ai.process_mode = Node.PROCESS_MODE_DISABLED
				if attack_ai.has_method("stop_attacking"):
					attack_ai.stop_attacking()
			# Signal that economic payouts should be disabled
			EventBus.building_state_changed.emit(self, current_state)
			
		BuildingState.ACTIVE:
			# Enable collision and interactions
			if collision_shape: collision_shape.disabled = false
			if hitbox_area: hitbox_area.monitorable = true
			if attack_ai: attack_ai.process_mode = Node.PROCESS_MODE_INHERIT
			# Signal that economic payouts should be enabled
			EventBus.building_state_changed.emit(self, current_state)

func add_construction_progress(amount: int) -> void:
	if current_state == BuildingState.ACTIVE: return
	construction_progress += amount
	if construction_progress >= data.construction_effort_required:
		set_state(BuildingState.ACTIVE)

func is_active() -> bool:
	return current_state == BuildingState.ACTIVE

# --- Internal Setup Functions (Unchanged logic, just condensed for file completeness) ---
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
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(size.x, 6)
	health_bar.position = Vector2(-size.x/2, -size.y/2 - 10)
	health_bar.max_value = data.max_health
	health_bar.value = current_health
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
