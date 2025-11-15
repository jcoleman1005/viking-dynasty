# res://autoload/SettlementManager.gd
extends Node

const BUILDER_EFFICIENCY: int = 25
const GATHERER_EFFICIENCY: int = 10
const BASE_GATHERING_CAPACITY: int = 2
const USER_SAVE_PATH = "user://savegame.tres"
# --- NEW: Map Save Path ---
const MAP_SAVE_PATH = "user://campaign_map.tres"
# --------------------------

var current_settlement: SettlementData
var active_astar_grid: AStarGrid2D = null
var active_building_container: Node2D = null
var grid_manager_node: Node = null 

func _ready() -> void:
	# Listen for permanent unit loss
	EventBus.player_unit_died.connect(_on_player_unit_died)

# --- MODIFIED: Save Management Helper ---
func delete_save_file() -> void:
	"""Deletes existing save files (Settlement & Map) to force a new game state."""
	var settlement_deleted = false
	var map_deleted = false
	
	# 1. Delete Settlement Save
	if FileAccess.file_exists(USER_SAVE_PATH):
		var error = DirAccess.remove_absolute(USER_SAVE_PATH)
		if error == OK:
			settlement_deleted = true
		else:
			Loggie.msg("SettlementManager: Failed to delete settlement save. Error: %s" % error).domain(LogDomains.SYSTEM).error()
	
	# 2. Delete Map Save
	if FileAccess.file_exists(MAP_SAVE_PATH):
		var error = DirAccess.remove_absolute(MAP_SAVE_PATH)
		if error == OK:
			map_deleted = true
		else:
			Loggie.msg("SettlementManager: Failed to delete map save. Error: %s" % error).domain(LogDomains.SYSTEM).error()
			
	if settlement_deleted or map_deleted:
		Loggie.msg("SettlementManager: Save files deleted (Settlement: %s, Map: %s). Starting fresh." % [settlement_deleted, map_deleted]).domain(LogDomains.SYSTEM).info()
	else:
		Loggie.msg("SettlementManager: No save files found to delete.").domain(LogDomains.SYSTEM).info()
# -----------------------------------

func register_active_scene_nodes(grid: AStarGrid2D, container: Node2D, manager_node: Node = null) -> void:
	if not is_instance_valid(grid) or not is_instance_valid(container):
		Loggie.msg("Failed to register invalid scene nodes.").domain(LogDomains.SETTLEMENT).error()
		return
	active_astar_grid = grid
	active_building_container = container
	grid_manager_node = manager_node 
	Loggie.msg("Active scene nodes registered.").domain(LogDomains.SETTLEMENT).info()
	_trigger_territory_update()

func unregister_active_scene_nodes() -> void:
	active_astar_grid = null
	active_building_container = null
	grid_manager_node = null 
	Loggie.msg("Active scene nodes unregistered.").domain(LogDomains.SETTLEMENT).info()

func _trigger_territory_update() -> void:
	if current_settlement and is_instance_valid(grid_manager_node) and grid_manager_node.has_method("recalculate_territory"):
		var all_buildings = current_settlement.placed_buildings + current_settlement.pending_construction_buildings
		grid_manager_node.recalculate_territory(all_buildings)

func _on_player_unit_died(unit: Node2D) -> void:
	"""
	Removes a destroyed unit from the settlement's garrison.
	Called automatically by EventBus when a PlayerVikingRaider dies.
	"""
	if not current_settlement: return
	
	var base_unit = unit as BaseUnit
	if not base_unit or not base_unit.data:
		return
		
	var unit_path = base_unit.data.resource_path
	if unit_path.is_empty():
		Loggie.msg("Unit died but has no valid resource_path. Cannot update garrison.").domain(LogDomains.SETTLEMENT).warn()
		return
		
	if current_settlement.garrisoned_units.has(unit_path):
		var count = current_settlement.garrisoned_units[unit_path]
		
		if count > 0:
			current_settlement.garrisoned_units[unit_path] = count - 1
			
			if current_settlement.garrisoned_units[unit_path] <= 0:
				current_settlement.garrisoned_units.erase(unit_path)
			
			Loggie.msg("⚔️ Unit PERMANENTLY lost: %s (Remaining: %d)" % [base_unit.data.display_name, count - 1]).domain(LogDomains.SETTLEMENT).info()
			
			save_settlement()
	else:
		Loggie.msg("Unit %s died, but was not found in garrison records (Mercenary/Event unit?)" % base_unit.data.display_name).domain(LogDomains.SETTLEMENT).debug()

# --- Settlement Data ---

func load_settlement(data: SettlementData) -> void:
	if ResourceLoader.exists(USER_SAVE_PATH):
		var saved_data = load(USER_SAVE_PATH)
		if saved_data is SettlementData:
			current_settlement = saved_data
			Loggie.msg("Loaded user save from %s" % USER_SAVE_PATH).domain(LogDomains.SETTLEMENT).info()
		else:
			_load_fallback_data(data)
	else:
		_load_fallback_data(data)
	
	EventBus.settlement_loaded.emit(current_settlement)
	_trigger_territory_update()

func _load_fallback_data(data: SettlementData) -> void:
	if data:
		current_settlement = data.duplicate(true)
		Loggie.msg("Loaded default template.").domain(LogDomains.SETTLEMENT).info()
	else:
		Loggie.msg("No data provided and no save file found.").domain(LogDomains.SETTLEMENT).error()

func save_settlement() -> void:
	if not current_settlement: return
	
	var error = ResourceSaver.save(current_settlement, USER_SAVE_PATH)
	if error == OK:
		var count = current_settlement.pending_construction_buildings.size()
		Loggie.msg("Saved to %s (Pending: %d)" % [USER_SAVE_PATH, count]).domain(LogDomains.SETTLEMENT).info()
	else:
		Loggie.msg("Failed to save to %s. Error code: %s" % [USER_SAVE_PATH, error]).domain(LogDomains.SETTLEMENT).error()

func has_current_settlement() -> bool:
	return current_settlement != null

# --- Treasury & Economy ---
func get_labor_capacities() -> Dictionary:
	var capacities = {
		"construction": 0,
		"food": BASE_GATHERING_CAPACITY,
		"wood": BASE_GATHERING_CAPACITY,
		"stone": BASE_GATHERING_CAPACITY
	}
	if not current_settlement: return capacities

	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if capacities.has(type):
				capacities[type] += b_data.max_workers
	
	for entry in current_settlement.pending_construction_buildings:
		var b_data = load(entry["resource_path"]) as BuildingData
		if b_data:
			capacities["construction"] += b_data.base_labor_capacity
			
	return capacities

func deposit_resources(loot: Dictionary) -> void:
	if not current_settlement: return
	
	for resource_type in loot:
		var amount = loot[resource_type]
		if resource_type == "population":
			if not "population_total" in current_settlement:
				current_settlement.population_total = 10
			current_settlement.population_total += amount
			Loggie.msg("Acquired %d new thralls. Total Pop: %d" % [amount, current_settlement.population_total]).domain(LogDomains.SETTLEMENT).info()
		elif current_settlement.treasury.has(resource_type):
			current_settlement.treasury[resource_type] += amount
		else:
			current_settlement.treasury[resource_type] = amount
			
	EventBus.treasury_updated.emit(current_settlement.treasury)
	save_settlement()

func attempt_purchase(item_cost: Dictionary) -> bool:
	if not current_settlement: return false
	
	for resource_type in item_cost:
		if not current_settlement.treasury.has(resource_type) or \
		current_settlement.treasury[resource_type] < item_cost[resource_type]:
			var reason = "Insufficient %s" % resource_type
			Loggie.msg("Purchase failed. %s." % reason).domain(LogDomains.SETTLEMENT).warn()
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

	if current_settlement.worker_assignments:
		for resource_type in ["food", "wood", "stone"]:
			var assigned = current_settlement.worker_assignments.get(resource_type, 0)
			if assigned > 0:
				if not total_payout.has(resource_type): total_payout[resource_type] = 0
				var labor_yield = int(assigned * GATHERER_EFFICIENCY * stewardship_bonus)
				total_payout[resource_type] += labor_yield
				Loggie.msg("Labor added %d %s" % [labor_yield, resource_type]).domain(LogDomains.SETTLEMENT).info()

	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if not total_payout.has(type): total_payout[type] = 0
			total_payout[type] += int(b_data.fixed_payout_amount * stewardship_bonus)

	if jarl:
		for region_path in jarl.conquered_regions:
			var r_data = load(region_path)
			if r_data:
				for res in r_data.yearly_income:
					if not total_payout.has(res): total_payout[res] = 0
					total_payout[res] += int(r_data.yearly_income[res] * stewardship_bonus)

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
	
	Loggie.msg("Recruited %s." % unit_data.display_name).domain(LogDomains.SETTLEMENT).info()
	save_settlement()
	EventBus.purchase_successful.emit(unit_data.display_name)

func _process_construction_labor() -> void:
	if not current_settlement: return
	
	var assigned_builders = current_settlement.worker_assignments.get("construction", 0)
	if assigned_builders <= 0:
		Loggie.msg("End Year: No builders assigned. Construction stalled.").domain(LogDomains.SETTLEMENT).warn()
		return
		
	var total_labor_points = assigned_builders * BUILDER_EFFICIENCY
	Loggie.msg("End Year: Processing Construction. Available Labor: %d" % total_labor_points).domain(LogDomains.SETTLEMENT).info()
	
	var completed_indices: Array[int] = []
	
	for i in range(current_settlement.pending_construction_buildings.size()):
		if total_labor_points <= 0: break
			
		var entry = current_settlement.pending_construction_buildings[i]
		var building_data = load(entry["resource_path"]) as BuildingData
		if not building_data: continue
		
		var current_progress = entry.get("progress", 0)
		var effort_needed = building_data.construction_effort_required
		var effort_remaining = effort_needed - current_progress
		var points_to_apply = min(total_labor_points, effort_remaining)
		
		entry["progress"] = current_progress + points_to_apply
		total_labor_points -= points_to_apply
		
		Loggie.msg(" > Applied %d points to %s (Progress: %d/%d)" % [points_to_apply, building_data.display_name, entry["progress"], effort_needed]).domain(LogDomains.SETTLEMENT).debug()
		
		var grid_pos = Vector2i(entry["grid_position"]) 
		var active_instance = _find_building_instance_at(grid_pos)
		if is_instance_valid(active_instance):
			active_instance.add_construction_progress(points_to_apply)
		else:
			Loggie.msg("Warning: Could not find visual instance for building at %s" % grid_pos).domain(LogDomains.SETTLEMENT).warn()
		
		if entry["progress"] >= effort_needed:
			Loggie.msg(" >>> Construction COMPLETE: %s" % building_data.display_name).domain(LogDomains.SETTLEMENT).info()
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
	if not completed_indices.is_empty():
		_trigger_territory_update()

func _find_building_instance_at(grid_pos: Vector2i) -> BaseBuilding:
	if not is_instance_valid(active_building_container): return null
	var cell_size = get_active_grid_cell_size()
	for child in active_building_container.get_children():
		if child is BaseBuilding:
			var size_offset = Vector2(child.data.grid_size) * cell_size / 2.0
			var top_left = child.global_position - size_offset
			var child_grid_pos = Vector2i(round(top_left.x / cell_size.x), round(top_left.y / cell_size.y))
			if child_grid_pos == grid_pos:
				return child
	return null

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
		Loggie.msg("Removed %s from data at %s." % [building_instance.data.display_name, grid_pos]).domain(LogDomains.SETTLEMENT).info()
		_trigger_territory_update()
	else:
		Loggie.msg("Could not find data entry for building at %s" % grid_pos).domain(LogDomains.SETTLEMENT).warn()

	building_instance.queue_free()

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry = list[i]
		var entry_pos = entry["grid_position"]
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
		Loggie.msg("Place building failed: Active scene nodes are not registered.").domain(LogDomains.SETTLEMENT).error()
		return null

	if not building_data or not building_data.scene_to_spawn:
		Loggie.msg("Build request failed: BuildingData or scene_to_spawn is null.").domain(LogDomains.SETTLEMENT).error()
		return null
	
	if not is_placement_valid(grid_position, building_data.grid_size):
		Loggie.msg("Cannot place building at %s: Invalid position." % grid_position).domain(LogDomains.SETTLEMENT).error()
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
		Loggie.msg("New blueprint placed and saved at %s." % grid_position).domain(LogDomains.SETTLEMENT).info()
	else:
		new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
	
	_trigger_territory_update()
	return new_building

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	
	# 1. Standard Grid/Collision Checks
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell_pos = grid_position + Vector2i(x, y)
			if not _is_cell_within_bounds(cell_pos): return false
			if active_astar_grid.is_point_solid(cell_pos): return false
	
	# 2. District Constraint Check (NEW)
	if building_data and building_data is EconomicBuildingData:
		if not _is_within_district_range(grid_position, building_size, building_data):
			return false
			
	return true

# Helper to check distance against all nodes
func _is_within_district_range(grid_pos: Vector2i, size: Vector2i, data: EconomicBuildingData) -> bool:
	var cell_size = get_active_grid_cell_size()
	
	# Calculate center of the proposed building in World Space
	var building_world_pos = Vector2(grid_pos) * cell_size
	var building_center = building_world_pos + (Vector2(size) * cell_size / 2.0)
	
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	
	for node in nodes:
		if node is ResourceNode and node.resource_type == data.resource_type:
			# Check 1: Is it close enough?
			if node.is_position_in_district(building_center):
				# Check 2: Is the resource still alive?
				if not node.is_depleted():
					return true
	
	return false

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

func simulate_turn(simulated_assignments: Dictionary) -> Dictionary:
	if not current_settlement: return {}
	var result = {
		"resources_gained": { "food": 0, "wood": 0, "stone": 0, "gold": 0 },
		"buildings_completing": []
	}
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

	var stewardship_bonus = 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05

	for res in ["food", "wood", "stone"]:
		var count = simulated_assignments.get(res, 0)
		if count > 0:
			result["resources_gained"][res] += int(count * GATHERER_EFFICIENCY * stewardship_bonus)

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

func apply_raid_damages() -> Dictionary:
	"""
	Calculates and applies material losses from a successful enemy raid.
	Returns a dictionary of losses for display.
	"""
	if not current_settlement: return {}
	
	var report = {
		"gold_lost": 0,
		"wood_lost": 0,
		"buildings_damaged": 0,
		"buildings_destroyed": 0
	}
	
	# 1. Resource Plundering (Lose 20-40% of Gold and Wood)
	var loss_ratio = randf_range(0.2, 0.4)
	
	var current_gold = current_settlement.treasury.get("gold", 0)
	var gold_loss = int(current_gold * loss_ratio)
	current_settlement.treasury["gold"] = max(0, current_gold - gold_loss)
	report["gold_lost"] = gold_loss
	
	var current_wood = current_settlement.treasury.get("wood", 0)
	var wood_loss = int(current_wood * loss_ratio)
	current_settlement.treasury["wood"] = max(0, current_wood - wood_loss)
	report["wood_lost"] = wood_loss
	
	# 2. Construction Setbacks (Damage pending blueprints)
	var indices_to_remove = []
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		var damage = randi_range(50, 150) # Setback amount
		
		if entry.get("progress", 0) > 0:
			entry["progress"] -= damage
			report["buildings_damaged"] += 1
			
			if entry["progress"] <= 0:
				indices_to_remove.append(i)
				report["buildings_destroyed"] += 1
	
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for i in indices_to_remove:
		current_settlement.pending_construction_buildings.remove_at(i)
		
	# 3. Apply Stability Debuff
	current_settlement.has_stability_debuff = true
	
	save_settlement()
	EventBus.treasury_updated.emit(current_settlement.treasury)
	
	return report
