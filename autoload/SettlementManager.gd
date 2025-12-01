# res://autoload/SettlementManager.gd
extends Node

# --- Constants ---
const USER_SAVE_PATH := "user://savegame.tres"
const MAP_SAVE_PATH := "user://campaign_map.tres"

# --- State ---
var current_settlement: SettlementData
var active_astar_grid: AStarGrid2D = null
var active_building_container: Node2D = null
var grid_manager_node: Node = null 

# Scene Transition Flag
var pending_management_open: bool = false

func _ready() -> void:
	EventBus.player_unit_died.connect(_on_player_unit_died)

# --- ECONOMY DELEGATION (CLEANED) ---

func calculate_payout() -> Dictionary:
	# Pure delegation. EconomyManager handles the orchestration.
	return EconomyManager.calculate_payout()

func deposit_resources(loot: Dictionary) -> void:
	# Pure delegation. Prevents double-counting resources.
	EconomyManager.deposit_resources(loot)

func attempt_purchase(item_cost: Dictionary) -> bool:
	# Pure delegation.
	return EconomyManager.attempt_purchase(item_cost)

func apply_raid_damages() -> Dictionary:
	# Pure delegation.
	return EconomyManager.apply_raid_damages()

# --- POPULATION & WORKER MANAGEMENT ---

func get_idle_peasants() -> int:
	if not current_settlement: return 0
	var employed = 0
	
	# Count Active
	for entry in current_settlement.placed_buildings:
		employed += entry.get("peasant_count", 0)
		
	# Count Builders
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("peasant_count", 0)
	
	return current_settlement.population_peasants - employed

func get_idle_thralls() -> int:
	if not current_settlement: return 0
	var employed = 0
	
	# Count Active
	for entry in current_settlement.placed_buildings:
		employed += entry.get("thrall_count", 0)
		
	# Count Builders
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("thrall_count", 0)
	
	return current_settlement.population_thralls - employed

func assign_worker(building_index: int, type: String, amount: int) -> void:
	if not current_settlement: return
	var entry = current_settlement.placed_buildings[building_index]
	var data = load(entry["resource_path"]) as EconomicBuildingData
	if not data: return
	
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.peasant_capacity if type == "peasant" else data.thrall_capacity
	var current = entry.get(key, 0)
	
	var new_val = current + amount
	new_val = clampi(new_val, 0, cap)
	
	# Check Availability (Only if adding)
	if amount > 0:
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
		if amount > idle:
			EventBus.purchase_failed.emit("Not enough idle %ss!" % type.capitalize())
			return
			
	entry[key] = new_val
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

func assign_construction_worker(index: int, type: String, amount: int) -> void:
	if not current_settlement: return
	var entry = current_settlement.pending_construction_buildings[index]
	var data = load(entry["resource_path"]) as BuildingData
	if not data: return
	
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.base_labor_capacity 
	var current = entry.get(key, 0)
	
	var new_val = current + amount
	new_val = clampi(new_val, 0, cap)
	
	if amount > 0:
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
		if amount > idle:
			EventBus.purchase_failed.emit("Not enough %ss!" % type.capitalize())
			return
			
	entry[key] = new_val
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

# --- CONSTRUCTION LOGIC ---

func process_construction_labor() -> void:
	if not current_settlement: return
	
	var completed_indices: Array[int] = []
	
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		var b_data = load(entry["resource_path"]) as BuildingData
		if not b_data: continue
		
		# Calculate Local Labor
		var peasants = entry.get("peasant_count", 0)
		var thralls = entry.get("thrall_count", 0)
		
		if peasants == 0 and thralls == 0:
			continue 
			
		# Note: Efficiency constant is now in EconomyManager
		var labor_points = (peasants + thralls) * EconomyManager.BUILDER_EFFICIENCY
		
		entry["progress"] = entry.get("progress", 0) + labor_points
		Loggie.msg("Construction: %s gained %d progress" % [b_data.display_name, labor_points]).domain("SETTLEMENT").info()
		
		if entry["progress"] >= b_data.construction_effort_required:
			completed_indices.append(i)
			
			# Move to placed, preserving workers
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

func complete_building_construction(building_instance: BaseBuilding) -> void:
	# Called by BaseBuilding when state changes to ACTIVE via other means (e.g. debug)
	pass

# --- RECRUITMENT & UNIT LOGIC ---

func recruit_unit(unit_data: UnitData) -> void:
	if not current_settlement or not unit_data: return
	
	# --- REMOVED: Population Conscription Logic ---
	# We no longer check for idle peasants or deduct them.
	# Recruitment is now purely a mercenary/professional contract paid in Gold/Food.
	# ----------------------------------------------
	
	var new_warband = WarbandData.new(unit_data)
	
	# Training Grounds Legacy
	if DynastyManager.has_purchased_upgrade("UPG_TRAINING_GROUNDS"):
		new_warband.experience = 200
		new_warband.add_history("Recruited as Hardened Veterans")
	else:
		new_warband.add_history("Recruited")
		
	current_settlement.warbands.append(new_warband)
	
	Loggie.msg("Recruited %s (Mercenary Contract)." % new_warband.custom_name).domain(LogDomains.SETTLEMENT).info()
	
	save_settlement()
	EventBus.purchase_successful.emit(unit_data.display_name)
	
	# Emit settlement_loaded to force the Bridge/Spawner to refresh visuals
	# This ensures the new squad appears and villagers stay put
	EventBus.settlement_loaded.emit(current_settlement)

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
	if warband.is_hearth_guard:
		warband.add_history("Assigned to Hearth Guard")
	else:
		warband.add_history("Relieved from Hearth Guard")
	save_settlement()
	EventBus.purchase_successful.emit("Guard Toggle")

func process_warband_hunger() -> Array[String]:
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
				Loggie.msg("The %s have betrayed you and left!" % warband.custom_name).domain("SETTLEMENT").warn()
			else:
				warnings.append("[color=red]MUTINY: The %s refuse to obey![/color]" % warband.custom_name)
				Loggie.msg("The %s are openly mutinous!" % warband.custom_name).domain("SETTLEMENT").warn()
				
		elif warband.loyalty <= 25:
			warnings.append("[color=yellow]UNREST: The %s are growing restless (%d%% Loyalty).[/color]" % [warband.custom_name, warband.loyalty])
			
	for bad_apple in deserters:
		current_settlement.warbands.erase(bad_apple)
		
	if not deserters.is_empty() or not warnings.is_empty():
		save_settlement()
		
	return warnings

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
			Loggie.msg("☠️ Warband Destroyed: %s" % warband.custom_name).domain("SETTLEMENT").warn()
		else:
			Loggie.msg("⚔️ Casualty in %s. Remaining: %d" % [warband.custom_name, warband.current_manpower]).domain("SETTLEMENT").info()
		save_settlement()

# --- PERSISTENCE ---

func delete_save_file() -> void:
	if FileAccess.file_exists(USER_SAVE_PATH):
		DirAccess.remove_absolute(USER_SAVE_PATH)
	if FileAccess.file_exists(MAP_SAVE_PATH):
		DirAccess.remove_absolute(MAP_SAVE_PATH)
	reset_manager_state()
	Loggie.msg("Save files deleted.").domain("SYSTEM").info()

func reset_manager_state() -> void:
	current_settlement = null
	active_astar_grid = null
	active_building_container = null
	grid_manager_node = null

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
		if current_settlement.warbands == null: current_settlement.warbands = []
		Loggie.msg("Loaded default template.").domain("SETTLEMENT").info()
	else:
		Loggie.msg("No data provided and no save file found.").domain("SETTLEMENT").error()

func save_settlement() -> void:
	if not current_settlement: return
	var error = ResourceSaver.save(current_settlement, USER_SAVE_PATH)
	if error != OK:
		Loggie.msg("Failed to save to %s. Error code: %s" % [USER_SAVE_PATH, error]).domain("SETTLEMENT").error()

func has_current_settlement() -> bool:
	return current_settlement != null

# --- PATHFINDING / GRID (Delegated to Scene Nodes) ---

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
			"progress": 0,
			"peasant_count": 0,
			"thrall_count": 0
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
	
	var cell_size = active_astar_grid.cell_size
	var start = Vector2i(start_pos / cell_size)
	var end = Vector2i(end_pos / cell_size)
	
	if not _is_cell_within_bounds(start): return PackedVector2Array()
	
	var bounds = active_astar_grid.region
	end.x = clampi(end.x, bounds.position.x, bounds.end.x - 1)
	end.y = clampi(end.y, bounds.position.y, bounds.end.y - 1)
	
	return active_astar_grid.get_point_path(start, end, allow_partial_path)

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_position):
		active_astar_grid.set_point_solid(grid_position, solid)


func assign_worker_from_unit(building: BaseBuilding, type: String) -> bool:
	if not current_settlement: return false
	
	var entry = _find_entry_for_building(building)
	if entry.is_empty(): 
		Loggie.msg("SettlementManager: Could not find data for %s" % building.name).domain("SETTLEMENT").error()
		return false
	
	var data = building.data
	var cap = 0
	var current = 0
	
	if building.current_state == BaseBuilding.BuildingState.ACTIVE:
		if data is EconomicBuildingData:
			cap = data.peasant_capacity
			current = entry.get("peasant_count", 0)
	else:
		cap = data.base_labor_capacity
		current = entry.get("peasant_count", 0)
		
	if current >= cap:
		EventBus.purchase_failed.emit("Building is full!")
		return false # <--- FAILURE

	entry["peasant_count"] = current + 1
	Loggie.msg("Worker assigned to %s" % building.data.display_name).domain("SETTLEMENT").info()
	
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)
	return true # <--- SUCCESS
	
func _find_entry_for_building(building: BaseBuilding) -> Dictionary:
	# Helper to map a Node back to its Data Dictionary
	var cell_size = get_active_grid_cell_size()
	
	# Calculate the top-left grid position based on the building's center and size
	var half_size = (Vector2(building.data.grid_size) * cell_size) / 2.0
	var grid_pos = Vector2i((building.global_position - half_size) / cell_size)
	
	# Check Placed Buildings
	for entry in current_settlement.placed_buildings:
		# entry["grid_position"] might be Vector2 or Vector2i, cast to be safe
		if Vector2i(entry["grid_position"]) == grid_pos: return entry
		
	# Check Pending Construction
	for entry in current_settlement.pending_construction_buildings:
		if Vector2i(entry["grid_position"]) == grid_pos: return entry
		
	return {}
