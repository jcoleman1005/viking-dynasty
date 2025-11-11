# res://autoload/SettlementManager.gd
#
# A global Singleton (Autoload) that acts as a pure data manager
# for the player's current settlement.
# --- MODIFIED: Phase 1.3 Blueprint Logic ---

extends Node

var current_settlement: SettlementData

# --- Scene Registry ---
var active_astar_grid: AStarGrid2D = null
var active_building_container: Node2D = null

# --- Scene Management ---

func register_active_scene_nodes(grid: AStarGrid2D, container: Node2D) -> void:
	if not is_instance_valid(grid) or not is_instance_valid(container):
		push_error("SettlementManager: Failed to register invalid scene nodes.")
		return
	active_astar_grid = grid
	active_building_container = container
	print("SettlementManager: Active scene nodes registered.")

func unregister_active_scene_nodes() -> void:
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
			push_warning("SettlementManager: Set fallback resource_path to: %s" % current_settlement.resource_path)
	
	print("SettlementManager: Settlement data loaded - %s" % current_settlement.resource_path)
	EventBus.settlement_loaded.emit(current_settlement)

func save_settlement() -> void:
	if not current_settlement:
		push_error("Attempted to save a null settlement.")
		return
	
	print("SettlementManager: Saving... Pending Buildings Count: %d" % current_settlement.pending_construction_buildings.size())
	
	# Debug: Print pending buildings before save
	_debug_print_pending_buildings()
	
	if current_settlement.resource_path and not current_settlement.resource_path.is_empty():
		if not current_settlement.get_script():
			current_settlement.set_script(preload("res://data/settlements/SettlementData.gd"))
		
		# Force resource to be marked as changed
		current_settlement.changed.emit()
		current_settlement.take_over_path(current_settlement.resource_path)
		
		var error = ResourceSaver.save(current_settlement, current_settlement.resource_path, ResourceSaver.FLAG_CHANGE_PATH)
		if error == OK:
			print("Settlement data saved successfully to %s" % current_settlement.resource_path)
			# Verify save by reloading and checking
			_debug_verify_save()
		else:
			push_error("Failed to save settlement data. Error code: %s" % error)
	else:
		push_warning("SettlementData has no resource_path, cannot save settlement.")

func _debug_print_pending_buildings() -> void:
	print("DEBUG: Current pending_construction_buildings:")
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		print("  [%d]: %s" % [i, entry])

func _debug_verify_save() -> void:
	# Try to reload the resource and check if pending buildings were saved
	if current_settlement.resource_path:
		var reloaded_settlement: SettlementData = load(current_settlement.resource_path)
		if reloaded_settlement:
			print("DEBUG: Verification - Reloaded settlement has %d pending buildings" % reloaded_settlement.pending_construction_buildings.size())
			for i in range(reloaded_settlement.pending_construction_buildings.size()):
				var entry = reloaded_settlement.pending_construction_buildings[i]
				print("  Reloaded [%d]: %s" % [i, entry])
		else:
			print("DEBUG: Failed to reload settlement for verification")

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
	EventBus.purchase_successful.emit("Unnamed Item")
	return true

func calculate_payout() -> Dictionary:
	if not current_settlement:
		return {}

	var total_payout: Dictionary = {}
	var stewardship_bonus: float = 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var stewardship_skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (stewardship_skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	# Only ACTIVE buildings generate resources (explicitly exclude blueprints/construction)
	# Loop through building instances in the scene to check their state
	if is_instance_valid(active_building_container):
		for child in active_building_container.get_children():
			if child is BaseBuilding:
				var building: BaseBuilding = child
				# Only ACTIVE buildings contribute to economy
				if building.is_active() and building.data is EconomicBuildingData:
					var eco_data: EconomicBuildingData = building.data
					var resource_type: String = eco_data.resource_type
					
					if not total_payout.has(resource_type):
						total_payout[resource_type] = 0
					
					var base_payout = eco_data.fixed_payout_amount
					var final_payout = int(round(base_payout * stewardship_bonus))
					total_payout[resource_type] += final_payout

	if jarl:
		for region_path in jarl.conquered_regions:
			var region_data: WorldRegionData = load(region_path)
			if not region_data: continue
			
			for resource_type in region_data.yearly_income:
				var income_amount = region_data.yearly_income[resource_type]
				if not total_payout.has(resource_type):
					total_payout[resource_type] = 0
				
				var final_income = int(round(income_amount * stewardship_bonus))
				total_payout[resource_type] += final_income

	if jarl:
		if current_settlement.has_stability_debuff:
			if total_payout.has("gold"):
				total_payout["gold"] = int(total_payout["gold"] * 0.75)
			current_settlement.has_stability_debuff = false
			save_settlement()

	return total_payout

func recruit_unit(unit_data: UnitData) -> void:
	if not current_settlement or not unit_data: return
	
	var unit_path: String = unit_data.resource_path
	if unit_path.is_empty(): return
	
	if current_settlement.garrisoned_units.has(unit_path):
		current_settlement.garrisoned_units[unit_path] += 1
	else:
		current_settlement.garrisoned_units[unit_path] = 1
	
	print("Recruited %s." % unit_data.display_name)
	save_settlement()
	EventBus.purchase_successful.emit(unit_data.display_name)


# --- Building & Pathfinding ---

func remove_building(building_instance: BaseBuilding) -> void:
	"""
	Removes a building from the scene, data model, and grid.
	Handles both 'placed' and 'pending' buildings.
	"""
	if not current_settlement or not is_instance_valid(building_instance):
		return

	# 1. Calculate Grid Position
	var cell_size = get_active_grid_cell_size()
	var building_pos = building_instance.global_position
	var size_pixels = Vector2(building_instance.data.grid_size) * cell_size
	var top_left_pixels = building_pos - (size_pixels / 2.0)
	var grid_pos = Vector2i(top_left_pixels / cell_size)
	
	# 2. Clear A* Grid (if it was blocking)
	# Blueprints might not block pathfinding yet, but good to clear anyway
	if is_instance_valid(active_astar_grid):
		for x in range(building_instance.data.grid_size.x):
			for y in range(building_instance.data.grid_size.y):
				var cell = grid_pos + Vector2i(x, y)
				if _is_cell_within_bounds(cell):
					active_astar_grid.set_point_solid(cell, false)
		active_astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_pos)

	# 3. Remove from Data Model
	# Check placed_buildings
	var removed = _remove_from_list(current_settlement.placed_buildings, grid_pos)
	if not removed:
		# Check pending_construction_buildings
		removed = _remove_from_list(current_settlement.pending_construction_buildings, grid_pos)
	
	if removed:
		save_settlement()
		print("SettlementManager: Removed %s from data at %s." % [building_instance.data.display_name, grid_pos])
	else:
		push_warning("SettlementManager: Could not find data entry for building at %s" % grid_pos)

	# 4. Remove Instance
	building_instance.queue_free()

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry = list[i]
		var entry_pos = entry["grid_position"]
		# Handle both Vector2 and Vector2i for compatibility
		var compare_pos = Vector2(grid_pos) if entry_pos is Vector2 else Vector2i(entry_pos)
		if compare_pos == grid_pos or Vector2(entry_pos) == Vector2(grid_pos):
			list.remove_at(i)
			return true
	return false

func get_active_grid_cell_size() -> Vector2:
	if is_instance_valid(active_astar_grid):
		return active_astar_grid.cell_size
	return Vector2(32, 32)

# --- MODIFIED: Updated for Phase 1.3 Blueprint Logic ---
func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	"""
	Instantiates and places a building.
	If is_new_construction is true:
		- Sets state to BLUEPRINT 
		- Adds to pending_construction_buildings 
		- Saves data
	If false (loading from save):
		- Sets state to ACTIVE (default assumption for legacy saves)
		- Does NOT save data (assumes it came from data)
	"""
	if not is_instance_valid(active_astar_grid) or not is_instance_valid(active_building_container):
		push_error("Place building failed: Active scene nodes are not registered.")
		return null

	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return null
	
	if not is_placement_valid(grid_position, building_data.grid_size):
		push_error("Cannot place building at %s: Invalid position." % grid_position)
		return null
	
	# Instantiate
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	# Position
	var world_pos_top_left: Vector2 = Vector2(grid_position) * active_astar_grid.cell_size
	var building_footprint_size: Vector2 = Vector2(building_data.grid_size) * active_astar_grid.cell_size
	var building_center_offset: Vector2 = building_footprint_size / 2.0
	new_building.global_position = world_pos_top_left + building_center_offset
	
	active_building_container.add_child(new_building)
	
	# Update Grid (Blueprints reserve the space)
	if building_data.blocks_pathfinding:
		for x in range(building_data.grid_size.x):
			for y in range(building_data.grid_size.y):
				var cell_pos = grid_position + Vector2i(x, y)
				if _is_cell_within_bounds(cell_pos):
					active_astar_grid.set_point_solid(cell_pos, true)
		
		active_astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_position)

	# --- Phase 1.3 Logic ---
	if is_new_construction:
		# 1. Set State to Blueprint 
		new_building.set_state(BaseBuilding.BuildingState.BLUEPRINT)
		
		# 2. Save to Pending List 
		var entry = {
			"resource_path": building_data.resource_path,
			"grid_position": Vector2(grid_position), # Convert Vector2i to Vector2 for better serialization
			"progress": 0 # Track construction progress
		}
		current_settlement.pending_construction_buildings.append(entry)
		save_settlement()
		print("SettlementManager: New blueprint placed at %s." % grid_position)
	else:
		# Loading existing building, assume Active for now
		new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
		
	return new_building

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid):
		return false
	
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell_pos = grid_position + Vector2i(x, y)
			if not _is_cell_within_bounds(cell_pos): return false
			if active_astar_grid.is_point_solid(cell_pos): return false
	
	return true

func _is_cell_within_bounds(grid_position: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	var bounds = active_astar_grid.region
	return grid_position.x >= bounds.position.x and grid_position.x < bounds.end.x and \
		   grid_position.y >= bounds.position.y and grid_position.y < bounds.end.y

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid): return PackedVector2Array()
	
	var start_id: Vector2i = Vector2i(start_pos / active_astar_grid.cell_size)
	var end_id: Vector2i = Vector2i(end_pos / active_astar_grid.cell_size)
	
	if not _is_cell_within_bounds(start_id): return PackedVector2Array()
	
	return active_astar_grid.get_point_path(start_id, end_id, allow_partial_path)

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_position):
		active_astar_grid.set_point_solid(grid_position, solid)

# --- Phase 1: Blueprint Construction Methods ---

func complete_building_construction(building: BaseBuilding) -> void:
	"""
	Called when a building transitions from BLUEPRINT/UNDER_CONSTRUCTION to ACTIVE.
	Moves the building from pending_construction_buildings to placed_buildings.
	"""
	if not current_settlement or not is_instance_valid(building): return
	
	# Calculate the building's grid position
	var cell_size = get_active_grid_cell_size()
	var building_pos = building.global_position
	var size_pixels = Vector2(building.data.grid_size) * cell_size
	var top_left_pixels = building_pos - (size_pixels / 2.0)
	var grid_pos = Vector2i(top_left_pixels / cell_size)
	
	# Find and remove from pending list
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		if entry["grid_position"] == grid_pos:
			# Move to placed buildings
			var placed_entry = {
				"resource_path": building.data.resource_path,
				"grid_position": grid_pos
			}
			current_settlement.placed_buildings.append(placed_entry)
			current_settlement.pending_construction_buildings.remove_at(i)
			save_settlement()
			print("SettlementManager: Building construction completed at %s" % grid_pos)
			return
	
	push_warning("SettlementManager: Could not find pending construction entry for building at %s" % grid_pos)

func get_pending_construction_buildings() -> Array:
	"""Returns a copy of the pending construction buildings array."""
	if not current_settlement: return []
	return current_settlement.pending_construction_buildings.duplicate()

func update_construction_progress(grid_pos: Vector2i, progress: int) -> void:
	"""Updates the progress of a building under construction."""
	if not current_settlement: return
	
	for entry in current_settlement.pending_construction_buildings:
		if entry["grid_position"] == grid_pos:
			entry["progress"] = progress
			return
	
	push_warning("SettlementManager: Could not find pending construction at %s to update progress" % grid_pos)

func get_construction_progress(grid_pos: Vector2i) -> int:
	"""Gets the current construction progress for a building at the given position."""
	if not current_settlement: return 0
	
	for entry in current_settlement.pending_construction_buildings:
		if entry["grid_position"] == grid_pos:
			return entry.get("progress", 0)
	
	return 0
