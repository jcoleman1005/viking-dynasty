# res://autoload/SettlementManager.gd
#
# A global Singleton (Autoload) that acts as a pure data manager
# for the player's current settlement.
#
# --- REFACTORED (The "Proper Fix") ---
# This script is now data-only and has no scene dependencies.
# All node instantiation, container management, and AStarGrid logic
# has been moved to the scenes that need it (e.g., SettlementBridge.gd
# and RaidMission.gd).

extends Node

var current_settlement: SettlementData

# --- NEW: Scene Registry ---
# These variables hold references to nodes in the *active* scene
# (e.g., SettlementBridge or RaidMission).
# This lets us fix the "buildings in raid" bug while minimizing
# refactoring of other scripts, which can still call SettlementManager.
var active_astar_grid: AStarGrid2D = null
var active_building_container: Node2D = null
# ---------------------------


# --- Scene Management ---

func register_active_scene_nodes(grid: AStarGrid2D, container: Node2D) -> void:
	"""
	Called by the active scene (e.g., SettlementBridge) to register
	its local pathfinding grid and building container.
	"""
	if not is_instance_valid(grid) or not is_instance_valid(container):
		push_error("SettlementManager: Failed to register invalid scene nodes.")
		return
	active_astar_grid = grid
	active_building_container = container
	print("SettlementManager: Active scene nodes registered.")

func unregister_active_scene_nodes() -> void:
	"""Called by the active scene when it exits to clear references."""
	active_astar_grid = null
	active_building_container = null
	print("SettlementManager: Active scene nodes unregistered.")


# --- Settlement Data ---

func load_settlement(data: SettlementData) -> void:
	if not data:
		push_error("SettlementManager: load_settlement called with null data.")
		return
	
	current_settlement = data
	
	if not current_settlement.resource_path or current_settlement.resource_path.is_empty():
		if data.resource_path and not data.resource_path.is_empty():
			current_settlement.resource_path = data.resource_path
		else:
			current_settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
			# Changed print to push_warning for setting fallback path
			push_warning("SettlementManager: Set fallback resource_path to: %s" % current_settlement.resource_path)
	
	print("SettlementManager: Settlement data loaded - %s" % current_settlement.resource_path)
	print("SettlementManager: Garrison units: %s" % current_settlement.garrisoned_units)
	
	EventBus.settlement_loaded.emit(current_settlement)


func save_settlement() -> void:
	if not current_settlement:
		push_error("Attempted to save a null settlement.")
		return
	
	if current_settlement.resource_path and not current_settlement.resource_path.is_empty():
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
	return current_settlement != null


# --- Treasury & Economy ---

func deposit_resources(loot: Dictionary) -> void:
	if not current_settlement: return
	for resource_type in loot:
		if current_settlement.treasury.has(resource_type):
			current_settlement.treasury[resource_type] += loot[resource_type]
		else:
			current_settlement.treasury[resource_type] = loot[resource_type]
	EventBus.treasury_updated.emit(current_settlement.treasury)
	# Removed print("Loot deposited. New treasury: %s" % current_settlement.treasury)
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
	# Removed print("Purchase successful. New treasury: %s" % current_settlement.treasury)
	return true

# --- MODIFIED: Added Stewardship Bonus Logic ---
func calculate_payout() -> Dictionary:
	if not current_settlement:
		return {}

	var total_payout: Dictionary = {}
	
	# 1. Get the Jarl's stewardship bonus
	var stewardship_bonus: float = 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		# Logic: +5% bonus for every point of stewardship above 10
		var stewardship_skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (stewardship_skill - 10) * 0.05
		# Ensure bonus can't be negative (e.g., stewardship below 10)
		stewardship_bonus = max(0.5, stewardship_bonus) # Cap negative bonus at -50%
		# Removed: print("Jarl Stewardship: %d. Payout Multiplier: %s" % [stewardship_skill, stewardship_bonus])
	else:
		push_warning("SettlementManager: Could not get Jarl to calculate stewardship bonus.")

	# 2. Calculate payout for each building
	for building_entry in current_settlement.placed_buildings:
		var building_data: BuildingData = load(building_entry["resource_path"])
		if building_data is EconomicBuildingData:
			var eco_data: EconomicBuildingData = building_data
			var resource_type: String = eco_data.resource_type
			
			if not total_payout.has(resource_type):
				total_payout[resource_type] = 0
			
			# 3. Apply the bonus and round to the nearest integer
			var base_payout = eco_data.fixed_payout_amount
			var final_payout = int(round(base_payout * stewardship_bonus))
			
			total_payout[resource_type] += final_payout

	# --- NEW: Add income from Conquered Regions ---
	if jarl:
		for region_path in jarl.conquered_regions:
			var region_data: WorldRegionData = load(region_path)
			if not region_data:
				push_warning("Could not load conquered region data from path: %s" % region_path)
				continue
			
			for resource_type in region_data.yearly_income:
				var income_amount = region_data.yearly_income[resource_type]
				if not total_payout.has(resource_type):
					total_payout[resource_type] = 0
				
				# Apply stewardship bonus to region income as well
				var final_income = int(round(income_amount * stewardship_bonus))
				total_payout[resource_type] += final_income
				# Removed: print("Added %d %s from conquered region: %s" % [final_income, resource_type, region_data.display_name])
	# --- END NEW ---

	# Removed: if not total_payout.is_empty(): print("Calculated fixed payout (with bonus): %s" % total_payout)
	return total_payout

func recruit_unit(unit_data: UnitData) -> void:
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
	
	if current_settlement.garrisoned_units.has(unit_path):
		current_settlement.garrisoned_units[unit_path] += 1
	else:
		current_settlement.garrisoned_units[unit_path] = 1
	
	print("Recruited %s. Garrison count: %d" % [unit_data.display_name, current_settlement.garrisoned_units[unit_path]])
	
	save_settlement()
	EventBus.purchase_successful.emit(unit_data.display_name)


# --- Building & Pathfinding (Delegated) ---

func get_active_grid_cell_size() -> Vector2:
	"""
	Returns the cell size of the currently registered AStarGrid.
	Used by Base_Building to scale itself correctly.
	"""
	if is_instance_valid(active_astar_grid):
		return active_astar_grid.cell_size
	
	# Fallback in case no grid is registered
	push_warning("SettlementManager: get_active_grid_cell_size() called, but no grid is active. Returning default (32,32).")
	return Vector2(32, 32)

func place_building(building_data: BuildingData, grid_position: Vector2i) -> BaseBuilding:
	if not is_instance_valid(active_astar_grid) or not is_instance_valid(active_building_container):
		push_error("Place building failed: Active scene nodes are not registered.")
		return null

	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return null
	
	if not is_placement_valid(grid_position, building_data.grid_size):
		push_error("Cannot place building at %s: position is invalid, out of bounds, or occupied." % grid_position)
		return null
	
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	# Calculate the center position of the building's entire footprint
	var world_pos_top_left: Vector2 = Vector2(grid_position) * active_astar_grid.cell_size
	var building_footprint_size: Vector2 = Vector2(building_data.grid_size) * active_astar_grid.cell_size
	var building_center_offset: Vector2 = building_footprint_size / 2.0
	new_building.global_position = world_pos_top_left + building_center_offset
	
	active_building_container.add_child(new_building)
	
	if building_data.blocks_pathfinding:
		for x in range(building_data.grid_size.x):
			for y in range(building_data.grid_size.y):
				var cell_pos = grid_position + Vector2i(x, y)
				if _is_cell_within_bounds(cell_pos): # Use local helper
					active_astar_grid.set_point_solid(cell_pos, true)
		
		active_astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_position)
		
	return new_building

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid):
		push_error("is_placement_valid: AStarGrid is not registered!")
		return false
	
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell_pos = grid_position + Vector2i(x, y)
			
			if not _is_cell_within_bounds(cell_pos):
				return false
			
			if active_astar_grid.is_point_solid(cell_pos):
				return false
	
	return true

func _is_cell_within_bounds(grid_position: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid):
		return false
	
	var bounds = active_astar_grid.region
	return grid_position.x >= bounds.position.x and grid_position.x < bounds.end.x and \
		   grid_position.y >= bounds.position.y and grid_position.y < bounds.end.y

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid):
		push_error("AStarGrid is not registered!")
		return PackedVector2Array()

	if active_astar_grid.region.size.x <= 0 or active_astar_grid.region.size.y <= 0:
		push_error("AStarGrid region is invalid: %s." % active_astar_grid.region)
		return PackedVector2Array()
	
	var start_id: Vector2i = Vector2i(start_pos / active_astar_grid.cell_size)
	var end_id: Vector2i = Vector2i(end_pos / active_astar_grid.cell_size)
	
	if not _is_cell_within_bounds(start_id):
		push_error("Start position (%s) -> grid_id (%s) is out of bounds." % [start_pos, start_id])
		return PackedVector2Array()
	
	if not _is_cell_within_bounds(end_id):
		# Don't error if the end_id is out of bounds, a partial path might still work
		pass
	
	# Pass the allow_partial_path flag to the real AStarGrid2D function
	return active_astar_grid.get_point_path(start_id, end_id, allow_partial_path)

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	if not is_instance_valid(active_astar_grid):
		push_warning("AStarGrid not registered")
		return
	
	if not _is_cell_within_bounds(grid_position):
		push_warning("Grid position %s is out of bounds" % grid_position)
		return
	
	active_astar_grid.set_point_solid(grid_position, solid)
