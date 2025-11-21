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
var pending_management_open: bool = false

func _ready() -> void:
	EventBus.player_unit_died.connect(_on_player_unit_died)

# --- POPULATION GETTERS (FIXED) ---

func get_idle_peasants() -> int:
	if not current_settlement: return 0
	var employed = 0
	
	# Count Active
	for entry in current_settlement.placed_buildings:
		employed += entry.get("peasant_count", 0)
		
	# Count Builders
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("peasant_count", 0)
	
	# FIX: Use population_peasants
	return current_settlement.population_peasants - employed

func get_idle_thralls() -> int:
	if not current_settlement: return 0
	var employed = 0
	for entry in current_settlement.placed_buildings:
		employed += entry.get("thrall_count", 0)
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("thrall_count", 0)
	
	return current_settlement.population_thralls - employed

# --- ASSIGNMENT LOGIC ---

func assign_construction_worker(index: int, type: String, amount: int) -> void:
	if not current_settlement: return
	var entry = current_settlement.pending_construction_buildings[index]
	var data = load(entry["resource_path"]) as BuildingData
	if not data: return
	
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.base_labor_capacity 
	var current = entry.get(key, 0)
	
	var new_val = current + amount
	if new_val < 0: new_val = 0
	if new_val > cap: new_val = cap
	
	if amount > 0:
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
		if amount > idle:
			EventBus.purchase_failed.emit("Not enough %ss!" % type.capitalize())
			return
			
	entry[key] = new_val
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

func assign_worker(building_index: int, type: String, amount: int) -> void:
	if not current_settlement: return
	var entry = current_settlement.placed_buildings[building_index]
	var data = load(entry["resource_path"]) as EconomicBuildingData
	if not data: return
	
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.peasant_capacity if type == "peasant" else data.thrall_capacity
	var current = entry.get(key, 0)
	
	var new_val = current + amount
	if new_val < 0: new_val = 0
	if new_val > cap: new_val = cap
	
	if amount > 0:
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
		if amount > idle:
			EventBus.purchase_failed.emit("Not enough idle %ss!" % type.capitalize())
			return
			
	entry[key] = new_val
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

# --- RECRUITMENT (DRAFTING) ---

func recruit_unit(unit_data: UnitData) -> void:
	if not current_settlement or not unit_data: return
	
	# Drafting Cost
	var population_cost = 10
	var idle_peasants = get_idle_peasants()
	
	if idle_peasants < population_cost:
		EventBus.purchase_failed.emit("Not enough idle Citizens! (Need %d)" % population_cost)
		return
		
	# FIX: Update peasant count
	current_settlement.population_peasants -= population_cost
	
	var new_warband = WarbandData.new(unit_data)
	if DynastyManager.has_purchased_upgrade("UPG_TRAINING_GROUNDS"):
		new_warband.experience = 200
		new_warband.add_history("Recruited as Hardened Veterans")
	else:
		new_warband.add_history("Recruited")
		
	current_settlement.warbands.append(new_warband)
	Loggie.msg("Drafted %d citizens into %s." % [population_cost, new_warband.custom_name]).domain("SETTLEMENT").info()
	
	save_settlement()
	EventBus.purchase_successful.emit(unit_data.display_name)

# --- OTHER MANAGERS ---

func calculate_payout() -> Dictionary:
	if not current_settlement: return {}
	
	_process_construction_labor()
	var hunger_warnings = _process_warband_hunger()
	var total_payout: Dictionary = {}
	if not hunger_warnings.is_empty():
		total_payout["_messages"] = hunger_warnings

	var stewardship_bonus := 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	for entry in current_settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if not total_payout.has(type): total_payout[type] = 0
			
			var p_count = entry.get("peasant_count", 0)
			var p_out = p_count * b_data.output_per_peasant
			
			var t_count = entry.get("thrall_count", 0)
			var t_out = t_count * b_data.output_per_thrall
			
			var production = int((p_out + t_out) * stewardship_bonus)
			total_payout[type] += production

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

	return total_payout

func deposit_resources(loot: Dictionary) -> void:
	if not current_settlement: return
	for resource_type in loot:
		if resource_type.begins_with("_"): continue
		var amount = loot[resource_type]
		if resource_type == "population":
			current_settlement.population_thralls += amount
		elif current_settlement.treasury.has(resource_type):
			current_settlement.treasury[resource_type] += amount
		else:
			current_settlement.treasury[resource_type] = amount
	EventBus.treasury_updated.emit(current_settlement.treasury)
	save_settlement()

# --- BOILERPLATE (Shortened for brevity, keep your existing functions) ---
# (Ensure _clone_settlement_data in MapDataGenerator also copies population_peasants)

# ... (The rest of your functions: save/load, construction, warbands, etc. remain the same)
# Just ensure you replace 'population_total' with 'population_peasants' if it appears anywhere else.

# ... (Below functions are included for safety) ...

func _process_construction_labor() -> void:
	if not current_settlement: return
	var completed_indices: Array[int] = []
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		var b_data = load(entry["resource_path"]) as BuildingData
		if not b_data: continue
		
		var peasants = entry.get("peasant_count", 0)
		var thralls = entry.get("thrall_count", 0)
		if peasants == 0 and thralls == 0: continue 
			
		var labor_points = (peasants + thralls) * BUILDER_EFFICIENCY
		entry["progress"] = entry.get("progress", 0) + labor_points
		
		if entry["progress"] >= b_data.construction_effort_required:
			completed_indices.append(i)
			current_settlement.placed_buildings.append({
				"resource_path": entry["resource_path"],
				"grid_position": entry["grid_position"],
				"peasant_count": peasants,
				"thrall_count": thralls
			})
	
	completed_indices.sort()
	completed_indices.reverse()
	for i in completed_indices:
		current_settlement.pending_construction_buildings.remove_at(i)
	save_settlement()
	if not completed_indices.is_empty(): _trigger_territory_update()

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

func upgrade_warband_gear(warband: WarbandData) -> bool:
	if not current_settlement: return false
	if warband.gear_tier >= WarbandData.MAX_GEAR_TIER: return false
	var cost = warband.get_gear_cost()
	if attempt_purchase({"gold": cost}):
		warband.gear_tier += 1
		warband.add_history("Upgraded to %s" % warband.get_gear_name())
		save_settlement()
		EventBus.purchase_successful.emit("Gear Upgrade")
		return true
	return false

func toggle_hearth_guard(warband: WarbandData) -> void:
	if not current_settlement: return
	warband.is_hearth_guard = !warband.is_hearth_guard
	save_settlement()
	EventBus.purchase_successful.emit("Guard Toggle")

func _process_warband_hunger() -> Array[String]:
	if not current_settlement: return []
	var deserters: Array[WarbandData] = []
	var warnings: Array[String] = []
	for warband in current_settlement.warbands:
		if warband.is_hearth_guard: continue
		var decay = 25
		warband.modify_loyalty(-decay)
		warband.turns_idle += 1
		if warband.loyalty <= 0:
			if randf() < 0.5:
				deserters.append(warband)
				warnings.append("[color=red]DESERTION: The %s have left![/color]" % warband.custom_name)
			else:
				warnings.append("[color=red]MUTINY: The %s refuse to obey![/color]" % warband.custom_name)
		elif warband.loyalty <= 25:
			warnings.append("[color=yellow]UNREST: The %s are growing restless (%d%% Loyalty).[/color]" % [warband.custom_name, warband.loyalty])
	for bad_apple in deserters: current_settlement.warbands.erase(bad_apple)
	if not deserters.is_empty() or not warnings.is_empty(): save_settlement()
	return warnings

func delete_save_file() -> void:
	var settlement_deleted := false
	var map_deleted := false
	if FileAccess.file_exists(USER_SAVE_PATH):
		if DirAccess.remove_absolute(USER_SAVE_PATH) == OK: settlement_deleted = true
	if FileAccess.file_exists(MAP_SAVE_PATH):
		if DirAccess.remove_absolute(MAP_SAVE_PATH) == OK: map_deleted = true
	reset_manager_state()
	Loggie.msg("Save files deleted.").domain("SYSTEM").info()

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

func _on_player_unit_died(unit: Node2D) -> void:
	if not current_settlement: return
	var base_unit = unit as BaseUnit
	if not base_unit or not base_unit.warband_ref: return 
	var warband = base_unit.warband_ref
	if warband in current_settlement.warbands:
		warband.current_manpower -= 1
		if warband.current_manpower <= 0:
			if warband.assigned_heir_name != "":
				DynastyManager.kill_heir_by_name(warband.assigned_heir_name, "Slain leading the %s" % warband.custom_name)
			current_settlement.warbands.erase(warband)
		save_settlement()

func load_settlement(data: SettlementData) -> void:
	if ResourceLoader.exists(USER_SAVE_PATH):
		var saved_data = load(USER_SAVE_PATH)
		if saved_data is SettlementData:
			current_settlement = saved_data
		else:
			_load_fallback_data(data)
	else:
		_load_fallback_data(data)
	EventBus.settlement_loaded.emit(current_settlement)
	_trigger_territory_update()

func _load_fallback_data(data: SettlementData) -> void:
	if data:
		current_settlement = data.duplicate(true)
		if current_settlement.warbands == null: current_settlement.warbands = []

func save_settlement() -> void:
	if not current_settlement: return
	ResourceSaver.save(current_settlement, USER_SAVE_PATH)

func has_current_settlement() -> bool:
	return current_settlement != null

func get_active_grid_cell_size() -> Vector2:
	if is_instance_valid(active_astar_grid): return active_astar_grid.cell_size
	return Vector2(32, 32)

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
