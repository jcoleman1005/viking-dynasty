# res://autoload/SettlementManager.gd
extends Node

const BUILDER_EFFICIENCY: int = 25
const GATHERER_EFFICIENCY: int = 10
const BASE_GATHERING_CAPACITY: int = 2
const USER_SAVE_PATH := "user://savegame.tres"
const MAP_SAVE_PATH := "user://campaign_map.tres"

var current_settlement: SettlementData
var active_astar_grid: AStarGrid2D = null
var active_building_container: Node2D = null
var grid_manager_node: Node = null 

func _ready() -> void:
	EventBus.player_unit_died.connect(_on_player_unit_died)

# --- SAVE MANAGEMENT ---

func delete_save_file() -> void:
	var settlement_deleted := false
	var map_deleted := false
	
	if FileAccess.file_exists(USER_SAVE_PATH):
		if DirAccess.remove_absolute(USER_SAVE_PATH) == OK: settlement_deleted = true
	
	if FileAccess.file_exists(MAP_SAVE_PATH):
		if DirAccess.remove_absolute(MAP_SAVE_PATH) == OK: map_deleted = true
	
	reset_manager_state()
	Loggie.msg("Save files deleted (Settlement: %s, Map: %s)." % [settlement_deleted, map_deleted]).domain("SYSTEM").info()

func reset_manager_state() -> void:
	current_settlement = null
	active_astar_grid = null
	active_building_container = null
	grid_manager_node = null

func register_active_scene_nodes(grid: AStarGrid2D, container: Node2D, manager_node: Node = null) -> void:
	if not is_instance_valid(grid) or not is_instance_valid(container): return
	active_astar_grid = grid
	active_building_container = container
	grid_manager_node = manager_node 
	_trigger_territory_update()

func unregister_active_scene_nodes() -> void:
	active_astar_grid = null
	active_building_container = null
	grid_manager_node = null 

func _trigger_territory_update() -> void:
	if current_settlement and is_instance_valid(grid_manager_node) and grid_manager_node.has_method("recalculate_territory"):
		var all_buildings = current_settlement.placed_buildings + current_settlement.pending_construction_buildings
		grid_manager_node.recalculate_territory(all_buildings)

# --- WARBAND MANAGEMENT ---

func _on_player_unit_died(unit: Node2D) -> void:
	if not current_settlement: return
	
	var base_unit = unit as BaseUnit
	# Safety check: ensure it's a tracked unit
	if not base_unit or not base_unit.warband_ref:
		return 

	var warband = base_unit.warband_ref
	
	# Check if this warband is actually in our roster
	if warband in current_settlement.warbands:
		
		# --- LOGIC CHANGE: Casualty vs Wipe ---
		warband.current_manpower -= 1
		
		if warband.current_manpower <= 0:
			# Total Wipeout
			current_settlement.warbands.erase(warband)
			Loggie.msg("☠️ Warband Destroyed: %s" % warband.custom_name).domain("SETTLEMENT").warn()
		else:
			# Just a casualty
			Loggie.msg("⚔️ Casualty in %s. Remaining: %d" % [warband.custom_name, warband.current_manpower]).domain("SETTLEMENT").info()
		
		# Always save state immediately
		save_settlement()

func recruit_unit(unit_data: UnitData) -> void:
	if not current_settlement or not unit_data: return
	
	var new_warband = WarbandData.new(unit_data)
	current_settlement.warbands.append(new_warband)
	
	Loggie.msg("Recruited new Warband: %s" % new_warband.custom_name).domain("SETTLEMENT").info()
	save_settlement()
	EventBus.purchase_successful.emit(unit_data.display_name)

# --- LOAD/SAVE ---

func load_settlement(data: SettlementData) -> void:
	if ResourceLoader.exists(USER_SAVE_PATH):
		var saved_data = load(USER_SAVE_PATH)
		if saved_data is SettlementData:
			current_settlement = saved_data
			Loggie.msg("Loaded user save from %s" % USER_SAVE_PATH).domain("SETTLEMENT").info()
		else:
			_load_fallback_data(data)
	else:
		_load_fallback_data(data)
	
	EventBus.settlement_loaded.emit(current_settlement)
	_trigger_territory_update()

func _load_fallback_data(data: SettlementData) -> void:
	if data:
		current_settlement = data.duplicate(true)
		if current_settlement.warbands == null:
			current_settlement.warbands = []
		_migrate_legacy_properties()
		Loggie.msg("Loaded default template.").domain("SETTLEMENT").info()
	else:
		Loggie.msg("No data provided and no save file found.").domain("SETTLEMENT").error()

func _migrate_legacy_properties() -> void:
	"""Migrates old settlement data properties to new format."""
	if not current_settlement:
		return
	
	# Safely migrate 'garrisoned_units' to 'warbands' if it exists
	if "garrisoned_units" in current_settlement:
		var legacy_units = current_settlement.get("garrisoned_units")
		if legacy_units is Dictionary and not legacy_units.is_empty():
			# Convert old dictionary format to new warband array
			for unit_type in legacy_units:
				var count = legacy_units[unit_type] as int
				for i in range(count):
					# Try to find matching unit data
					var unit_path = "res://data/units/Unit_PlayerRaider.tres"
					if ResourceLoader.exists(unit_path):
						var unit_data = load(unit_path) as UnitData
						if unit_data:
							var warband = WarbandData.new(unit_data)
							current_settlement.warbands.append(warband)
		
		# Remove the old property
		if current_settlement.has_method("remove_meta"):
			current_settlement.remove_meta("garrisoned_units")
		
		Loggie.msg("Migrated %d legacy units to warband format." % current_settlement.warbands.size()).domain("SETTLEMENT").info()
	
	# Ensure other required properties exist
	if not "population_total" in current_settlement:
		current_settlement.population_total = 10
	
	if not "worker_assignments" in current_settlement:
		current_settlement.worker_assignments = {
			"construction": 0,
			"food": 0,
			"wood": 0,
			"stone": 0,
			"gold": 0
		}

func save_settlement() -> void:
	if not current_settlement: return
	var error = ResourceSaver.save(current_settlement, USER_SAVE_PATH)
	if error != OK:
		Loggie.msg("Failed to save to %s. Error code: %s" % [USER_SAVE_PATH, error]).domain("SETTLEMENT").error()

func has_current_settlement() -> bool:
	return current_settlement != null

# --- ECONOMY (UNCHANGED) ---

func get_labor_capacities() -> Dictionary:
	var capacities = { "construction": 0, "food": BASE_GATHERING_CAPACITY, "wood": BASE_GATHERING_CAPACITY, "stone": BASE_GATHERING_CAPACITY }
	if not current_settlement: return capacities

	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			if capacities.has(b_data.resource_type):
				capacities[b_data.resource_type] += b_data.max_workers
	
	for entry in current_settlement.pending_construction_buildings:
		var b_data = load(entry["resource_path"]) as BuildingData
		if b_data: capacities["construction"] += b_data.base_labor_capacity
			
	return capacities

func deposit_resources(loot: Dictionary) -> void:
	if not current_settlement: return
	
	for resource_type in loot:
		# --- NEW: Skip special keys ---
		if resource_type.begins_with("_"): continue
		# ------------------------------
		
		var amount = loot[resource_type]
		if resource_type == "population":
			if not "population_total" in current_settlement: current_settlement.population_total = 10
			current_settlement.population_total += amount
		elif current_settlement.treasury.has(resource_type):
			current_settlement.treasury[resource_type] += amount
		else:
			current_settlement.treasury[resource_type] = amount
			
	EventBus.treasury_updated.emit(current_settlement.treasury)
	save_settlement()

func attempt_purchase(item_cost: Dictionary) -> bool:
	if not current_settlement: return false
	for res in item_cost:
		if not current_settlement.treasury.has(res) or current_settlement.treasury[res] < item_cost[res]:
			EventBus.purchase_failed.emit("Insufficient %s" % res)
			return false
	for res in item_cost:
		current_settlement.treasury[res] -= item_cost[res]
	EventBus.treasury_updated.emit(current_settlement.treasury)
	return true

func calculate_payout() -> Dictionary:
	if not current_settlement: return {}
	_process_construction_labor()
	
	var total_payout: Dictionary = {}
	var stewardship_bonus := 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	if current_settlement.worker_assignments:
		for res in ["food", "wood", "stone"]:
			var assigned: int = current_settlement.worker_assignments.get(res, 0)
			if assigned > 0:
				if not total_payout.has(res): total_payout[res] = 0
				total_payout[res] += int(assigned * GATHERER_EFFICIENCY * stewardship_bonus)

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
		if total_payout.has("gold"): total_payout["gold"] = int(total_payout["gold"] * 0.75)
		current_settlement.has_stability_debuff = false
		save_settlement()
	var hunger_warnings = _process_warband_hunger()
	if not hunger_warnings.is_empty():
		# Store messages in a special key starting with underscore
		total_payout["_messages"] = hunger_warnings
		
	return total_payout

# --- CONSTRUCTION (UNCHANGED) ---

func get_active_grid_cell_size() -> Vector2:
	if is_instance_valid(active_astar_grid): return active_astar_grid.cell_size
	return Vector2(32, 32)

func _process_construction_labor() -> void:
	if not current_settlement: return
	var assigned = current_settlement.worker_assignments.get("construction", 0)
	if assigned <= 0: return
		
	var total_points = assigned * BUILDER_EFFICIENCY
	var completed_indices: Array[int] = []
	
	for i in range(current_settlement.pending_construction_buildings.size()):
		if total_points <= 0: break
		var entry = current_settlement.pending_construction_buildings[i]
		var b_data = load(entry["resource_path"]) as BuildingData
		if not b_data: continue
		
		var needed = b_data.construction_effort_required - entry.get("progress", 0)
		var applied = min(total_points, needed)
		entry["progress"] += applied
		total_points -= applied
		
		if entry["progress"] >= b_data.construction_effort_required:
			completed_indices.append(i)
			current_settlement.placed_buildings.append({
				"resource_path": entry["resource_path"],
				"grid_position": entry["grid_position"]
			})
	
	completed_indices.sort()
	completed_indices.reverse()
	for i in completed_indices:
		current_settlement.pending_construction_buildings.remove_at(i)
		
	save_settlement()
	if not completed_indices.is_empty(): _trigger_territory_update()

func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	if not is_instance_valid(active_building_container): return null
	if not is_placement_valid(grid_position, building_data.grid_size, building_data): return null
	
	var new_building = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	var cell = get_active_grid_cell_size()
	var pos = Vector2(grid_position) * cell + (Vector2(building_data.grid_size) * cell / 2.0)
	new_building.global_position = pos
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
		current_settlement.pending_construction_buildings.append({
			"resource_path": building_data.resource_path,
			"grid_position": grid_position,
			"progress": 0
		})
		save_settlement()
		Loggie.msg("New blueprint placed at %s." % grid_position).domain("SETTLEMENT").info()
	else:
		new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
	
	_trigger_territory_update()
	return new_building

func remove_building(building_instance: BaseBuilding) -> void:
	if not current_settlement or not is_instance_valid(building_instance): return
	var cell_size = get_active_grid_cell_size()
	var grid_pos = Vector2i((building_instance.global_position - (Vector2(building_instance.data.grid_size) * cell_size / 2.0)) / cell_size)
	
	if is_instance_valid(active_astar_grid):
		for x in range(building_instance.data.grid_size.x):
			for y in range(building_instance.data.grid_size.y):
				var cell = grid_pos + Vector2i(x, y)
				if _is_cell_within_bounds(cell):
					active_astar_grid.set_point_solid(cell, false)
		active_astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_pos)

	var removed = _remove_from_list(current_settlement.placed_buildings, grid_pos)
	if not removed: removed = _remove_from_list(current_settlement.pending_construction_buildings, grid_pos)
	if removed:
		save_settlement()
		_trigger_territory_update()
	building_instance.queue_free()

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry_pos = list[i]["grid_position"]
		var current_pos_i = Vector2i(entry_pos) if (entry_pos is Vector2 or entry_pos is Vector2i) else Vector2i.ZERO
		if current_pos_i == grid_pos:
			list.remove_at(i)
			return true
	return false

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell_pos = grid_position + Vector2i(x, y)
			if not _is_cell_within_bounds(cell_pos) or active_astar_grid.is_point_solid(cell_pos): return false
	if building_data and building_data is EconomicBuildingData:
		return _is_within_district_range(grid_position, building_size, building_data)
	return true

func _is_within_district_range(grid_pos: Vector2i, size: Vector2i, data: EconomicBuildingData) -> bool:
	var cell = get_active_grid_cell_size()
	var center = (Vector2(grid_pos) * cell) + (Vector2(size) * cell / 2.0)
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	for node in nodes:
		if node is ResourceNode and node.resource_type == data.resource_type:
			if node.is_position_in_district(center) and not node.is_depleted(): return true
	return false

func _is_cell_within_bounds(grid_position: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	var bounds = active_astar_grid.region
	return grid_position.x >= bounds.position.x and grid_position.x < bounds.end.x and grid_position.y >= bounds.position.y and grid_position.y < bounds.end.y

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid): return PackedVector2Array()
	var start = Vector2i(start_pos / active_astar_grid.cell_size)
	var end = Vector2i(end_pos / active_astar_grid.cell_size)
	if not _is_cell_within_bounds(start): return PackedVector2Array()
	return active_astar_grid.get_point_path(start, end, allow_partial_path)

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_position):
		active_astar_grid.set_point_solid(grid_position, solid)

func simulate_turn(simulated_assignments: Dictionary) -> Dictionary:
	if not current_settlement: return {}
	var result = { "resources_gained": { "food": 0, "wood": 0, "stone": 0, "gold": 0 }, "buildings_completing": [] }
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
		if count > 0: result["resources_gained"][res] += int(count * GATHERER_EFFICIENCY * stewardship_bonus)

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
	if not current_settlement: return {}
	var report = { "gold_lost": 0, "wood_lost": 0, "buildings_damaged": 0, "buildings_destroyed": 0 }
	var loss_ratio = randf_range(0.2, 0.4)
	
	var g_loss = int(current_settlement.treasury.get("gold", 0) * loss_ratio)
	current_settlement.treasury["gold"] -= g_loss
	report["gold_lost"] = g_loss
	
	var w_loss = int(current_settlement.treasury.get("wood", 0) * loss_ratio)
	current_settlement.treasury["wood"] -= w_loss
	report["wood_lost"] = w_loss
	
	var indices_to_remove: Array[int] = []
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		if entry.get("progress", 0) > 0:
			entry["progress"] -= randi_range(50, 150)
			report["buildings_damaged"] += 1
			if entry["progress"] <= 0:
				indices_to_remove.append(i)
				report["buildings_destroyed"] += 1
	
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for i in indices_to_remove: current_settlement.pending_construction_buildings.remove_at(i)
		
	current_settlement.has_stability_debuff = true
	save_settlement()
	EventBus.treasury_updated.emit(current_settlement.treasury)
	return report

func _process_warband_hunger() -> Array[String]:
	if not current_settlement: return []
	
	var deserters: Array[WarbandData] = []
	var warnings: Array[String] = []
	
	for warband in current_settlement.warbands:
		var old_loyalty = warband.loyalty
		
		# 1. Decay Loyalty
		var decay = 25
		warband.modify_loyalty(-decay)
		warband.turns_idle += 1
		
		# 2. Generate Warnings based on NEW loyalty
		if warband.loyalty <= 0:
			if randf() < 0.5:
				deserters.append(warband)
				warnings.append("[color=red]DESERTION: The %s have left your service![/color]" % warband.custom_name)
				Loggie.msg("The %s have betrayed you and left!" % warband.custom_name).domain("SETTLEMENT").warn()
			else:
				warnings.append("[color=red]MUTINY: The %s refuse to obey! Raid immediately![/color]" % warband.custom_name)
				Loggie.msg("The %s are openly mutinous!" % warband.custom_name).domain("SETTLEMENT").warn()
				
		elif warband.loyalty <= 25:
			warnings.append("[color=yellow]UNREST: The %s are growing restless (%d%% Loyalty).[/color]" % [warband.custom_name, warband.loyalty])
			Loggie.msg("The %s are losing faith in your leadership." % warband.custom_name).domain("SETTLEMENT").info()
			
	# Remove deserters
	for bad_apple in deserters:
		current_settlement.warbands.erase(bad_apple)
		
	if not deserters.is_empty() or not warnings.is_empty():
		save_settlement()
		
	return warnings
