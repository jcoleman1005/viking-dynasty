# res://autoload/SettlementManager.gd
#
# A global Singleton (Autoload) that acts as a pure data manager
# for the player's current settlement.
# --- MODIFIED: Fixed Type Error in _remove_from_list ---

extends Node

# --- Configuration Constants ---
const BUILDER_EFFICIENCY: int = 25 # Construction progress per worker per year
const GATHERER_EFFICIENCY: int = 10 # Resources produced per worker per year
const BASE_GATHERING_CAPACITY: int = 2

#Define a Save Path
const USER_SAVE_PATH = "user://savegame.tres"

var current_settlement: SettlementData

# --- Scene Registry ---
var active_astar_grid: AStarGrid2D = null
var active_building_container: Node2D = null
var grid_manager_node: Node = null 

# --- Scene Management ---

func register_active_scene_nodes(grid: AStarGrid2D, container: Node2D, manager_node: Node = null) -> void:
	if not is_instance_valid(grid) or not is_instance_valid(container):
		push_error("SettlementManager: Failed to register invalid scene nodes.")
		return
	active_astar_grid = grid
	active_building_container = container
	grid_manager_node = manager_node 
	print("SettlementManager: Active scene nodes registered.")
	
	_trigger_territory_update()

func unregister_active_scene_nodes() -> void:
	active_astar_grid = null
	active_building_container = null
	grid_manager_node = null 
	print("SettlementManager: Active scene nodes unregistered.")

func _trigger_territory_update() -> void:
	if current_settlement and is_instance_valid(grid_manager_node) and grid_manager_node.has_method("recalculate_territory"):
		var all_buildings = current_settlement.placed_buildings + current_settlement.pending_construction_buildings
		grid_manager_node.recalculate_territory(all_buildings)

# --- Settlement Data ---

func load_settlement(data: SettlementData) -> void:
	# 1. Try to load from User Save first (Persistence)
	if ResourceLoader.exists(USER_SAVE_PATH):
		var saved_data = load(USER_SAVE_PATH)
		if saved_data is SettlementData:
			current_settlement = saved_data
			print("SettlementManager: Loaded user save from %s" % USER_SAVE_PATH)
		else:
			_load_fallback_data(data)
	else:
		_load_fallback_data(data)
	
	EventBus.settlement_loaded.emit(current_settlement)
	_trigger_territory_update()

func _load_fallback_data(data: SettlementData) -> void:
	if data:
		# Duplicate data so we don't overwrite the .tres template in memory
		current_settlement = data.duplicate(true)
		print("SettlementManager: Loaded default template.")
	else:
		push_error("SettlementManager: No data provided and no save file found.")

func save_settlement() -> void:
	if not current_settlement: return
	
	# --- FIX: Save to user:// instead of res:// ---
	var error = ResourceSaver.save(current_settlement, USER_SAVE_PATH)
	
	if error == OK:
		var count = current_settlement.pending_construction_buildings.size()
		print("SettlementManager: Saved to %s (Pending: %d)" % [USER_SAVE_PATH, count])
	else:
		push_error("Failed to save to %s. Error code: %s" % [USER_SAVE_PATH, error])

func has_current_settlement() -> bool:
	return current_settlement != null

# --- Treasury & Economy ---
func get_labor_capacities() -> Dictionary:
	"""
	Returns the maximum workers allowed for each category.
	Based on Active Buildings (Gathering) and Blueprints (Construction).
	"""
	var capacities = {
		"construction": 0,
		"food": BASE_GATHERING_CAPACITY,
		"wood": BASE_GATHERING_CAPACITY,
		"stone": BASE_GATHERING_CAPACITY
		# Gold is removed (Raiding only)
	}
	
	if not current_settlement:
		return capacities

	# 1. Gathering Capacity (From Active Buildings)
	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if capacities.has(type):
				capacities[type] += b_data.max_workers
	
	# 2. Construction Capacity (From Blueprints)
	# Limits how many people can crowd around a construction site
	for entry in current_settlement.pending_construction_buildings:
		var b_data = load(entry["resource_path"]) as BuildingData
		if b_data:
			capacities["construction"] += b_data.base_labor_capacity
			
	return capacities

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
	if not current_settlement: return {}

	_process_construction_labor()

	var total_payout: Dictionary = {}
	var stewardship_bonus = 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	# 1. Labor Output (Gold Removed)
	if current_settlement.worker_assignments:
		for resource_type in ["food", "wood", "stone"]: # Gold removed
			var assigned = current_settlement.worker_assignments.get(resource_type, 0)
			if assigned > 0:
				if not total_payout.has(resource_type): total_payout[resource_type] = 0
				var labor_yield = int(assigned * GATHERER_EFFICIENCY * stewardship_bonus)
				total_payout[resource_type] += labor_yield
				print("Labor added %d %s" % [labor_yield, resource_type])

	# 2. Passive Building Output (Gold allowed here, e.g. Markets/Mints)
	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if not total_payout.has(type): total_payout[type] = 0
			total_payout[type] += int(b_data.fixed_payout_amount * stewardship_bonus)

	# 3. Region Income
	if jarl:
		for region_path in jarl.conquered_regions:
			var r_data = load(region_path)
			if r_data:
				for res in r_data.yearly_income:
					if not total_payout.has(res): total_payout[res] = 0
					total_payout[res] += int(r_data.yearly_income[res] * stewardship_bonus)

	# 4. Debuffs
	if jarl and current_settlement.has_stability_debuff:
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

# --- Building Construction Logic ---

func _process_construction_labor() -> void:
	if not current_settlement: return
	
	var assigned_builders = current_settlement.worker_assignments.get("construction", 0)
	if assigned_builders <= 0:
		print("End Year: No builders assigned. Construction stalled.")
		return
		
	var total_labor_points = assigned_builders * BUILDER_EFFICIENCY
	print("End Year: Processing Construction. Available Labor: %d" % total_labor_points)
	
	var completed_indices: Array[int] = []
	
	for i in range(current_settlement.pending_construction_buildings.size()):
		if total_labor_points <= 0:
			break
			
		var entry = current_settlement.pending_construction_buildings[i]
		var building_data = load(entry["resource_path"]) as BuildingData
		
		if not building_data: continue
		
		var current_progress = entry.get("progress", 0)
		var effort_needed = building_data.construction_effort_required
		var effort_remaining = effort_needed - current_progress
		
		var points_to_apply = min(total_labor_points, effort_remaining)
		
		# 1. Update Data
		entry["progress"] = current_progress + points_to_apply
		total_labor_points -= points_to_apply
		
		print("  > Applied %d points to %s (Progress: %d/%d)" % [points_to_apply, building_data.display_name, entry["progress"], effort_needed])
		
		# 2. Update Visuals (LIVE SCENE UPDATE)
		# We must convert the stored position to Vector2i for the lookup
		var grid_pos = Vector2i(entry["grid_position"]) 
		var active_instance = _find_building_instance_at(grid_pos)
		
		if is_instance_valid(active_instance):
			# This triggers the visual state change (Blueprint -> Construction)
			# and updates the health bar/label immediately
			active_instance.add_construction_progress(points_to_apply)
		else:
			print("Warning: Could not find visual instance for building at %s" % grid_pos)
		
		# 3. Check Completion
		if entry["progress"] >= effort_needed:
			print("  >>> Construction COMPLETE: %s" % building_data.display_name)
			completed_indices.append(i)
			
			var new_placed_entry = {
				"resource_path": entry["resource_path"],
				"grid_position": entry["grid_position"]
			}
			current_settlement.placed_buildings.append(new_placed_entry)
	
	completed_indices.sort()
	completed_indices.reverse()
	for i in completed_indices:
		current_settlement.pending_construction_buildings.remove_at(i)
		
	save_settlement()
	
	# If anything completed, we might need to reload/refresh territory
	if not completed_indices.is_empty():
		_trigger_territory_update()

# --- NEW HELPER ---
func _find_building_instance_at(grid_pos: Vector2i) -> BaseBuilding:
	"""Finds the actual node in the scene for a given grid position."""
	if not is_instance_valid(active_building_container):
		return null
		
	# Convert grid pos to world pos logic to match building positions?
	# Actually, simpler: Iterate children and check their data.
	# Since we don't have a dictionary map of instances, we loop.
	# Optimization: Maintain a lookup dict in the future if building count > 100.
	
	var cell_size = get_active_grid_cell_size()
	
	for child in active_building_container.get_children():
		if child is BaseBuilding:
			# Reverse engineer the grid pos from global pos
			var size_offset = Vector2(child.data.grid_size) * cell_size / 2.0
			var top_left = child.global_position - size_offset
			var child_grid_pos = Vector2i(round(top_left.x / cell_size.x), round(top_left.y / cell_size.y))
			
			if child_grid_pos == grid_pos:
				return child
	return null
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
		_trigger_territory_update()
	else:
		push_warning("SettlementManager: Could not find data entry for building at %s" % grid_pos)

	building_instance.queue_free()

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry = list[i]
		var entry_pos = entry["grid_position"]
		
		# Explicitly cast entry to Vector2i for safe comparison
		var current_pos_i: Vector2i
		
		if entry_pos is Vector2:
			current_pos_i = Vector2i(entry_pos)
		elif entry_pos is Vector2i:
			current_pos_i = entry_pos
		else:
			continue 
			
		if current_pos_i == grid_pos:
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
	
	_trigger_territory_update()
		
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
# --- Phase 4.1: The Prediction Engine ---

func simulate_turn(simulated_assignments: Dictionary) -> Dictionary:
	if not current_settlement: return {}

	var result = {
		"resources_gained": { "food": 0, "wood": 0, "stone": 0, "gold": 0 },
		"buildings_completing": []
	}

	# 1. Simulate Construction
	var assigned_builders = simulated_assignments.get("construction", 0)
	var total_points = assigned_builders * BUILDER_EFFICIENCY
	
	for entry in current_settlement.pending_construction_buildings:
		if total_points <= 0: break
		var b_data = load(entry["resource_path"]) as BuildingData
		if not b_data: continue
		
		var needed = b_data.construction_effort_required - entry.get("progress", 0)
		var applied = min(total_points, needed)
		total_points -= applied
		
		if (entry.get("progress", 0) + applied) >= b_data.construction_effort_required:
			result["buildings_completing"].append(b_data.display_name)

	# 2. Simulate Economy
	var stewardship_bonus = 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05

	# Labor (Gold Removed)
	for res in ["food", "wood", "stone"]:
		var count = simulated_assignments.get(res, 0)
		if count > 0:
			result["resources_gained"][res] += int(count * GATHERER_EFFICIENCY * stewardship_bonus)

	# Passive Buildings & Regions (Keep Gold)
	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			result["resources_gained"][b_data.resource_type] += int(b_data.fixed_payout_amount * stewardship_bonus)
			
	if jarl:
		for path in jarl.conquered_regions:
			var r_data = load(path)
			if r_data:
				for res in r_data.yearly_income:
					result["resources_gained"][res] += int(r_data.yearly_income[res] * stewardship_bonus)

	return result
