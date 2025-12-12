# res://data/buildings/Base_Building.gd
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

@export var data: BuildingData
var current_health: int = 100
var current_state: BuildingState = BuildingState.ACTIVE 
var construction_progress: int = 0

# --- NEW: HUD Component Reference ---
var hud: BuildingInfoHUD
const HUD_SCENE = preload("res://ui/components/BuildingInfoHUD.tscn")
# ------------------------------------

# Node refs (Physical)
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var hitbox_area: Area2D
var attack_ai: Node = null 
var border_rect: ColorRect # Kept for debug borders

# --- NEW: Loot State ---
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
	
	# 2. Setup Sprite
	if data.building_texture and not sprite:
		sprite = Sprite2D.new()
		sprite.texture = data.building_texture
		add_child(sprite)
	
	# 3. Setup HUD (Visuals)
	if not hud:
		hud = HUD_SCENE.instantiate()
		add_child(hud)
	
	_apply_data_and_scale()
	
	# Stop here if Editor
	if Engine.is_editor_hint(): return
		
	# Gameplay Setup
	input_pickable = true
	_create_hitbox()
	_setup_defensive_ai()
	if not Engine.is_editor_hint():
		_initialize_loot()
		
	_update_visual_state()

func _initialize_loot() -> void:
	if not data is EconomicBuildingData: 
		# Non-economic buildings have small generic loot
		available_loot = {"gold": 25} 
		total_loot_value = 25
		return
		
	var eco = data as EconomicBuildingData
	var type = eco.resource_type
	# 3x the passive output is the "Storehouse" amount (Logic from RaidMapGenerator)
	var amount = eco.base_passive_output * 3
	
	available_loot = {type: amount}
	total_loot_value = amount
	
	# Log for debugging
	Loggie.msg("Building %s initialized with loot: %s" % [name, available_loot]).domain("RAID").debug()

# --- NEW: The Pillage Mechanic ---
func steal_resources(max_amount: int) -> int:
	if total_loot_value <= 0:
		return 0
		
	# Find a resource that still has amount left
	var target_res = ""
	for key in available_loot:
		if available_loot[key] > 0:
			target_res = key
			break
			
	if target_res == "":
		return 0
		
	var available = available_loot[target_res]
	var actual_steal = min(available, max_amount)
	
	available_loot[target_res] -= actual_steal
	total_loot_value -= actual_steal
	
	# Notify System (RaidManager will listen to this)
	loot_stolen.emit(target_res, actual_steal)
	
	if total_loot_value <= 0:
		loot_depleted.emit(self)
		modulate = Color(0.5, 0.5, 0.5) # Visually darken to show "Empty"
		
	return actual_steal

func _apply_data_and_scale() -> void:
	var cell_size = Vector2(32, 32)
	if not Engine.is_editor_hint() and SettlementManager:
		cell_size = SettlementManager.get_active_grid_cell_size()
	
	var size = Vector2(data.grid_size) * cell_size
	
	# Update Collision
	if collision_shape and collision_shape.shape: 
		collision_shape.shape.size = size
	
	# Update Sprite
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		sprite.scale = size / texture_size
		# Ensure sprite is behind HUD
		sprite.z_index = 0
		hud.z_index = 1
	
	# Update HUD
	if hud:
		hud.setup(data.display_name, size)
		hud.position = -size / 2.0 # Center it

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
			if sprite: sprite.modulate = Color(0.4, 0.6, 1.0, 0.5)
			
		BuildingState.UNDER_CONSTRUCTION:
			hud.update_construction(construction_progress, data.construction_effort_required)
			if sprite: sprite.modulate = Color(0.8, 0.8, 0.8, 1.0)
			
		BuildingState.ACTIVE:
			hud.set_active_mode(data.display_name)
			hud.update_health(current_health, data.max_health)
			if sprite: sprite.modulate = Color.WHITE

func _update_logic_state() -> void:
	# (Same logic as before, just cleaner file)
	match current_state:
		BuildingState.BLUEPRINT, BuildingState.UNDER_CONSTRUCTION:
			if collision_shape: collision_shape.disabled = true
			# Hitbox: ENABLED (Mouse can click it)
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
	Loggie.msg("Building %s progress: %d" % [name, construction_progress]).domain("BUILDING").info()
	
	# Update HUD
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
	queue_free()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.building_right_clicked.emit(self)

func _create_hitbox() -> void:
	hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	if self.collision_layer & 1: hitbox_area.collision_layer = 1
	else: hitbox_area.collision_layer = 8 # Enemy building layer default
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
	if attack_ai.has_method("set_target_mask"): attack_ai.set_target_mask(1 << 1) # Default Target Player
