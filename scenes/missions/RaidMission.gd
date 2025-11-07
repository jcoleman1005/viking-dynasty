# res://scenes/missions/RaidMission.gd
# Raid Mission Controller for Phase 3
# GDD Ref: Phase 3 Task 7
#
# --- REFACTORED ---
# This script is now decoupled from input.
# It gets a reference to the RTSController node
# and simply hands units to it.
extends Node2D

# --- Exported Mission Configuration ---
@export var enemy_base_data: SettlementData
@export var default_enemy_base_path: String = "res://data/settlements/monastery_base.tres"
@export_group("Enemy Base Presets")
@export var available_enemy_bases: Array[String] = [
	"res://data/settlements/monastery_base.tres",
	"res://data/settlements/fortress_base.tres"
]
@export var victory_bonus_loot: Dictionary = {"gold": 200}
@export var player_spawn_formation: Dictionary = {"units_per_row": 5, "spacing": 40}
@export var mission_difficulty: float = 1.0
@export var allow_retreat: bool = true

## The scene to return to after the mission ends (e.g., SettlementBridge.tscn)
# --- REMOVED ---
# @export var settlement_bridge_scene: PackedScene
# --- ADDED ---
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"


## If true, this mission will *not* check for the "all units destroyed" loss condition.
## This should be TRUE for the Sacked/Defensive mission.
@export var is_defensive_mission: bool = false

# --- MODIFIED: Node References ---
@onready var player_spawn_pos: Marker2D = $PlayerStartPosition
@onready var rts_controller: RTSController = $RTSController
# ---------------------------------

var enemy_hall: Node2D = null
var raid_loot: RaidLootData = null

# --- REMOVED ---
# var player_units: Array[Node2D] = []
# The RTSController now tracks all units.
# -----------------

func _ready() -> void:
	# Connect to the settlement_loaded signal - this works for both standalone and child scenarios
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	# If no settlement is currently loaded (standalone mode), load a test settlement
	if not SettlementManager.has_current_settlement():
		print("RaidMission: No current settlement - loading test settlement for standalone mode")
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		print("RaidMission: Settlement already loaded - initializing mission")
		call_deferred("initialize_mission")

func _load_test_settlement() -> void:
	"""Load a test settlement with garrison units for standalone testing"""
	var test_settlement_path = "res://data/settlements/home_base_fixed.tres"
	var test_settlement = load(test_settlement_path) as SettlementData
	
	if test_settlement:
		print("RaidMission: Loading test settlement: %s" % test_settlement_path)
		print("RaidMission: Test settlement garrison: %s" % test_settlement.garrisoned_units)
		SettlementManager.load_settlement(test_settlement)
	else:
		push_error("RaidMission: Failed to load test settlement from %s" % test_settlement_path)

func _on_settlement_ready_for_mission(settlement_data: SettlementData) -> void:
	"""Called when settlement is loaded - only initialize if we haven't already"""
	if not raid_loot:  # Check if we've already initialized
		print("RaidMission: Settlement loaded - initializing mission")
		initialize_mission()


func initialize_mission() -> void:
	"""
	This function now contains all the logic that used to be in _ready().
	It is called either by _ready() (if standalone) or by SettlementBridge.gd.
	"""
	print("RaidMission starting...")
	
	# Verify controller was found
	if rts_controller == null:
		push_error("RaidMission: Critical error! RTSController node not found.")
		get_tree().quit() # This is a fatal error
		return
	
	raid_loot = RaidLootData.new()
	
	if not enemy_base_data:
		enemy_base_data = load(default_enemy_base_path)
		if not enemy_base_data:
			push_error("Could not load enemy base data from default path.")
			return
	
	_load_enemy_base()
	_update_astar_grid_for_enemy_base()
	_spawn_player_garrison()
	_setup_win_loss_conditions()

func _load_enemy_base() -> void:
	"""Load and instance the enemy's base from SettlementData"""
	print("Loading enemy base...")
	
	if not enemy_base_data:
		push_error("No enemy base data provided")
		return
	
	# Instance each building from the enemy's placed_buildings array
	for building_entry in enemy_base_data.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var loaded_resource = load(building_res_path)
		var building_data: BuildingData = loaded_resource as BuildingData
		
		if not building_data:
			push_error("Failed to load building resource as BuildingData: %s (loaded as %s)" % [building_res_path, loaded_resource.get_class() if loaded_resource else "null"])
			continue
		
		if not building_data.scene_to_spawn:
			push_error("Failed to load building: %s" % building_res_path)
			continue
		
		# Instance the building
		var building_instance: Node2D = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Enemy"
		
		# Set building data
		if "data" in building_instance:
			building_instance.data = building_data
		
		# Position the building (convert grid to world position)
		var world_pos: Vector2 = Vector2(grid_pos) * 32 + Vector2(16, 16) # 32 = tile size
		building_instance.global_position = world_pos
		
		# Add to enemy groups for targeting
		building_instance.add_to_group("enemy_buildings")
		
		# Set collision layer for right-click detection and targeting
		if building_instance.has_method("set_collision_layer"):
			building_instance.set_collision_layer(4)  # Layer 3 for enemy buildings
			building_instance.set_collision_mask(0)   # Don't physically collide with anything
			print("Building %s collision setup: layer=4, mask=0" % building_data.display_name)
		else:
			push_warning("Building %s does not have collision layer methods!" % building_data.display_name)
		
		# Verify collision shape exists
		var collision_shape = building_instance.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			print("Building %s has collision shape: %s" % [building_data.display_name, collision_shape.shape.get_class()])
		else:
			push_error("Building %s missing collision shape!" % building_data.display_name)
		
		# Add debug area for targeting verification
		building_instance.set_meta("building_data", building_data)
		building_instance.set_meta("is_enemy_building", true)
		
		# Check if this is the Great Hall (main target)
		if building_data.display_name.to_lower().contains("hall"):
			enemy_hall = building_instance
			print("Found enemy hall: %s" % building_data.display_name)
			# Connect to building destroyed signal for win condition
			if building_instance.has_signal("building_destroyed"):
				building_instance.building_destroyed.connect(_on_enemy_hall_destroyed)
		
		# Connect ALL buildings to loot collection system
		if building_instance.has_signal("building_destroyed"):
			building_instance.building_destroyed.connect(_on_enemy_building_destroyed)
		
		# Add to scene
		add_child(building_instance)

func _update_astar_grid_for_enemy_base() -> void:
	"""Update the A* pathfinding grid to account for enemy buildings"""
	print("Updating A* grid for enemy base...")
	
	if not enemy_base_data:
		return
	
	# Process each building to update pathfinding grid
	for building_entry in enemy_base_data.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data:
			continue
		
		# Only block pathfinding for buildings that should block movement
		if building_data.blocks_pathfinding:
			var grid_size: Vector2i = building_data.grid_size
			
			# Mark all grid cells occupied by this building as blocked
			for x in range(grid_size.x):
				for y in range(grid_size.y):
					var cell_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
					SettlementManager.set_astar_point_solid(cell_pos, true)
			
			print("Blocked pathfinding for %s at %s (size: %s)" % [
				building_data.display_name, grid_pos, grid_size
			])
		else:
			print("Building %s does not block pathfinding" % building_data.display_name)
	
	# Update the grid once after all buildings are processed
	if SettlementManager.astar_grid:
		SettlementManager.astar_grid.update()
		print("A* grid updated for enemy base with %d buildings" % enemy_base_data.placed_buildings.size())

func _spawn_player_garrison() -> void:
	"""Spawn player units from the garrison"""
	print("=== SPAWNING PLAYER GARRISON ===")
	
	if not SettlementManager.current_settlement:
		print("No current settlement found - spawning test units for demo")
		_spawn_test_units() 
		return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	if garrison.is_empty():
		print("No units in garrison to spawn")
		# We must still check for a loss condition
		# --- MODIFIED: Check if this is a defensive mission ---
		if not is_defensive_mission:
			call_deferred("_check_loss_condition")
		# -----------------------------------------------------
		return
	
	var units_per_row: int = player_spawn_formation.get("units_per_row", 5)
	var spacing: float = player_spawn_formation.get("spacing", 40.0)
	var current_row: int = 0
	var current_col: int = 0
	
	for unit_path in garrison:
		var unit_count: int = garrison[unit_path]
		var unit_data: UnitData = load(unit_path)
		
		if not unit_data or not unit_data.scene_to_spawn:
			push_error("Failed to load unit data: %s" % unit_path)
			continue
		
		for i in range(unit_count):
			var unit_instance: Node2D = unit_data.scene_to_spawn.instantiate()
			
			# This is a critical check
			if not unit_instance is BaseUnit:
				push_error("Unit scene %s does not extend BaseUnit!" % unit_data.scene_to_spawn.get_path())
				continue
				
			unit_instance.name = unit_data.display_name + "_" + str(i)
			if "data" in unit_instance:
				unit_instance.data = unit_data
			
			var spawn_pos: Vector2 = player_spawn_pos.global_position
			spawn_pos.x += current_col * spacing
			spawn_pos.y += current_row * spacing
			unit_instance.global_position = spawn_pos
			
			unit_instance.add_to_group("player_units")
			
			# --- MODIFIED: This is the new, clean way ---
			# We hand the unit to our controller.
			rts_controller.add_unit_to_group(unit_instance)
			# --------------------------------------------
			
			add_child(unit_instance)
			
			current_col += 1
			if current_col >= units_per_row:
				current_col = 0
				current_row += 1


func _spawn_test_units() -> void:
	"""
	Spawn test units for demonstration.
	NOTE: This debug code is brittle as it creates
	units that are not BaseUnit.
	"""
	print("Spawning test units for box selection demo...")
	
	var units_per_row: int = 3
	var current_row: int = 0
	var current_col: int = 0
	
	for i in range(6):
		var test_unit = CharacterBody2D.new()
		# ... (rest of the test unit creation code) ...
		var script_source = """
extends CharacterBody2D
var is_selected: bool = false; var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 100.0; var is_moving: bool = false
func set_selected(selected: bool) -> void: is_selected = selected; queue_redraw()
func _draw() -> void:
	if is_selected: draw_circle(Vector2.ZERO, 15.0, Color(1,1,0,0.8), false, 2.0)
func command_move_to(target_pos: Vector2) -> void: target_position = target_pos; is_moving = true
func command_attack(target: Node2D) -> void: print('%s attacking %s' % [name, target.name])
func set_target_position(pos: Vector2) -> void: target_position = pos; is_moving = true
func _physics_process(delta: float) -> void:
	if is_moving and target_position != Vector2.ZERO:
		var dir = (target_position - global_position).normalized()
		if global_position.distance_to(target_position) < 5.0:
			is_moving = false; velocity = Vector2.ZERO
		else: velocity = dir * move_speed
		move_and_slide()
"""
		var temp_script = GDScript.new(); temp_script.source_code = script_source
		temp_script.reload(); test_unit.set_script(temp_script)
		
		# ... (code to position and add_child the unit) ...
		var spawn_pos: Vector2 = player_spawn_pos.global_position
		spawn_pos.x += current_col * 60
		spawn_pos.y += current_row * 60
		test_unit.global_position = spawn_pos
		test_unit.add_to_group("player_units")
		add_child(test_unit)

		# --- MODIFIED: Register test unit with controller ---
		# We must check if it's a BaseUnit, which it is not.
		# This debug code will not work with our new system
		# without a significant rewrite.
		if test_unit is BaseUnit:
			rts_controller.add_unit_to_group(test_unit)
		else:
			push_warning("Test unit '%s' is not a BaseUnit. Skipping add to RTSController." % test_unit.name)
		# ----------------------------------------------------
		
		current_col += 1
		if current_col >= units_per_row:
			current_col = 0
			current_row += 1

# --- REMOVED ---
# The _setup_rts_controller() function is now gone.
# -----------------

func _on_enemy_building_destroyed(building: BaseBuilding) -> void:
	"""Called when any enemy building is destroyed - collect loot and update grid"""
	var building_data = building.data as BuildingData
	
	if raid_loot and building_data:
		raid_loot.add_loot_from_building(building_data)
		print("Building destroyed: %s | %s" % [building_data.display_name, raid_loot.get_loot_summary()])
	
	# Update pathfinding grid to make the area passable again
	_clear_building_from_pathfinding_grid(building)
	
	# Count remaining buildings for mission tracking
	var remaining_buildings = get_tree().get_nodes_in_group("enemy_buildings").size()
	print("Buildings remaining: %d" % remaining_buildings)

func _clear_building_from_pathfinding_grid(building: BaseBuilding) -> void:
	"""Remove building's collision from pathfinding grid"""
	if not building.data:
		return
		
	# Calculate the grid position from the building's world position
	var world_pos = building.global_position
	var grid_pos = Vector2i((world_pos - Vector2(16, 16)) / 32)  # Reverse the positioning logic
	var grid_size = building.data.grid_size
	
	# Clear all grid cells that were occupied by this building
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			SettlementManager.set_astar_point_solid(cell_pos, false)
	
	# Update the grid
	if SettlementManager.astar_grid:
		SettlementManager.astar_grid.update()
		print("Cleared pathfinding for destroyed building at %s (size: %s)" % [grid_pos, grid_size])

func _setup_win_loss_conditions() -> void:
	"""Setup win/loss condition monitoring"""
	# --- MODIFIED: Check if this is a defensive mission ---
	if not is_defensive_mission:
		# Start periodic check for loss condition
		_check_loss_condition()
	else:
		print("RaidMission: Skipping 'all units destroyed' loss check for defensive mission.")
	# -----------------------------------------------------

func _check_loss_condition() -> void:
	"""Check if all player units are destroyed (loss condition)"""
	# This is a recursive timer loop.
	await get_tree().create_timer(1.0).timeout
	
	# --- MODIFIED: Ask the controller ---
	# The RTSController is now the single source of truth for unit counts.
	var remaining_units = 0
	if is_instance_valid(rts_controller):
		remaining_units = rts_controller.controllable_units.size()
	# ------------------------------------
	
	print("Loss check: %d units remaining" % remaining_units)
	
	if remaining_units == 0:
		_on_mission_failed()
		return # Stop the loop
	
	# Continue checking if mission is still active
	if is_instance_valid(enemy_hall):
		_check_loss_condition()
	else:
		print("Loss condition checking stopped - enemy hall destroyed")

func _on_mission_failed() -> void:
	"""Called when all player units are destroyed"""
	print("Mission Failed! All units destroyed.")
	
	_show_failure_message()
	
	await get_tree().create_timer(3.0).timeout
	
	# --- MODIFIED: Emit signal ---
	if not settlement_bridge_scene_path.is_empty():
		EventBus.scene_change_requested.emit(settlement_bridge_scene_path)
	else:
		push_error("RaidMission: settlement_bridge_scene_path is not set! Cannot return to settlement.")
	# --- END MODIFICATION ---


func _show_failure_message() -> void:
	"""Display the mission failure message to the player"""
	var failure_popup = Control.new()
	failure_popup.name = "FailurePopup"
	failure_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.modulate = Color(0, 0, 0, 0.7)
	failure_popup.add_child(bg_panel)
	
	var message_container = VBoxContainer.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_container.size = Vector2(300, 150)
	
	var failure_label = Label.new()
	failure_label.text = "RAID FAILED!"
	# ... (rest of label setup)
	message_container.add_child(failure_label)
	
	var subtitle_label = Label.new()
	subtitle_label.text = "All units destroyed"
	# ... (rest of label setup)
	message_container.add_child(subtitle_label)
	
	var return_label = Label.new()
	return_label.text = "Returning to settlement..."
	# ... (rest of label setup)
	message_container.add_child(return_label)
	
	failure_popup.add_child(message_container)
	add_child(failure_popup)
	print("Failure message displayed")

func _on_enemy_hall_destroyed(_building: BaseBuilding = null) -> void:
	"""Called when the enemy's Great Hall is destroyed"""
	print("Enemy Hall destroyed! Mission success!")
	
	var total_loot = raid_loot.get_total_loot()
	raid_loot.add_loot("gold", 200) # Bonus
	total_loot = raid_loot.get_total_loot()
	
	SettlementManager.deposit_resources(total_loot)
	print("Mission Complete! %s" % raid_loot.get_loot_summary())
	
	await get_tree().create_timer(2.0).timeout
	
	# --- MODIFIED: Emit signal ---
	if not settlement_bridge_scene_path.is_empty():
		EventBus.scene_change_requested.emit(settlement_bridge_scene_path)
	else:
		push_error("Ra...
		
		idMission: settlement_bridge_scene_path is not set! Cannot return to settlement.")
	# --- END MODIFICATION ---
