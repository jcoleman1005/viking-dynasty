extends Node

# --- Constants ---
const USER_SAVE_PATH := "user://savegame.tres"
const MAP_SAVE_PATH := "user://campaign_map.tres"
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF_SIZE = Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)

# NEW: Terrain Validation Constants
const MAX_SEARCH_RADIUS: int = 10 # How far to search for valid ground
# CORRECTED: Uses Negative Logic based on NBLM Context ("is_unwalkable")
const UNWALKABLE_LAYER_NAME: String = "is_unwalkable" 
const GREAT_HALL_BUFFER: int = 4 # Tiles from water required for Great Hall

# --- Data State ---
var current_settlement: SettlementData 
var active_map_data: SettlementData      

# --- Scene Refs ---
var active_building_container: Node2D = null
var active_tilemap_layer: TileMapLayer = null # Critical for Custom Data lookups
var pending_seasonal_recruits: Array[UnitData] = []

# --- Signals ---
# (Assuming these exist based on previous context, inferred if not declared)
# signal settlement_loaded(data) 

func _ready() -> void:
	EventBus.player_unit_died.connect(_on_player_unit_died)
	Loggie.msg("SettlementManager Initialized").domain(LogDomains.GAMEPLAY).info()
	
# --- TERRAIN & COORDINATE VALIDATION (NEW) ---

## CHECKS TERRAIN DATA ONLY (Ignores Buildings/Units)
## Returns TRUE if the tile is valid land (not water/void).
func is_terrain_walkable(coords: Vector2i) -> bool:
	# 1. Check if we have a map to read from
	if not is_instance_valid(active_tilemap_layer):
		# Fallback: If no map, assume valid to prevent softlocks
		return true
	
	# 2. Check if the cell exists (is not empty/void)
	var tile_data: TileData = active_tilemap_layer.get_cell_tile_data(coords)
	if not tile_data:
		return false # Void/Empty space is invalid

	# 3. Check Unwalkability via Custom Data (NEGATIVE LOGIC)
	# "is_unwalkable" = true means WATER/OBSTACLE.
	# "is_unwalkable" = false (or null) means LAND.
	var is_unwalkable: bool = tile_data.get_custom_data(UNWALKABLE_LAYER_NAME)
	
	# Return valid if NOT unwalkable
	return not is_unwalkable

## CHECKS TILE DATA + DYNAMIC SOLIDS
## Returns TRUE if the tile is land AND empty of obstacles.
func is_tile_valid_for_placement(coords: Vector2i) -> bool:
	# 1. Check Static Terrain (Water/Cliffs)
	if not is_terrain_walkable(coords):
		return false
	
	# 2. Check Dynamic Solids (Buildings/Units via NavManager)
	if NavigationManager.is_point_solid(coords):
		return false
		
	return true

## Finds the nearest valid tile to the target coordinates.
## Useful if a unit tries to spawn on water; this moves them to the beach.
func get_nearest_valid_spawn_point(target_coords: Vector2i) -> Vector2i:
	# Optimistic check: if target is valid, return immediately
	if is_tile_valid_for_placement(target_coords):
		return target_coords
		
	Loggie.msg("Target invalid %s, searching for nearest land" % target_coords).domain(LogDomains.GAMEPLAY).debug()
	
	# BFS Flood Fill to find nearest valid tile
	var visited: Dictionary[Vector2i, bool] = {} # Typed dictionary for 4.4
	var queue: Array[Vector2i] = []
	
	queue.append(target_coords)
	visited[target_coords] = true
	
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		
		# Valid found?
		if is_tile_valid_for_placement(current):
			return current
			
		# Limit search depth roughly by checking distance
		if Vector2(current - target_coords).length() > MAX_SEARCH_RADIUS:
			continue
			
		# Add neighbors (4-way)
		var neighbors = [
			Vector2i(0, 1), Vector2i(0, -1), 
			Vector2i(1, 0), Vector2i(-1, 0)
		]
		
		for offset in neighbors:
			var next_cell = current + offset
			if not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)
	
	# Fallback if map is totally water or error
	Loggie.msg("No valid spawn point found within radius").ctx({"radius": MAX_SEARCH_RADIUS}).domain(LogDomains.GAMEPLAY).warn()
	return target_coords

# --- COORDINATE & SPATIAL DELEGATION ---

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	if NavigationManager.has_method("_grid_to_world"):
		return NavigationManager._grid_to_world(grid_pos)
	
	var iso_x = (grid_pos.x - grid_pos.y) * 32.0 
	var iso_y = (grid_pos.x + grid_pos.y) * 16.0 
	return Vector2(iso_x, iso_y)

func get_tile_center(grid_pos: Vector2i) -> Vector2:
	if NavigationManager.has_method("_grid_to_world"):
		var top_left = NavigationManager._grid_to_world(grid_pos)
		return top_left + Vector2(0, 16.0) 
		
	return grid_to_world(grid_pos)

## NEW: Calculates the VISUAL CENTER of a multi-tile footprint.
## Fixes the "Heel vs Foot" issue where buildings were visually offset from their logic.
func get_footprint_center(grid_pos: Vector2i, grid_size: Vector2i) -> Vector2:
	# Convert grid coordinate + half size to world space
	# This aligns with SettlementBridge logic: Center = Pos + Size/2
	
	var center_x = float(grid_pos.x) + (float(grid_size.x) / 2.0)
	var center_y = float(grid_pos.y) + (float(grid_size.y) / 2.0)
	
	# Manual Isometric Conversion (matches grid_to_world but for floats)
	# Assuming Tile Width 64, Height 32 (Half 32, 16)
	var iso_x = (center_x - center_y) * 32.0
	var iso_y = (center_x + center_y) * 16.0
	
	return Vector2(iso_x, iso_y)

func world_to_grid(pos: Vector2) -> Vector2i:
	return NavigationManager._world_to_grid(pos)

## UPDATED: Checks direct tile data + navigation
func is_tile_buildable(grid_pos: Vector2i) -> bool:
	return is_tile_valid_for_placement(grid_pos)

func get_active_grid_cell_size() -> Vector2:
	if NavigationManager.active_astar_grid:
		return NavigationManager.active_astar_grid.cell_size
	return Vector2(64, 32) 

# --- BUILDING PLACEMENT ---

func _spawn_building_node(building_data: BuildingData, grid_pos: Vector2i) -> BaseBuilding:
	if not is_instance_valid(active_building_container): return null

	var new_building = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	new_building.grid_coordinate = grid_pos
	
	# CRITICAL FIX: Use Footprint Center instead of Tile Center
	# This ensures the sprite is centered over the entire MxN grid area.
	var center_pos = get_footprint_center(grid_pos, building_data.grid_size)
	new_building.global_position = center_pos 
	
	active_building_container.add_child(new_building)
	return new_building
	
func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	if not is_instance_valid(active_building_container): return null
	
	# 1. Validation (Loops from Top-Left grid_position)
	if not is_placement_valid(grid_position, building_data.grid_size, building_data): 
		return null

	# 2. Spawn Visuals (Correctly centered now)
	var new_building = _spawn_building_node(building_data, grid_position)
	
	var entry = {
		"resource_path": building_data.resource_path,
		"grid_position": grid_position,
		"peasant_count": 0, "thrall_count": 0, "progress": 0
	}
	
	# 3. Update Data & Navigation Grid
	if active_map_data:
		if is_new_construction and building_data.construction_effort_required > 0:
			active_map_data.pending_construction_buildings.append(entry)
			new_building.set_state(BaseBuilding.BuildingState.BLUEPRINT)
			if active_map_data == current_settlement: save_settlement()
			_update_building_footprint_navigation(building_data, grid_position, true)
		else:
			active_map_data.placed_buildings.append(entry)
			new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
			_update_building_footprint_navigation(building_data, grid_position, true)
			
	return new_building

func reconstruct_buildings_from_data() -> void:
	if active_building_container:
		for child in active_building_container.get_children():
			if child is BaseBuilding: child.queue_free()
			
	if not current_settlement: return
	
	for entry in current_settlement.placed_buildings:
		if ResourceLoader.exists(entry.resource_path):
			var data = load(entry.resource_path)
			var b = _spawn_building_node(data, entry.grid_position)
			if b: b.set_state(BaseBuilding.BuildingState.ACTIVE)
			_update_building_footprint_navigation(data, entry.grid_position, true)
			
	for entry in current_settlement.pending_construction_buildings:
		if ResourceLoader.exists(entry.resource_path):
			var data = load(entry.resource_path)
			var b = _spawn_building_node(data, entry.grid_position)
			if b: b.set_state(BaseBuilding.BuildingState.BLUEPRINT)
			_update_building_footprint_navigation(data, entry.grid_position, true)

func remove_building(building_instance: BaseBuilding) -> void:
	if not active_map_data or not is_instance_valid(building_instance): return
	
	var grid_pos = Vector2i.ZERO
	if "grid_coordinate" in building_instance and building_instance.grid_coordinate != Vector2i(-999, -999):
		grid_pos = building_instance.grid_coordinate
	else:
		grid_pos = NavigationManager._world_to_grid(building_instance.global_position)

	if building_instance.data:
		_update_building_footprint_navigation(building_instance.data, grid_pos, false)

	var removed_placed = _remove_from_list(active_map_data.placed_buildings, grid_pos)
	var removed_pending = _remove_from_list(active_map_data.pending_construction_buildings, grid_pos)
	
	if removed_placed or removed_pending:
		if active_map_data == current_settlement: save_settlement()
		
	building_instance.queue_free()

func _update_building_footprint_navigation(data: BuildingData, origin: Vector2i, is_solid: bool) -> void:
	for x in range(data.grid_size.x):
		for y in range(data.grid_size.y):
			var cell = origin + Vector2i(x, y)
			NavigationManager.set_point_solid(cell, is_solid)
	
	EventBus.pathfinding_grid_updated.emit(Vector2i.ZERO)

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry = list[i]
		var entry_pos = entry["grid_position"]
		if Vector2i(entry_pos.x, entry_pos.y) == grid_pos:
			list.remove_at(i)
			return true
	return false

# --- PLACEMENT VALIDATION & DIAGNOSTICS ---

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> bool:
	var error = get_placement_error(grid_position, building_size, building_data)
	return error == ""

## Returns an empty string if valid, or a reason string if invalid.
func get_placement_error(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> String:
	# 1. Check Solids via STRICT Validation
	for x in range(building_size.x):
		for y in range(building_size.y):
			var check = grid_position + Vector2i(x, y)
			if not is_tile_valid_for_placement(check):
				return "Blocked / Invalid Terrain"

	# 2. Check Great Hall Buffer (Must be far from water)
	if building_data and _is_great_hall(building_data):
		if not _check_surrounding_terrain_buffer(grid_position, building_size, GREAT_HALL_BUFFER):
			return "Too Close to Water"

	# 3. Check District/Economic Logic
	if building_data and building_data is EconomicBuildingData:
		if not _is_within_district_range(grid_position, building_size, building_data):
			var res_name = building_data.resource_type.capitalize()
			return "Must be near %s" % res_name
			
	return ""

func _is_great_hall(data: BuildingData) -> bool:
	# Heuristic check for the Great Hall
	if "Great Hall" in data.display_name: return true
	if "GreatHall" in data.resource_path or "Great_Hall" in data.resource_path: return true
	return false

func _check_surrounding_terrain_buffer(origin: Vector2i, size: Vector2i, buffer: int) -> bool:
	# Loop through the padded rectangle
	var start_x = origin.x - buffer
	var end_x = origin.x + size.x + buffer
	var start_y = origin.y - buffer
	var end_y = origin.y + size.y + buffer
	
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			# We only care about TERRAIN validation here (is it water?)
			# We do NOT care if there is a tree or another building in the buffer zone.
			if not is_terrain_walkable(Vector2i(x, y)):
				return false
	return true

func _is_within_district_range(grid_pos: Vector2i, size: Vector2i, data: EconomicBuildingData) -> bool:
	var cell = get_active_grid_cell_size()
	# FIX: Use Isometric Center calculation instead of Orthogonal
	var center = get_footprint_center(grid_pos, size)
	
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	for node in nodes:
		if "resource_type" in node and node.resource_type == data.resource_type:
			if node.has_method("is_depleted") and node.is_depleted(): continue
			
			if node.has_method("is_position_in_district"):
				if node.is_position_in_district(center): return true
			else:
				var dist = center.distance_to(node.global_position)
				var rad = node.get("district_radius") if "district_radius" in node else 300.0
				if dist <= rad: return true
				
	return false

# --- SCENE MANAGEMENT ---

func register_active_scene_nodes(container: Node2D) -> void:
	Loggie.msg("SettlementManager: Registering container: %s" % container.name).domain(LogDomains.SETTLEMENT).info()
	active_building_container = container
	
	# CRITICAL: Capture the TileMapLayer so is_tile_valid_for_placement can read Custom Data
	if container.get_parent() is TileMapLayer:
		active_tilemap_layer = container.get_parent()
		Loggie.msg("Active TileMapLayer captured for terrain validation.").domain(LogDomains.SETTLEMENT).info()
	elif container.get_parent().has_node("TileMapLayer"):
		# Fallback if structure is different
		active_tilemap_layer = container.get_parent().get_node("TileMapLayer")
	
	if current_settlement:
		reconstruct_buildings_from_data()

func unregister_active_scene_nodes() -> void:
	active_building_container = null
	active_tilemap_layer = null

# --- PERSISTENCE ---

func load_settlement(data: SettlementData) -> void:
	if ResourceLoader.exists(USER_SAVE_PATH):
		current_settlement = load(USER_SAVE_PATH)
	else:
		_load_fallback_data(data)
	active_map_data = current_settlement
	if active_building_container: reconstruct_buildings_from_data()
	EventBus.settlement_loaded.emit(current_settlement)
	
func _load_fallback_data(data: SettlementData) -> void:
	if data:
		current_settlement = data.duplicate(true)
		if current_settlement.warbands == null: current_settlement.warbands = []
		
		if current_settlement.map_seed == 0:
			randomize()
			current_settlement.map_seed = randi()
			Loggie.msg("New Campaign Initialized. Generated Seed: %d" % current_settlement.map_seed).domain(LogDomains.SETTLEMENT).info()
		
		save_settlement()
		Loggie.msg("Loaded default template and created new save file.").domain(LogDomains.SETTLEMENT).info()
	else:
		Loggie.msg("No data provided/found.").domain(LogDomains.SETTLEMENT).error()

func save_settlement() -> void:
	if not current_settlement: return
	var error = ResourceSaver.save(current_settlement, USER_SAVE_PATH)
	if error != OK:
		Loggie.msg("Save Failed: %s" % error).domain(LogDomains.SETTLEMENT).error()

func delete_save_file() -> void:
	if FileAccess.file_exists(USER_SAVE_PATH):
		DirAccess.remove_absolute(USER_SAVE_PATH)
	if FileAccess.file_exists(MAP_SAVE_PATH):
		DirAccess.remove_absolute(MAP_SAVE_PATH)
	reset_manager_state()
	Loggie.msg("Save files deleted.").domain(LogDomains.SYSTEM).info()

func reset_manager_state() -> void:
	current_settlement = null
	active_map_data = null
	active_building_container = null

func has_current_settlement() -> bool:
	return current_settlement != null

# --- ECONOMY & WORKERS ---

# FIX: Add Backward Compatibility for SettlementBridge.gd (Prevents crash, prevents double-refund)
func deposit_resources(_resources: Dictionary) -> void:
	Loggie.msg("SettlementBridge tried to refund via deprecated 'deposit_resources'. Ignored to prevent double-refund (StorefrontUI handles this now).").domain(LogDomains.ECONOMY).warn()

# FIX: Proxy for WinterManager and other legacy systems.
# Forwards the purchase request to the new EconomyManager.
func attempt_purchase(cost: Dictionary) -> bool:
	return EconomyManager.attempt_purchase(cost)

func get_total_ship_capacity_squads() -> int:
	var total_capacity = 3
	if not current_settlement: return total_capacity
	for entry in current_settlement.placed_buildings:
		var data = load(entry["resource_path"]) as BuildingData
		if data: total_capacity += data.fleet_capacity_bonus
	return total_capacity

func get_idle_peasants() -> int:
	if not current_settlement: return 0
	
	var employed = 0
	for entry in current_settlement.placed_buildings:
		employed += entry.get("peasant_count", 0)
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("peasant_count", 0)
	
	var idle = current_settlement.population_peasants - employed
	
	if idle < 0:
		Loggie.msg("Negative Idle Peasants detected (%d). Triggering layoffs." % idle).domain(LogDomains.SETTLEMENT).warn()
		_validate_employment_levels()
		return 0 
	
	return idle

func get_idle_thralls() -> int:
	if not current_settlement: return 0
	
	var employed = 0
	for entry in current_settlement.placed_buildings:
		employed += entry.get("thrall_count", 0)
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("thrall_count", 0)
		
	var idle = current_settlement.population_thralls - employed
	
	if idle < 0:
		Loggie.msg("Negative Idle Thralls detected (%d). Triggering layoffs." % idle).domain(LogDomains.SETTLEMENT).warn()
		_validate_employment_levels()
		return 0
	
	return idle

func assign_worker(building_index: int, type: String, amount: int) -> void:
	if not current_settlement: return
	var entry = current_settlement.placed_buildings[building_index]
	var data = load(entry["resource_path"]) as EconomicBuildingData
	if not data: return
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.peasant_capacity if type == "peasant" else data.thrall_capacity
	var current = entry.get(key, 0)
	var new_val = clampi(current + amount, 0, cap)
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
	var new_val = clampi(current + amount, 0, cap)
	if amount > 0:
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
		if amount > idle:
			EventBus.purchase_failed.emit("Not enough %ss!" % type.capitalize())
			return
	entry[key] = new_val
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

func _validate_employment_levels() -> void:
	if not current_settlement: return
	
	# 1. Validate Peasants
	var total_peasants = current_settlement.population_peasants
	var employed_peasants = 0
	for entry in current_settlement.placed_buildings:
		employed_peasants += entry.get("peasant_count", 0)
	
	if employed_peasants > total_peasants:
		var deficit = employed_peasants - total_peasants
		_force_layoffs("peasant", deficit)
		
	# 2. Validate Thralls
	var total_thralls = current_settlement.population_thralls
	var employed_thralls = 0
	for entry in current_settlement.placed_buildings:
		employed_thralls += entry.get("thrall_count", 0)
		
	if employed_thralls > total_thralls:
		var deficit = employed_thralls - total_thralls
		_force_layoffs("thrall", deficit)

func _force_layoffs(type: String, amount_to_remove: int) -> void:
	var removed_count = 0
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	
	var buildings = current_settlement.placed_buildings
	for i in range(buildings.size() - 1, -1, -1):
		if removed_count >= amount_to_remove: 
			break
		
		var entry = buildings[i]
		var current_workers = entry.get(key, 0)
		
		if current_workers > 0:
			var take = min(current_workers, amount_to_remove - removed_count)
			entry[key] = current_workers - take
			removed_count += take
			
	Loggie.msg("Force Layoff Complete. Removed %d %ss due to population deficit." % [removed_count, type]).domain(LogDomains.SETTLEMENT).info()
	EventBus.settlement_loaded.emit(current_settlement)

func process_construction_labor() -> void:
	if not current_settlement: return
	
	# 1. Delegate Math to EconomyManager
	var finished_buildings = EconomyManager.advance_construction_progress()
	
	# 2. Handle Completion (Scene/Gameplay Logic)
	for entry in finished_buildings:
		_finalize_construction(entry)
		
	# Save state if any progress happened
	save_settlement()
	
func _finalize_construction(entry: Dictionary) -> void:
	# Add to authoritative "Placed" list
	# (Ensure we reset transient data like progress/workers)
	entry.erase("progress")
	entry.erase("peasant_count")
	
	current_settlement.placed_buildings.append(entry)
	
	Loggie.msg("Construction Finalized: %s" % entry.get("resource_path")).domain(LogDomains.SETTLEMENT).info()
	
	# Trigger Scene Updates (e.g., spawn the actual node)
	# This signal is likely listened to by your BuildingManager or SceneController
	EventBus.building_construction_completed.emit(entry)
# --- RECRUITMENT & WARBANDS ---

func recruit_unit(unit_data: UnitData) -> void:
	if not current_settlement or not unit_data:
		return
	
	var current_squads = current_settlement.warbands.size()
	var max_squads = get_total_ship_capacity_squads()
	
	if current_squads >= max_squads:
		Loggie.msg("Recruitment blocked: Fleet at capacity (%d/%d)" % [current_squads, max_squads]).domain(LogDomains.SETTLEMENT).info()
		EventBus.purchase_failed.emit("Fleet capacity reached! Build more Nausts.")
		return

	var new_warband = WarbandData.new(unit_data)
	
	if DynastyManager.has_purchased_upgrade("UPG_TRAINING_GROUNDS"):
		new_warband.experience = 200
		new_warband.add_history("Recruited as Hardened Veterans")
	else:
		new_warband.add_history("Recruited")
		
	current_settlement.warbands.append(new_warband)
	save_settlement()
	
	EventBus.purchase_successful.emit(unit_data.display_name)
	EventBus.settlement_loaded.emit(current_settlement)

func upgrade_warband_gear(warband: WarbandData) -> bool:
	if not current_settlement: return false
	if warband.gear_tier >= WarbandData.MAX_GEAR_TIER: return false
	var cost = warband.get_gear_cost()
	
	if EconomyManager.attempt_purchase({"gold": cost}):
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
				warnings.append("DESERTION: The %s have left!" % warband.custom_name)
			else:
				warnings.append("MUTINY: The %s refuse to obey!" % warband.custom_name)
		elif warband.loyalty <= 25:
			warnings.append("UNREST: The %s are growing restless." % warband.custom_name)
	for bad_apple in deserters: current_settlement.warbands.erase(bad_apple)
	if not deserters.is_empty() or not warnings.is_empty(): save_settlement()
	return warnings

func _on_player_unit_died(unit: Node2D) -> void:
	if not current_settlement: return
	var warband = unit.get("warband_ref")
	if not warband: return 
	if warband in current_settlement.warbands:
		warband.current_manpower -= 1
		if warband.current_manpower <= 0:
			if warband.assigned_heir_name != "":
				DynastyManager.kill_heir_by_name(warband.assigned_heir_name, "Slain in battle")
			current_settlement.warbands.erase(warband)
		save_settlement()

func assign_worker_from_unit(building: BaseBuilding, type: String) -> bool:
	if not current_settlement: return false
	var entry = _find_entry_for_building(building)
	if entry.is_empty(): return false
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
		return false
	entry["peasant_count"] = current + 1
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)
	return true
	
func _find_entry_for_building(building: BaseBuilding) -> Dictionary:
	if "grid_coordinate" in building:
		var tagged_pos = building.grid_coordinate
		if tagged_pos != Vector2i(-999, -999):
			for entry in current_settlement.placed_buildings:
				if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == tagged_pos: return entry
			for entry in current_settlement.pending_construction_buildings:
				if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == tagged_pos: return entry
	
	# Fallback if grid_coordinate not found
	var grid_pos = NavigationManager._world_to_grid(building.global_position)
	
	for entry in current_settlement.placed_buildings:
		if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == grid_pos: 
			building.grid_coordinate = grid_pos
			return entry
	for entry in current_settlement.pending_construction_buildings:
		if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == grid_pos: 
			building.grid_coordinate = grid_pos
			return entry
	return {}

func unassign_worker_from_building(building: BaseBuilding, type: String) -> bool:
	if not current_settlement: return false
	var entry = _find_entry_for_building(building)
	if entry.is_empty(): return false
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var current = entry.get(key, 0)
	if current <= 0: return false
	entry[key] = current - 1
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)
	return true

func get_building_index(building_instance: Node2D) -> int:
	var data_to_search = active_map_data if active_map_data else current_settlement
	if not data_to_search: return -1
	var search_placed = true
	if "current_state" in building_instance:
		if building_instance.current_state != BaseBuilding.BuildingState.ACTIVE:
			search_placed = false
	var target_list = data_to_search.placed_buildings if search_placed else data_to_search.pending_construction_buildings
	if "grid_coordinate" in building_instance:
		var tagged_pos = building_instance.get("grid_coordinate")
		if tagged_pos != Vector2i(-999, -999):
			for i in range(target_list.size()):
				var entry = target_list[i]
				var pos = entry["grid_position"]
				if Vector2i(pos.x, pos.y) == tagged_pos: return i
				
	# Fallback
	var grid_pos = NavigationManager._world_to_grid(building_instance.global_position)
	for i in range(target_list.size()):
		var entry = target_list[i]
		var pos = entry["grid_position"]
		if Vector2i(pos.x, pos.y) == grid_pos: return i
	return -1

func queue_seasonal_recruit(unit_data: UnitData, count: int) -> void:
	for i in range(count): pending_seasonal_recruits.append(unit_data)

func commit_seasonal_recruits() -> void:
	if pending_seasonal_recruits.is_empty(): return
	if not current_settlement: return
	var new_warbands: Array[WarbandData] = []
	var current_batch_wb: WarbandData = null
	for u_data in pending_seasonal_recruits:
		if current_batch_wb == null or current_batch_wb.current_manpower >= WarbandData.MAX_MANPOWER or current_batch_wb.unit_type != u_data:
			current_batch_wb = WarbandData.new(u_data)
			current_batch_wb.is_seasonal = true
			current_batch_wb.current_manpower = 0 
			current_batch_wb.custom_name = "Drengir (%s)" % _generate_oath_name()
			current_batch_wb.add_history("Swore the oath at Yule")
			current_settlement.warbands.append(current_batch_wb)
			new_warbands.append(current_batch_wb)
		current_batch_wb.current_manpower += 1
	Loggie.msg("Spring Arrival: %d men organized into %d Warbands." % [pending_seasonal_recruits.size(), new_warbands.size()]).domain(LogDomains.SETTLEMENT).info()
	pending_seasonal_recruits.clear()
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
	return "The %s" % names.pick_random()

# --- FORMATION SAFETY ---

func validate_formation_point(target_pos: Vector2, taken_grid_points: Array[Vector2i] = []) -> Vector2:
	var grid_pos = world_to_grid(target_pos)
	
	# Use new safe function first
	if is_tile_valid_for_placement(grid_pos) and not grid_pos in taken_grid_points:
		return target_pos
		
	# Search using NavManager logic via wrapper
	var safe_grid_pos = _get_closest_walkable_point_exclusive(grid_pos, 4, taken_grid_points)
	
	return get_tile_center(safe_grid_pos)

func _get_closest_walkable_point_exclusive(origin: Vector2i, max_radius: int, exclusions: Array[Vector2i]) -> Vector2i:
	if is_tile_valid_for_placement(origin) and not origin in exclusions: return origin
	
	for r in range(1, max_radius + 1):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if abs(x) != r and abs(y) != r: continue
				
				var candidate = origin + Vector2i(x, y)
				if is_tile_valid_for_placement(candidate) and not candidate in exclusions:
					return candidate
	
	return origin
