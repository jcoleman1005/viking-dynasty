#res://data/buildings/Base_Building.gd
@tool
class_name BaseBuilding
extends StaticBody2D

signal building_destroyed(building: BaseBuilding)
signal construction_completed(building: BaseBuilding)
signal loot_stolen(type: String, amount: int)
signal loot_depleted(building: BaseBuilding)

# Defaults to a specific "Invalid" vector so we know if it wasn't set.
var grid_coordinate: Vector2i = Vector2i(-999, -999)

enum BuildingState { 
	BLUEPRINT, 
	UNDER_CONSTRUCTION, 
	ACTIVE 
}

@export var data: BuildingData:
	set(value):
		data = value
		if Engine.is_editor_hint():
			_apply_data_and_scale()
			queue_redraw()

var current_health: int = 100
var current_state: BuildingState = BuildingState.ACTIVE 
var construction_progress: int = 0

# --- Visual Components ---
var sprite: Sprite2D
var iso_placeholder: Node2D # Reference to the procedural shape
var hud: BuildingInfoHUD
const HUD_SCENE = preload("res://ui/components/BuildingInfoHUD.tscn")

# --- Physics Components ---
var collision_shape: CollisionShape2D
var hitbox_area: Area2D
var attack_ai: Node = null 

# --- Loot State ---
var available_loot: Dictionary = {}
var total_loot_value: int = 0

func _ready() -> void:
	if not data: return
	current_health = data.max_health
	
	# 1. Setup Physics/Collision
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.shape = RectangleShape2D.new()
		add_child(collision_shape)
	
	# 2. Setup Visuals (Sprite OR IsoPlaceholder)
	_setup_visual_style()
	
	# 3. Setup HUD (Visuals)
	if not hud:
		if HUD_SCENE:
			hud = HUD_SCENE.instantiate()
			add_child(hud)
	
	_apply_data_and_scale()
	
	# Stop here if Editor
	if Engine.is_editor_hint(): return
		
	# Gameplay Setup
	input_pickable = true
	_create_hitbox()
	_setup_defensive_ai()
	_initialize_loot()
		
	_update_visual_state()

func _setup_visual_style() -> void:
	# Clear existing to be safe
	if sprite: 
		sprite.queue_free()
		sprite = null
	if iso_placeholder: 
		iso_placeholder.queue_free()
		iso_placeholder = null

	# Decision: Texture vs Placeholder
	if data.building_texture != null:
		# Use Sprite
		sprite = Sprite2D.new()
		sprite.texture = data.building_texture
		# Y-Sort Offset: Center bottom of sprite should be at node origin
		sprite.centered = true 
		sprite.offset.y = -data.building_texture.get_height() / 2.0
		add_child(sprite)
	else:
		# Use Procedural Iso Placeholder
		# We attach a Node2D and add the script we wrote previously
		iso_placeholder = Node2D.new()
		iso_placeholder.name = "IsoPlaceholder"
		
		# Attach the script dynamically if not a scene
		var script = load("res://scripts/utility/IsoPlaceholder.gd")
		if script:
			iso_placeholder.set_script(script)
			iso_placeholder.set("data", data) # Pass data to it
			
		add_child(iso_placeholder)

func _initialize_loot() -> void:
	if not data is EconomicBuildingData: 
		available_loot = {"gold": 25} 
		total_loot_value = 25
		return
		
	var eco = data as EconomicBuildingData
	var type = eco.resource_type
	var amount = eco.base_passive_output * 3
	
	available_loot = {type: amount}
	total_loot_value = amount

func steal_resources(max_amount: int) -> int:
	if total_loot_value <= 0: return 0
		
	var target_res = ""
	for key in available_loot:
		if available_loot[key] > 0:
			target_res = key
			break
			
	if target_res == "": return 0
		
	var available = available_loot[target_res]
	var actual_steal = min(available, max_amount)
	
	available_loot[target_res] -= actual_steal
	total_loot_value -= actual_steal
	
	loot_stolen.emit(target_res, actual_steal)
	
	if total_loot_value <= 0:
		loot_depleted.emit(self)
		modulate = Color(0.5, 0.5, 0.5)
		
	return actual_steal

func _apply_data_and_scale() -> void:
	if not data: return
	
	# Determine logical size in pixels based on Grid
	# (Note: IsoPlaceholder handles its own drawing size, we just pass Data)
	if iso_placeholder:
		iso_placeholder.set("data", data)
		
	# Update Collision (Approximate box for clicking)
	# For Isometric, a box at (0,0) is "okay" for clicking, 
	# but technically it covers empty corners. 
	# For now, we size it to the total width/height of the diamond.
	if collision_shape and collision_shape.shape: 
		var cell_size = Vector2(64, 32) # Default
		if SettlementManager: cell_size = SettlementManager.get_active_grid_cell_size()
		
		# A 2x2 grid is 2 cells wide and 2 cells tall in Iso view
		# Total Width = (Rows + Cols) * HalfWidth
		# Total Height = (Rows + Cols) * HalfHeight
		var total_w = (data.grid_size.x + data.grid_size.y) * (cell_size.x * 0.5)
		var total_h = (data.grid_size.x + data.grid_size.y) * (cell_size.y * 0.5)
		
		collision_shape.shape.size = Vector2(total_w, total_h)
	
	# Update HUD Position
	if hud:
		hud.setup(data.display_name, Vector2(64, 64)) # Generic size
		# Raise HUD above the building visual
		hud.position = Vector2(0, -64) 

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
	if not hud: return

	match current_state:
		BuildingState.BLUEPRINT:
			hud.set_blueprint_mode()
			modulate = Color(0.4, 0.6, 1.0, 0.8)
			
		BuildingState.UNDER_CONSTRUCTION:
			hud.update_construction(construction_progress, data.construction_effort_required)
			modulate = Color(0.8, 0.8, 0.8, 1.0)
			
		BuildingState.ACTIVE:
			hud.set_active_mode(data.display_name)
			hud.update_health(current_health, data.max_health)
			modulate = Color.WHITE

func _update_logic_state() -> void:
	match current_state:
		BuildingState.BLUEPRINT, BuildingState.UNDER_CONSTRUCTION:
			if collision_shape: collision_shape.disabled = true
			if hitbox_area: 
				hitbox_area.monitorable = true
				hitbox_area.monitoring = true
			if attack_ai and attack_ai.has_method("stop_attacking"):
				attack_ai.stop_attacking()
				attack_ai.process_mode = Node.PROCESS_MODE_DISABLED
			
		BuildingState.ACTIVE:
			if collision_shape: collision_shape.disabled = false
			if hitbox_area: hitbox_area.monitorable = true
			if attack_ai: attack_ai.process_mode = Node.PROCESS_MODE_INHERIT

func add_construction_progress(amount: int) -> void:
	if current_state == BuildingState.ACTIVE: return
	
	if current_state == BuildingState.BLUEPRINT:
		set_state(BuildingState.UNDER_CONSTRUCTION)
		
	construction_progress += amount
	
	if hud:
		hud.update_construction(construction_progress, data.construction_effort_required)

func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if current_state != BuildingState.ACTIVE: return
	current_health = max(0, current_health - amount)
	
	if hud:
		hud.update_health(current_health, data.max_health)
	
	if current_health == 0: die()

func die() -> void:
	building_destroyed.emit(self)
	EventBus.building_destroyed.emit(self)
	queue_free()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.building_right_clicked.emit(self)

func _create_hitbox() -> void:
	hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	if self.collision_layer & 1: hitbox_area.collision_layer = 1
	else: hitbox_area.collision_layer = 8 
	hitbox_area.collision_mask = 0
	hitbox_area.monitorable = true
	var s = CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	if collision_shape and collision_shape.shape:
		s.shape.size = collision_shape.shape.size
	hitbox_area.add_child(s)
	add_child(hitbox_area)

func _setup_defensive_ai() -> void:
	if not data or not data.is_defensive_structure or not data.ai_component_scene: return
	attack_ai = data.ai_component_scene.instantiate()
	add_child(attack_ai)
	if attack_ai.has_method("configure_from_data"): attack_ai.configure_from_data(data)
	if attack_ai.has_method("set_target_mask"): attack_ai.set_target_mask(1 << 1)
