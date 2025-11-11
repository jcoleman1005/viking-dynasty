# res://autoload/SettlementManager.gd
#
# A global Singleton (Autoload) that acts as a pure data manager
# for the player's current settlement.
# --- MODIFIED: Phase 2.3 Economic Engine Integration ---

extends Node

# --- Configuration Constants ---
# Tweak these to balance the game pacing
const BUILDER_EFFICIENCY: int = 25 # Construction progress per worker per year
const GATHERER_EFFICIENCY: int = 10 # Resources produced per worker per year

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
	
	var count = 0
	if current_settlement.pending_construction_buildings:
		count = current_settlement.pending_construction_buildings.size()
		
	print("SettlementManager: Saving... Pending Buildings Count: %d" % count)
	
	if current_settlement.resource_path and not current_settlement.resource_path.is_empty():
		if not current_settlement.get_script():
			current_settlement.set_script(preload("res://data/settlements/SettlementData.gd"))
		
		var error = ResourceSaver.save(current_settlement, current_settlement.resource_path)
		if error == OK:
			print("Settlement data saved successfully.")
		else:
			push_error("Failed to save settlement data. Error code: %s" % error)
	else:
		push_warning("SettlementData has no resource_path, cannot save settlement.")

func has_current_settlement() -> bool:
	return current_settlement != null

# --- Treasury & Economy (Phase 2.3 Updated) ---

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
	"""
	Calculates total resource gain based on:
	1. Assigned Workers (Labor) -> The Core Engine
	2. Active Economic Buildings (Passive Bonus)
	3. Jarl Stewardship Bonus
	Also processes construction progress immediately.
	"""
	if not current_settlement:
		return {}

	# --- 1. Process Construction First ---
	# We do this before calculating payout so newly finished buildings don't produce immediately (optional design choice)
	_process_construction_labor()

	var total_payout: Dictionary = {}
	
	# --- 2. Jarl Bonus Calculation ---
	var stewardship_bonus: float = 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var stewardship_skill = jarl.get_effective_skill("stewardship")
		# 5% bonus per point over 10
		stewardship_bonus = 1.0 + (stewardship_skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	# --- 3. Labor Output (Active) ---
	# This is now the primary source of income
	if current_settlement.worker_assignments:
		for resource_type in ["food", "wood", "stone", "gold"]:
			var assigned_workers = current_settlement.worker_assignments.get(resource_type, 0)
			if assigned_workers > 0:
				if not total_payout.has(resource_type):
					total_payout[resource_type] = 0
				
				# Workers provide base yield * efficiency * stewardship
				var labor_yield = int(assigned_workers * GATHERER_EFFICIENCY * stewardship_bonus)
				total_payout[resource_type] += labor_yield
				print("Labor added %d %s (%d workers)" % [labor_yield, resource_type, assigned_workers])

	# --- 4. Building Output (Passive) ---
	# Active buildings act as multipliers or static bonuses
	for building_entry in current_settlement.placed_buildings:
		var building_data: BuildingData = load(building_entry["resource_path"])
		if building_data is EconomicBuildingData:
			var eco_data: EconomicBuildingData = building_data
			var resource_type: String = eco_data.resource_type
			
			if not total_payout.has(resource_type):
				total_payout[resource_type] = 0
			
			var base_payout = eco_data.fixed_payout_amount
			var final_payout = int(round(base_payout * stewardship_bonus))
			total_payout[resource_type] += final_payout

	# --- 5. Region Income ---
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

	# --- 6. Debuffs ---
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

# --- Building Construction Logic (Phase 2.3) ---

func _process_construction_labor() -> void:
	"""
	Applies assigned construction labor to pending blueprints.
	Moves completed buildings to the active list.
	"""
	if not current_settlement: return
	
	# 1. Calculate Total Work Available
	var assigned_builders = current_settlement.worker_assignments.get("construction", 0)
	if assigned_builders <= 0:
		print("End Year: No builders assigned. Construction stalled.")
		return
		
	var total_labor_points = assigned_builders * BUILDER_EFFICIENCY
	print("End Year: Processing Construction. Available Labor: %d" % total_labor_points)
	
	var completed_indices: Array[int] = []
	
	# 2. Apply Work to Blueprints
	# We iterate cleanly through the pending list
	for i in range(current_settlement.pending_construction_buildings.size()):
		if total_labor_points <= 0:
			break # Run out of labor
			
		var entry = current_settlement.pending_construction_buildings[i]
		var building_data = load(entry["resource_path"]) as BuildingData
		
		if not building_data: continue
		
		# Determine effort needed
		var current_progress = entry.get("progress", 0)
		var effort_needed = building_data.construction_effort_required
		var effort_remaining = effort_needed - current_progress
		
		# Apply points (capped by remaining effort for this building)
		var points_to_apply = min(total_labor_points, effort_remaining)
		
		# Update Data
		entry["progress"] = current_progress + points_to_apply
		total_labor_points -= points_to_apply
		
		print("  > Applied %d points to %s (Progress: %d/%d)" % [points_to_apply, building_data.display_name, entry["progress"], effort_needed])
		
		# 3. Check Completion
		if entry["progress"] >= effort_needed:
			print("  >>> Construction COMPLETE: %s" % building_data.display_name)
			completed_indices.append(i)
			
			# Add to placed buildings (ACTIVE)
			var new_placed_entry = {
				"resource_path": entry["resource_path"],
				"grid_position": entry["grid_position"]
			}
			current_settlement.placed_buildings.append(new_placed_entry)
	
	# 4. Cleanup Completed Blueprints
	# Iterate backwards to remove safely
	completed_indices.sort()
	completed_indices.reverse()
	
	for i in completed_indices:
		current_settlement.pending_construction_buildings.remove_at(i)
		
	# 5. Save changes
	save_settlement()
	
	# 6. Reload Scene if needed (Optional, but safe)
	# If we just finished a building, we want to see it turn solid immediately
	if not completed_indices.is_empty():
		EventBus.scene_change_requested.emit("settlement") # Reloads the scene to refresh visuals

# --- Building & Pathfinding ---

func remove_building(building_instance: BaseBuilding) -> void:
	if not current_settlement or not is_instance_valid(building_instance): return

	var cell_size = get_active_grid_cell_size()
	var building_pos = building_instance.global_position
	var size_pixels = Vector2(building_instance.data.grid_size) * cell_size
	var top_left_pixels = building_pos - (size_pixels / 2.0)
	var grid_pos = Vector2i(top_left_pixels / cell_size)
	
	if is_instance_valid(active_astar_grid):
		for x in range(building_instance.data.grid_size.x):
			for y in range(building_instance.data.grid_size.y):
				var cell = grid_pos + Vector2i(x, y)
				if _is_cell_within_bounds(cell):
					active_astar_grid.set_point_solid(cell, false)
		active_astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_pos)

	var removed = _remove_from_list(current_settlement.placed_buildings, grid_pos)
	if not removed:
		removed = _remove_from_list(current_settlement.pending_construction_buildings, grid_pos)
	
	if removed:
		save_settlement()
		print("SettlementManager: Removed %s from data at %s." % [building_instance.data.display_name, grid_pos])
	else:
		push_warning("SettlementManager: Could not find data entry for building at %s" % grid_pos)

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
	if is_instance_valid(active_astar_grid): return active_astar_grid.cell_size
	return Vector2(32, 32)

func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	if not is_instance_valid(active_astar_grid) or not is_instance_valid(active_building_container):
		push_error("Place building failed: Active scene nodes are not registered.")
		return null

	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return null
	
	if not is_placement_valid(grid_position, building_data.grid_size):
		push_error("Cannot place building at %s: Invalid position." % grid_position)
		return null
	
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	var world_pos_top_left: Vector2 = Vector2(grid_position) * active_astar_grid.cell_size
	var building_footprint_size: Vector2 = Vector2(building_data.grid_size) * active_astar_grid.cell_size
	var building_center_offset: Vector2 = building_footprint_size / 2.0
	new_building.global_position = world_pos_top_left + building_center_offset
	
	active_building_container.add_child(new_building)
	
	if building_data.blocks_pathfinding:
		for x in range(building_data.grid_size.x):
			for y in range(building_data.grid_size.y):
				var cell_pos = grid_position + Vector2i(x, y)
				if _is_cell_within_bounds(cell_pos):
					active_astar_grid.set_point_solid(cell_pos, true)
		
		active_astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_position)

	if is_new_construction:
		new_building.set_state(BaseBuilding.BuildingState.BLUEPRINT)
		
		var entry = {
			"resource_path": building_data.resource_path,
			"grid_position": grid_position,
			"progress": 0
		}
		if current_settlement.pending_construction_buildings == null:
			current_settlement.pending_construction_buildings = []
			
		current_settlement.pending_construction_buildings.append(entry)
		save_settlement() 
		print("SettlementManager: New blueprint placed and saved at %s." % grid_position)
	else:
		new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
		
	return new_building

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	
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
