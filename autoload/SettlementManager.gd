# res://autoload/SettlementManager.gd

extends Node

var current_settlement: SettlementData
var astar_grid: AStarGrid2D
@onready var building_container: Node2D = $BuildingContainer

# --- Configurable Grid Settings ---
@export_group("Grid Configuration")
@export var tile_size: int = 32
@export var grid_width: int = 120  # Increased from 50
@export var grid_height: int = 80  # Increased from 30
@export var auto_resize_for_scene: bool = true  # Enable automatic scene detection

# Scene-specific overrides (optional)
@export_subgroup("Scene Overrides")
@export var settlement_grid_size: Vector2i = Vector2i(60, 40)
@export var raid_grid_size: Vector2i = Vector2i(120, 80)  # Increased for raid missions
@export var defense_grid_size: Vector2i = Vector2i(80, 60)  # Increased for defensive missions

func _ready() -> void:
	# Initialize the grid as soon as the manager is ready.
	# This ensures astar_grid is never null after this point.
	_initialize_grid()

func _initialize_grid() -> void:
	"""Initialize the AStarGrid2D with proper error handling"""
	# Auto-detect scene type and adjust grid size if enabled
	if auto_resize_for_scene:
		_detect_and_set_grid_size()
	
	astar_grid = AStarGrid2D.new()
	var playable_rect := Rect2i(0, 0, grid_width, grid_height)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(tile_size, tile_size)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	print("Settlement Grid Initialized: %dx%d cells (auto-detected: %s)" % [grid_width, grid_height, auto_resize_for_scene])

func load_settlement(data: SettlementData) -> void:
	if not data:
		push_error("SettlementManager: load_settlement called with null data.")
		return
	
	current_settlement = data
	
	# Ensure resource_path is set for saving later
	if not current_settlement.resource_path or current_settlement.resource_path.is_empty():
		# Try to determine the path from how it was loaded
		if data.resource_path and not data.resource_path.is_empty():
			current_settlement.resource_path = data.resource_path
		else:
			# Fallback: assume it's the home base file
			current_settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
			print("SettlementManager: Set fallback resource_path to: %s" % current_settlement.resource_path)
	
	print("SettlementManager: Settlement loaded - %s" % current_settlement.resource_path)
	print("SettlementManager: Garrison units: %s" % current_settlement.garrisoned_units)
	
	# The grid already exists. Clear its state before loading new buildings.
	# Note: clear() resets the region to (0,0,0,0), so we must reinitialize
	astar_grid.clear()
	
	# Reinitialize grid parameters after clear()
	var playable_rect := Rect2i(0, 0, grid_width, grid_height)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(tile_size, tile_size)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	# CRITICAL: Update the grid after setting parameters
	astar_grid.update()
	print("AStarGrid reinitialized: %dx%d cells" % [grid_width, grid_height])
	
	for child in building_container.get_children():
		child.queue_free()

	for building_entry in current_settlement.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if building_data:
			place_building(building_data, grid_pos)
		else:
			push_error("Failed to load building resource from path: %s" % building_res_path)
	
	# Update the grid once after all new solid points have been set
	astar_grid.update()
	print("Settlement loaded with %d buildings." % building_container.get_child_count())


func place_building(building_data: BuildingData, grid_position: Vector2i) -> BaseBuilding:
	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return null
	
	# Use new, robust validation check
	if not is_placement_valid(grid_position, building_data.grid_size):
		push_error("Cannot place building at %s: position is invalid, out of bounds, or occupied." % grid_position)
		return null
	
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	var world_pos_top_left: Vector2 = Vector2(grid_position) * astar_grid.cell_size
	var half_cell_offset: Vector2 = astar_grid.cell_size / 2.0
	new_building.global_position = world_pos_top_left + half_cell_offset
	
	building_container.add_child(new_building)
	
	# --- MODIFIED: This is the critical fix ---
	# Mark *all* cells occupied by the building as solid, not just the top-left corner.
	if building_data.blocks_pathfinding:
		if astar_grid and astar_grid.region.size.x > 0 and astar_grid.region.size.y > 0:
			for x in range(building_data.grid_size.x):
				for y in range(building_data.grid_size.y):
					var cell_pos = grid_position + Vector2i(x, y)
					# Check if cell is *within* bounds before setting it
					if _is_cell_within_bounds(cell_pos):
						astar_grid.set_point_solid(cell_pos, true)
			
			astar_grid.update() # Update grid *after* all points are set
			EventBus.pathfinding_grid_updated.emit(grid_position)
		else:
			push_warning("AStarGrid not properly initialized, skipping pathfinding update for building at %s" % grid_position)
	# --- END MODIFICATION ---
		
	return new_building

func deposit_resources(loot: Dictionary) -> void:
	if not current_settlement: return
	for resource_type in loot:
		if current_settlement.treasury.has(resource_type):
			# Payouts should respect the storage cap of the building that generated them,
			# but the main treasury can be considered unlimited for now.
			current_settlement.treasury[resource_type] += loot[resource_type]
		else:
			current_settlement.treasury[resource_type] = loot[resource_type]
	EventBus.treasury_updated.emit(current_settlement.treasury)
	print("Loot deposited. New treasury: %s" % current_settlement.treasury)
	save_settlement()

func attempt_purchase(item_cost: Dictionary) -> bool:
	if not current_settlement: return false
	
	for resource_type in item_cost:
		if not current_settlement.treasury.has(resource_type) or \
		current_settlement.treasury[resource_type] < item_cost[resource_type]:
			var reason = "Insufficient %s" % resource_type
			print("Purchase failed. %s." % reason)
			EventBus.purchase_failed.emit(reason)
			return false
			
	for resource_type in item_cost:
		current_settlement.treasury[resource_type] -= item_cost[resource_type]
	
	EventBus.treasury_updated.emit(current_settlement.treasury)
	EventBus.purchase_successful.emit("Unnamed Item") # Placeholder
	print("Purchase successful. New treasury: %s" % current_settlement.treasury)
	return true

func calculate_payout() -> Dictionary:
	if not current_settlement:
		return {}

	var total_payout: Dictionary = {}

	for building_entry in current_settlement.placed_buildings:
		var building_data: BuildingData = load(building_entry["resource_path"])
		if building_data is EconomicBuildingData:
			var eco_data: EconomicBuildingData = building_data
			var resource_type: String = eco_data.resource_type
			
			if not total_payout.has(resource_type):
				total_payout[resource_type] = 0
			
			# The payout is now a simple, fixed amount per building.
			# The storage_cap is now effectively the treasury cap, handled in deposit_loot.
			total_payout[resource_type] += eco_data.fixed_payout_amount

	if not total_payout.is_empty():
		print("Calculated fixed payout: %s" % total_payout)
	return total_payout

func get_astar_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	if not astar_grid:
		push_error("AStarGrid is not initialized!")
		return PackedVector2Array()
	
	# Check if grid region is properly set
	if astar_grid.region.size.x <= 0 or astar_grid.region.size.y <= 0:
		push_error("AStarGrid region is invalid: %s. Grid was likely cleared but not reinitialized." % astar_grid.region)
		return PackedVector2Array()
	
	var start_id: Vector2i = Vector2i(start_pos / astar_grid.cell_size)
	var end_id: Vector2i = Vector2i(end_pos / astar_grid.cell_size)
	
	# Check bounds before calling get_point_path
	if start_id.x < 0 or start_id.x >= astar_grid.region.size.x or start_id.y < 0 or start_id.y >= astar_grid.region.size.y:
		push_error("Start position (%s) -> grid_id (%s) is out of bounds. Grid size: %s" % [start_pos, start_id, astar_grid.region.size])
		return PackedVector2Array()
	
	if end_id.x < 0 or end_id.x >= astar_grid.region.size.x or end_id.y < 0 or end_id.y >= astar_grid.region.size.y:
		push_error("End position (%s) -> grid_id (%s) is out of bounds. Grid size: %s" % [end_pos, end_id, astar_grid.region.size])
		return PackedVector2Array()
	
	return astar_grid.get_point_path(start_id, end_id)

func recruit_unit(unit_data: UnitData) -> void:
	"""Add a unit to the garrison"""
	if not current_settlement:
		push_error("Cannot recruit unit: no current settlement")
		return
	
	if not unit_data:
		push_error("Cannot recruit: UnitData is null")
		return
	
	var unit_path: String = unit_data.resource_path
	if unit_path.is_empty():
		push_error("Cannot recruit: UnitData has no resource_path")
		return
	
	# Increment the count for this unit type
	if current_settlement.garrisoned_units.has(unit_path):
		current_settlement.garrisoned_units[unit_path] += 1
	else:
		current_settlement.garrisoned_units[unit_path] = 1
	
	print("Recruited %s. Garrison count: %d" % [unit_data.display_name, current_settlement.garrisoned_units[unit_path]])
	
	# Save the updated settlement
	save_settlement()
	
	# Emit event for UI updates
	EventBus.purchase_successful.emit(unit_data.display_name)

func save_settlement() -> void:
	if not current_settlement:
		push_error("Attempted to save a null settlement.")
		return
	
	if current_settlement.resource_path and not current_settlement.resource_path.is_empty():
		# Ensure the settlement uses the external SettlementData script class
		# This prevents inline script conflicts when saving
		if not current_settlement.get_script():
			current_settlement.set_script(preload("res://data/settlements/SettlementData.gd"))
		
		var error = ResourceSaver.save(current_settlement, current_settlement.resource_path)
		if error == OK:
			print("Settlement data saved successfully to: %s" % current_settlement.resource_path)
		else:
			push_error("Failed to save settlement data to path: %s. Error code: %s" % [current_settlement.resource_path, error])
	else:
		push_warning("SettlementData has no resource_path, cannot save settlement.")

func has_current_settlement() -> bool:
	"""Check if there's a valid current settlement loaded"""
	return current_settlement != null

func get_settlement_status() -> String:
	"""Get debug information about the current settlement"""
	if not current_settlement:
		return "No settlement loaded"
	
	var garrison_count = 0
	for unit_path in current_settlement.garrisoned_units:
		garrison_count += current_settlement.garrisoned_units[unit_path]
	
	return "Settlement: %s | Buildings: %d | Garrison units: %d" % [
		current_settlement.resource_path.get_file(),
		current_settlement.placed_buildings.size(),
		garrison_count
	]

# --- NEW FUNCTION ---
func is_placement_valid(grid_position: Vector2i, building_size: Vector2i) -> bool:
	"""
	Checks if a building can be placed at a location.
	This is now the single source of truth for placement.
	"""
	if not astar_grid:
		push_error("is_placement_valid: AStarGrid is not initialized!")
		return false
	
	# Check all cells the building would occupy
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell_pos = grid_position + Vector2i(x, y)
			
			# 1. Check if cell is within grid bounds
			if not _is_cell_within_bounds(cell_pos):
				return false
			
			# 2. Check if cell is already solid (occupied)
			if astar_grid.is_point_solid(cell_pos):
				return false
	
	# All cells are valid and unoccupied
	return true

# --- RENAMED FUNCTION (was _is_position_valid) ---
func _is_cell_within_bounds(grid_position: Vector2i) -> bool:
	"""Check if a *single* grid cell is within the AStarGrid bounds"""
	return grid_position.x >= 0 and grid_position.x < grid_width and \
		   grid_position.y >= 0 and grid_position.y < grid_height

# --- REMOVED FUNCTION ---
# _is_position_occupied() is no longer needed, as its logic
# is now correctly handled by is_placement_valid() checking the AStarGrid.

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	"""Public interface to set pathfinding grid points as solid/passable"""
	if not astar_grid:
		push_warning("AStarGrid not initialized")
		return
	
	if not _is_cell_within_bounds(grid_position):
		push_warning("Grid position %s is out of bounds" % grid_position)
		return
	
	if astar_grid.region.size.x <= 0 or astar_grid.region.size.y <= 0:
		push_warning("AStarGrid region is invalid")
		return
	
	astar_grid.set_point_solid(grid_position, solid)
	# Don't call update() here - let caller decide when to batch update

func _detect_and_set_grid_size() -> void:
	"""Auto-detect the current scene type and set appropriate grid size"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("SettlementManager: No current scene found for auto-detection")
		return
	
	var scene_name = current_scene.name.to_lower()
	var scene_path = current_scene.scene_file_path.to_lower()
	
	print("SettlementManager: Detecting scene type from '%s' (%s)" % [scene_name, scene_path])
	
	# Detect raid missions
	if "raid" in scene_name or "raid" in scene_path:
		grid_width = raid_grid_size.x
		grid_height = raid_grid_size.y
		print("SettlementManager: Auto-detected RAID mission - using grid %dx%d" % [grid_width, grid_height])
	
	# Detect defensive missions
	elif "defensive" in scene_name or "defense" in scene_path or "sacked" in scene_name:
		grid_width = defense_grid_size.x
		grid_height = defense_grid_size.y
		print("SettlementManager: Auto-detected DEFENSIVE mission - using grid %dx%d" % [grid_width, grid_height])
	
	# Detect settlement/bridge scenes
	elif "settlement" in scene_name or "bridge" in scene_path:
		grid_width = settlement_grid_size.x
		grid_height = settlement_grid_size.y
		print("SettlementManager: Auto-detected SETTLEMENT scene - using grid %dx%d" % [grid_width, grid_height])
	
	# Use large default for unknown scenes
	else:
		print("SettlementManager: Unknown scene type - using default large grid %dx%d" % [grid_width, grid_height])
