extends Node

# --- Constants ---
const USER_SAVE_PATH := "user://savegame.tres"
const MAP_SAVE_PATH := "user://campaign_map.tres"

# --- Data State ---
var current_settlement: SettlementData 
var active_map_data: SettlementData    

# --- Grid Authority ---
var active_astar_grid: AStarGrid2D = null
var buildable_cells: Dictionary = {} 

# --- ISOMETRIC CONSTANTS ---
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF_SIZE = Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)

const GRID_WIDTH = 60
const GRID_HEIGHT = 60

# --- Scene Refs ---
var active_building_container: Node2D = null
var pending_management_open: bool = false
var pending_seasonal_recruits: Array[UnitData] = []

func _ready() -> void:
	EventBus.player_unit_died.connect(_on_player_unit_died)
	_init_grid()

# --- GRID AUTHORITY SYSTEM ---

## Returns the World Position of the TOP CORNER of the grid cell.
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var x = (grid_pos.x - grid_pos.y) * TILE_HALF_SIZE.x
	var y = (grid_pos.x + grid_pos.y) * TILE_HALF_SIZE.y
	return Vector2(x, y)

## Returns the World Position of the CENTER of the grid cell.
func get_tile_center(grid_pos: Vector2i) -> Vector2:
	var top_corner = grid_to_world(grid_pos)
	# In Isometric, center is TopCorner.y + HalfHeight
	return top_corner + Vector2(0, TILE_HALF_SIZE.y)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Standard Isometric to Grid conversion
	var x = (world_pos.x / TILE_HALF_SIZE.x + world_pos.y / TILE_HALF_SIZE.y) / 2.0
	var y = (world_pos.y / TILE_HALF_SIZE.y - (world_pos.x / TILE_HALF_SIZE.x)) / 2.0
	return Vector2i(floor(x), floor(y))

func _init_grid() -> void:
	active_astar_grid = AStarGrid2D.new()
	active_astar_grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	
	active_astar_grid.cell_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	
	# [CRITICAL] This tells AStar to expect Isometric Neighbors
	active_astar_grid.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN
	active_astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	active_astar_grid.update()
	
	if NavigationManager:
		NavigationManager.register_grid(active_astar_grid, self)

func _refresh_grid_state() -> void:
	if not active_astar_grid: _init_grid()
	
	# Safety Fallback
	if not active_map_data and current_settlement:
		active_map_data = current_settlement
	
	if not active_map_data: return 

	# 1. Clear Grid Solids
	var region = active_astar_grid.region
	active_astar_grid.fill_solid_region(region, false)
	
	# 2. Mark Placed Buildings
	for entry in active_map_data.placed_buildings:
		_apply_building_to_grid(entry, true)
		
	# 3. Mark Pending Construction
	for entry in active_map_data.pending_construction_buildings:
		_apply_building_to_grid(entry, true)
		
	# 4. Recalculate Territory
	buildable_cells = GridUtils.calculate_territory(
		active_map_data.placed_buildings, 
		active_astar_grid.region
	)
	
	EventBus.pathfinding_grid_updated.emit(Vector2i.ZERO)

func _apply_building_to_grid(entry: Dictionary, is_solid: bool) -> void:
	var path = entry.get("resource_path", "")
	if path == "": return
	
	var raw_pos = entry["grid_position"]
	var pos = Vector2i(raw_pos.x, raw_pos.y)
	
	var data = load(path) as BuildingData
	if not data: return
	
	if data.blocks_pathfinding:
		_mark_rect_solid(pos, data.grid_size, is_solid)

func _mark_rect_solid(top_left_pos: Vector2i, size: Vector2i, is_solid: bool) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var cell = top_left_pos + Vector2i(x, y)
			# Safe Set
			set_astar_point_solid(cell, is_solid)

# --- PUBLIC GRID API ---

## Main entry point for Spawners. Returns a safe World Position (CENTER of Tile).
func request_valid_spawn_point(target_world_pos: Vector2, max_search_radius: int = 3) -> Vector2:
	if not active_astar_grid: return target_world_pos
	
	var start_grid = world_to_grid(target_world_pos)
	
	# 1. Fast Check
	if _is_grid_point_valid(start_grid) and not active_astar_grid.is_point_solid(start_grid):
		return target_world_pos 
		
	# 2. Spiral Search
	for r in range(1, max_search_radius + 1):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if abs(x) != r and abs(y) != r: continue
				
				var check_pos = start_grid + Vector2i(x, y)
				if _is_grid_point_valid(check_pos) and not active_astar_grid.is_point_solid(check_pos):
					# [FIX] Return the center, not the top corner
					return get_tile_center(check_pos)
	
	Loggie.msg("Could not find valid spawn point near %s" % start_grid).domain(LogDomains.NAVIGATION).warn()
	return Vector2.INF

func is_tile_buildable(grid_pos: Vector2i) -> bool:
	return buildable_cells.has(grid_pos) and not active_astar_grid.is_point_solid(grid_pos)

func get_active_grid_cell_size() -> Vector2:
	return Vector2(TILE_WIDTH, TILE_HEIGHT)

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid): return PackedVector2Array()
	
	# 1. Convert World to Grid
	var start_grid = world_to_grid(start_pos)
	var end_grid = world_to_grid(end_pos)
	
	# 2. PROJECTION (The Standard Fix)
	# If the unit is on an invalid tile (Solid or OOB), find the nearest valid neighbor.
	if not is_tile_walkable(start_grid):
		start_grid = _get_closest_walkable_point(start_grid, 2)
		# If we still can't find a spot (e.g., trapped in a massive wall), fail gracefully
		if not is_tile_walkable(start_grid):
			Loggie.msg("Path failed: Unit trapped at %s" % start_grid).domain(LogDomains.NAVIGATION).warn()
			return PackedVector2Array()

	# 3. Target Validation
	# If the player clicks a wall/building, path to the nearest valid point (standard RTS behavior)
	if not is_tile_walkable(end_grid):
		end_grid = _get_closest_walkable_point(end_grid, 3)
		# If target is deep in void, return partial or empty based on flag
		if not is_tile_walkable(end_grid):
			return PackedVector2Array()

	# 4. Calculate Path
	var path = active_astar_grid.get_point_path(start_grid, end_grid, allow_partial_path)
	
	# 5. Path Smoothing (Visual Correction)
	# Snap the start/end exactly to world coordinates for smooth movement
	if path.size() > 0:
		path[0] = start_pos
		# Only snap end if we didn't have to project it too far
		if end_grid == world_to_grid(end_pos):
			path[path.size() - 1] = end_pos
		else:
			# If we projected the end (clicked a wall), use the center of the valid tile
			path[path.size() - 1] = get_tile_center(end_grid)
			
	return path

# --- HELPER: Projection Logic ---

func is_tile_walkable(grid_pos: Vector2i) -> bool:
	# Bounds check + Solid check
	if not is_instance_valid(active_astar_grid): return false
	if not active_astar_grid.region.has_point(grid_pos): return false
	return not active_astar_grid.is_point_solid(grid_pos)

func _get_closest_walkable_point(origin: Vector2i, max_radius: int) -> Vector2i:
	# 1. Check Origin first
	if is_tile_walkable(origin): return origin
	
	# 2. Spiral Search for nearest valid neighbor
	for r in range(1, max_radius + 1):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if abs(x) != r and abs(y) != r: continue # Only check outer ring
				
				var candidate = origin + Vector2i(x, y)
				if is_tile_walkable(candidate):
					return candidate
	
	# 3. Failed to find neighbor
	return origin

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	if _is_grid_point_valid(grid_position):
		active_astar_grid.set_point_solid(grid_position, solid)

func _is_grid_point_valid(grid_pos: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	return active_astar_grid.region.has_point(grid_pos)

# --- BUILDING PLACEMENT ---

func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	if not is_instance_valid(active_building_container): return null
	
	if not is_placement_valid(grid_position, building_data.grid_size, building_data): return null
	
	var new_building = building_data.scene_to_spawn.instantiate()
	
	# Assign Data
	new_building.data = building_data
	new_building.grid_coordinate = grid_position
	
	# --- FIX: ISOMETRIC CENTER CALCULATION ---
	# 1. Determine the "Center Point" of the building in Grid Coordinates
	#    (e.g., A 2x2 building at (0,0) has a center at (1.0, 1.0))
	var center_grid_x = float(grid_position.x) + (float(building_data.grid_size.x) / 2.0)
	var center_grid_y = float(grid_position.y) + (float(building_data.grid_size.y) / 2.0)
	
	# 2. Convert that Grid Center to World Pixels using Isometric Formula
	#    IsoX = (GridX - GridY) * TileHalfWidth
	#    IsoY = (GridX + GridY) * TileHalfHeight
	var final_x = (center_grid_x - center_grid_y) * TILE_HALF_SIZE.x
	var final_y = (center_grid_x + center_grid_y) * TILE_HALF_SIZE.y
	
	new_building.global_position = Vector2(final_x, final_y)
	# ----------------------------------------
	
	active_building_container.add_child(new_building)
	
	# Add to Data
	var entry = {
		"resource_path": building_data.resource_path,
		"grid_position": grid_position,
		"peasant_count": 0,
		"thrall_count": 0,
		"progress": 0
	}
	
	if active_map_data:
		if is_new_construction and building_data.construction_effort_required > 0:
			active_map_data.pending_construction_buildings.append(entry)
			new_building.set_state(BaseBuilding.BuildingState.BLUEPRINT)
			
			if active_map_data == current_settlement:
				save_settlement()
				
			Loggie.msg("New blueprint placed at %s." % grid_position).domain(LogDomains.SETTLEMENT).info()
		else:
			active_map_data.placed_buildings.append(entry)
			new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
			
		_refresh_grid_state()
	
	debug_validate_building_pos(new_building, grid_position)
	return new_building

func debug_validate_building_pos(building: Node2D, target_grid_pos: Vector2i) -> void:
	Loggie.msg("--- BUILDING PLACEMENT DIAGNOSTIC ---").domain(LogDomains.BUILD).info()
	
	# 1. CHECK INPUT DATA
	Loggie.msg("Target Grid: %s" % target_grid_pos).domain(LogDomains.BUILD).debug()
	
	# 2. CHECK MATH (Manual Recalculation)
	# Re-run the isometric formula manually to see if the code logic matches our expectation
	var cell_w = TILE_WIDTH
	var cell_h = TILE_HEIGHT
	var size = Vector2i(1,1)
	if "data" in building and building.data:
		size = building.data.grid_size
	
	# Calculate Center Grid Point
	var center_gx = float(target_grid_pos.x) + (float(size.x) / 2.0)
	var center_gy = float(target_grid_pos.y) + (float(size.y) / 2.0)
	
	# Isometric Projection
	var expected_x = (center_gx - center_gy) * (cell_w * 0.5)
	var expected_y = (center_gx + center_gy) * (cell_h * 0.5)
	var expected_pos = Vector2(expected_x, expected_y)
	
	Loggie.msg("Theoretical World Pos: %s" % expected_pos).domain(LogDomains.BUILD).debug()
	
	# 3. CHECK PARENT TRANSFORMS (Crucial!)
	# If the parent container is moved, the building will be offset globally
	var parent = building.get_parent()
	if parent:
		Loggie.msg("Parent (%s) Global Pos: %s" % [parent.name, parent.global_position]).domain(LogDomains.BUILD).debug()
		if parent.global_position != Vector2.ZERO:
			Loggie.msg("WARNING: Parent container is not at (0,0). This shifts all buildings!").domain(LogDomains.BUILD).warn()
	
	# 4. CHECK ACTUAL RESULT
	Loggie.msg("Actual Unit Global Pos: %s" % building.global_position).domain(LogDomains.BUILD).debug()
	
	# 5. CHECK DELTA
	var diff = building.global_position.distance_to(expected_pos)
	if diff > 1.0:
		Loggie.msg("CRITICAL MISMATCH: Visuals are %s pixels away from Logic!" % diff).domain(LogDomains.BUILD).error()
	else:
		Loggie.msg("Math verified. Visuals align with Logic.").domain(LogDomains.BUILD).info()
		
	# 6. CHECK BOUNDS
	if active_astar_grid:
		if not active_astar_grid.region.has_point(target_grid_pos):
			Loggie.msg("OUT OF BOUNDS: Grid %s is outside defined region %s" % [target_grid_pos, active_astar_grid.region]).domain(LogDomains.BUILD).error()

	Loggie.msg("---------------------------------------").domain(LogDomains.BUILD).info()

func remove_building(building_instance: BaseBuilding) -> void:
	if not active_map_data or not is_instance_valid(building_instance): return
	
	var cell_size = get_active_grid_cell_size()
	var top_left = building_instance.global_position - (Vector2(building_instance.data.grid_size) * cell_size / 2.0)
	var grid_pos = Vector2i(round(top_left.x / cell_size.x), round(top_left.y / cell_size.y))
	
	var removed_placed = _remove_from_list(active_map_data.placed_buildings, grid_pos)
	var removed_pending = _remove_from_list(active_map_data.pending_construction_buildings, grid_pos)
	
	if removed_placed or removed_pending:
		if active_map_data == current_settlement: save_settlement()
		_refresh_grid_state()
		
	building_instance.queue_free()

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry = list[i]
		var entry_pos = entry["grid_position"]
		if Vector2i(entry_pos.x, entry_pos.y) == grid_pos:
			list.remove_at(i)
			return true
	return false

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	if not GridUtils.is_area_clear(active_astar_grid, grid_position, building_size): return false
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

# --- SCENE MANAGEMENT ---

func register_active_scene_nodes(container: Node2D) -> void:
	active_building_container = container

func unregister_active_scene_nodes() -> void:
	active_building_container = null

# --- PERSISTENCE ---

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
	
	active_map_data = current_settlement
	EventBus.settlement_loaded.emit(current_settlement)
	_refresh_grid_state()

func _load_fallback_data(data: SettlementData) -> void:
	if data:
		current_settlement = data.duplicate(true)
		if current_settlement.warbands == null: current_settlement.warbands = []
		Loggie.msg("Loaded default template.").domain(LogDomains.SETTLEMENT).info()
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
	active_astar_grid = null
	active_building_container = null

func has_current_settlement() -> bool:
	return current_settlement != null
# --- ECONOMY & WORKERS ---
# (Keeping standard delegation functions unchanged)

func calculate_payout() -> Dictionary: return EconomyManager.calculate_payout()
func deposit_resources(loot: Dictionary) -> void: EconomyManager.deposit_resources(loot)
func attempt_purchase(item_cost: Dictionary) -> bool: return EconomyManager.attempt_purchase(item_cost)
func apply_raid_damages() -> Dictionary: return EconomyManager.apply_raid_damages()

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
	for entry in current_settlement.placed_buildings: employed += entry.get("peasant_count", 0)
	for entry in current_settlement.pending_construction_buildings: employed += entry.get("peasant_count", 0)
	return current_settlement.population_peasants - employed

func get_idle_thralls() -> int:
	if not current_settlement: return 0
	var employed = 0
	for entry in current_settlement.placed_buildings: employed += entry.get("thrall_count", 0)
	for entry in current_settlement.pending_construction_buildings: employed += entry.get("thrall_count", 0)
	return current_settlement.population_thralls - employed

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

func process_construction_labor() -> void:
	if not current_settlement: return
	var completed_indices: Array[int] = []
	for i in range(current_settlement.pending_construction_buildings.size()):
		var entry = current_settlement.pending_construction_buildings[i]
		var b_data = load(entry["resource_path"]) as BuildingData
		if not b_data: continue
		var peasants = entry.get("peasant_count", 0)
		var thralls = entry.get("thrall_count", 0)
		if peasants == 0 and thralls == 0: continue 
		var labor_points = (peasants + thralls) * EconomyManager.BUILDER_EFFICIENCY
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
	for i in completed_indices: current_settlement.pending_construction_buildings.remove_at(i)
	save_settlement()
	_refresh_grid_state()

func recruit_unit(unit_data: UnitData) -> void:
	if not current_settlement or not unit_data: return
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
	var cell_size = get_active_grid_cell_size()
	var half_size = (Vector2(building.data.grid_size) * cell_size) / 2.0
	var top_left = building.global_position - half_size
	var grid_pos = Vector2i(round(top_left.x / cell_size.x), round(top_left.y / cell_size.y))
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
	var cell_size = get_active_grid_cell_size()
	var size = Vector2i(1, 1)
	if "data" in building_instance and building_instance.data: size = building_instance.data.grid_size
	var grid_pos = Vector2i((building_instance.global_position - (Vector2(size) * cell_size / 2.0)) / cell_size)
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
