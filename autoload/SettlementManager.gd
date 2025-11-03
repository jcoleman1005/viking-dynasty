# res://autoload/SettlementManager.gd

extends Node

var current_settlement: SettlementData
var astar_grid: AStarGrid2D
@onready var building_container: Node2D = $BuildingContainer

const TILE_SIZE: int = 32
const GRID_WIDTH: int = 50
const GRID_HEIGHT: int = 30

func _ready() -> void:
	# Initialize the grid as soon as the manager is ready.
	# This ensures astar_grid is never null after this point.
	_initialize_grid()

func _initialize_grid() -> void:
	"""Initialize the AStarGrid2D with proper error handling"""
	astar_grid = AStarGrid2D.new()
	var playable_rect := Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	print("Settlement Grid Initialized: %dx%d cells" % [GRID_WIDTH, GRID_HEIGHT])

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
	var playable_rect := Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	# CRITICAL: Update the grid after setting parameters
	astar_grid.update()
	print("AStarGrid reinitialized: %dx%d cells" % [GRID_WIDTH, GRID_HEIGHT])
	
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
	
	# Validate grid position is within bounds
	if not _is_position_valid(grid_position):
		push_warning("Building placement at %s is outside grid bounds (%d x %d). Skipping pathfinding update." % [grid_position, GRID_WIDTH, GRID_HEIGHT])
		# Still create the building but don't update pathfinding
	
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	var world_pos_top_left: Vector2 = Vector2(grid_position) * astar_grid.cell_size
	var half_cell_offset: Vector2 = astar_grid.cell_size / 2.0
	new_building.global_position = world_pos_top_left + half_cell_offset
	
	building_container.add_child(new_building)
	
	# Only update pathfinding if position is valid and building blocks pathfinding
	if building_data.blocks_pathfinding and _is_position_valid(grid_position):
		# Ensure grid is properly initialized before setting solid points
		if astar_grid and astar_grid.region.size.x > 0 and astar_grid.region.size.y > 0:
			astar_grid.set_point_solid(grid_position, true)
			astar_grid.update()
			EventBus.pathfinding_grid_updated.emit(grid_position)
		else:
			push_warning("AStarGrid not properly initialized, skipping pathfinding update for building at %s" % grid_position)
		
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

func _is_position_valid(grid_position: Vector2i) -> bool:
	"""Check if a grid position is within the AStarGrid bounds"""
	return grid_position.x >= 0 and grid_position.x < GRID_WIDTH and \
		   grid_position.y >= 0 and grid_position.y < GRID_HEIGHT
