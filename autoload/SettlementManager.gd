extends Node

# --- Constants ---
const USER_SAVE_PATH := "user://savegame.tres"
const MAP_SAVE_PATH := "user://campaign_map.tres"

# --- Data State ---
var current_settlement: SettlementData # The Player's Home Economy (Always running)
var active_map_data: SettlementData    # The Map currently displayed (Home OR Raid Target)

# --- Grid Authority (Phase 1 Refactor) ---
var active_astar_grid: AStarGrid2D = null
var buildable_cells: Dictionary = {} # Cached territory map
# --- ISOMETRIC CONSTANTS ---
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF_SIZE = Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)

# 60x40 is a good size for this scale
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
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var x = (grid_pos.x - grid_pos.y) * TILE_HALF_SIZE.x
	var y = (grid_pos.x + grid_pos.y) * TILE_HALF_SIZE.y
	return Vector2(x, y)

# Convert World (Diamond) -> Grid (Square)
# Usage: var clicked_cell = world_to_grid(get_global_mouse_position())
func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Adjust for the center offset since (0,0) is the top tip
	var x = (world_pos.x / TILE_HALF_SIZE.x + world_pos.y / TILE_HALF_SIZE.y) / 2.0
	var y = (world_pos.y / TILE_HALF_SIZE.y - (world_pos.x / TILE_HALF_SIZE.x)) / 2.0
	return Vector2i(floor(x), floor(y))
	

func _init_grid() -> void:
	active_astar_grid = AStarGrid2D.new()
	active_astar_grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	
	# [FIX 1] Use the new Isometric Dimensions
	# Was: Vector2(CELL_SIZE_PX, CELL_SIZE_PX)
	active_astar_grid.cell_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	
	# [FIX 2] Tell AStar we are in Isometric Mode
	# This magically makes get_point_path() return the correct
	# Diamond World Coordinates instead of Square ones!
	active_astar_grid.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN
	
	# Keep this as is (Standard 4-way movement on the logical grid)
	active_astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	active_astar_grid.update()
	
	if NavigationManager:
		NavigationManager.register_grid(active_astar_grid, self)

func _refresh_grid_state() -> void:
	"""
	Rebuilds the navigation grid from scratch based on the ACTIVE map data.
	This ensures physics (Grid) always matches visuals (Data).
	"""
	if not active_astar_grid: _init_grid()
	
	# Safety Fallback: If no map is active, default to Home
	if not active_map_data and current_settlement:
		active_map_data = current_settlement
	
	if not active_map_data: return 

	# 1. Clear Grid Solids
	var region = active_astar_grid.region
	active_astar_grid.fill_solid_region(region, false)
	
	# 2. Mark Placed Buildings (Walls, Halls, etc)
	for entry in active_map_data.placed_buildings:
		_apply_building_to_grid(entry, true)
		
	# 3. Mark Pending Construction (Footprints are solid too!)
	for entry in active_map_data.pending_construction_buildings:
		_apply_building_to_grid(entry, true)
		
	# 4. Recalculate Territory (Buildable Green Tiles)
	# Note: We use the stateless GridUtils library for the math
	buildable_cells = GridUtils.calculate_territory(
		active_map_data.placed_buildings, 
		active_astar_grid.region
	)
	
	EventBus.pathfinding_grid_updated.emit(Vector2i.ZERO)

func _apply_building_to_grid(entry: Dictionary, is_solid: bool) -> void:
	var path = entry.get("resource_path", "")
	if path == "": return
	
	# Handle Vector2/Vector2i variance
	var raw_pos = entry["grid_position"]
	var pos = Vector2i(raw_pos.x, raw_pos.y)
	
	var data = load(path) as BuildingData
	if not data: return
	
	if data.blocks_pathfinding:
		_mark_rect_solid(pos, data.grid_size, is_solid)

func _mark_rect_solid(top_left_pos: Vector2i, size: Vector2i, is_solid: bool) -> void:
	for x in range(size.x):
		for y in range(size.y):
			# Simple addition: Start at Top-Left and iterate down/right
			var cell = top_left_pos + Vector2i(x, y)
			
			if GridUtils.is_within_bounds(active_astar_grid, cell):
				active_astar_grid.set_point_solid(cell, is_solid)

# --- PUBLIC GRID API ---

func is_tile_buildable(grid_pos: Vector2i) -> bool:
	return buildable_cells.has(grid_pos) and not active_astar_grid.is_point_solid(grid_pos)

func get_active_grid_cell_size() -> Vector2:
	return Vector2(TILE_WIDTH, TILE_HEIGHT)

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid): return PackedVector2Array()
	
	var cell_size = active_astar_grid.cell_size
	var start = Vector2i(start_pos / cell_size)
	var end = Vector2i(end_pos / cell_size)
	
	if not GridUtils.is_within_bounds(active_astar_grid, start): return PackedVector2Array()
	
	# Clamp end to bounds
	var bounds = active_astar_grid.region
	end.x = clampi(end.x, bounds.position.x, bounds.end.x - 1)
	end.y = clampi(end.y, bounds.position.y, bounds.end.y - 1)
	
	return active_astar_grid.get_point_path(start, end, allow_partial_path)

func set_astar_point_solid(grid_position: Vector2i, solid: bool) -> void:
	if is_instance_valid(active_astar_grid) and GridUtils.is_within_bounds(active_astar_grid, grid_position):
		active_astar_grid.set_point_solid(grid_position, solid)

# --- BUILDING PLACEMENT ---

func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	if not is_instance_valid(active_building_container): return null
	
	if not is_placement_valid(grid_position, building_data.grid_size, building_data): return null
	
	var new_building = building_data.scene_to_spawn.instantiate()
	
	# [FIX] Assign Data BEFORE adding to tree
	new_building.data = building_data
	new_building.grid_coordinate = grid_position
	
	var cell = get_active_grid_cell_size()
	var pos = Vector2(grid_position) * cell + (Vector2(building_data.grid_size) * cell / 2.0)
	new_building.global_position = pos
	
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
			
			# Save ONLY if we are at home (don't save Raid map state to user save)
			if active_map_data == current_settlement:
				save_settlement()
				
			Loggie.msg("New blueprint placed at %s." % grid_position).domain("SETTLEMENT").info()
		else:
			active_map_data.placed_buildings.append(entry)
			new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
			
		_refresh_grid_state() # Immediate Update
	
	return new_building

func remove_building(building_instance: BaseBuilding) -> void:
	if not active_map_data or not is_instance_valid(building_instance): return
	
	var cell_size = get_active_grid_cell_size()
	var top_left = building_instance.global_position - (Vector2(building_instance.data.grid_size) * cell_size / 2.0)
	var grid_pos = Vector2i(round(top_left.x / cell_size.x), round(top_left.y / cell_size.y))
	
	# Try removing from both lists
	var removed_placed = _remove_from_list(active_map_data.placed_buildings, grid_pos)
	var removed_pending = _remove_from_list(active_map_data.pending_construction_buildings, grid_pos)
	
	if removed_placed or removed_pending:
		if active_map_data == current_settlement:
			save_settlement()
		_refresh_grid_state()
		
	building_instance.queue_free()

func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
	for i in range(list.size()):
		var entry = list[i]
		var entry_pos = entry["grid_position"]
		var current_pos_i = Vector2i(entry_pos.x, entry_pos.y)
		
		if current_pos_i == grid_pos:
			list.remove_at(i)
			return true
	return false

func is_placement_valid(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	
	# Check Bounds & Solids
	if not GridUtils.is_area_clear(active_astar_grid, grid_position, building_size):
		return false
		
	# Check Economic Distance (District Logic)
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
	# If we have data loaded but no visuals yet, refresh grid to match


func unregister_active_scene_nodes() -> void:
	active_building_container = null

# --- PERSISTENCE ---

func load_settlement(data: SettlementData) -> void:
	# Load or Init Home Data
	if ResourceLoader.exists(USER_SAVE_PATH):
		var saved_data = load(USER_SAVE_PATH)
		if saved_data is SettlementData:
			current_settlement = saved_data
			Loggie.msg("Loaded user save from %s" % USER_SAVE_PATH).domain("SETTLEMENT").info()
		else:
			_load_fallback_data(data)
	else:
		_load_fallback_data(data)
	
	# Set Active Context to Home
	active_map_data = current_settlement
	
	EventBus.settlement_loaded.emit(current_settlement)
	_refresh_grid_state()

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

func delete_save_file() -> void:
	if FileAccess.file_exists(USER_SAVE_PATH):
		DirAccess.remove_absolute(USER_SAVE_PATH)
	if FileAccess.file_exists(MAP_SAVE_PATH):
		DirAccess.remove_absolute(MAP_SAVE_PATH)
	reset_manager_state()
	Loggie.msg("Save files deleted.").domain("SYSTEM").info()

func reset_manager_state() -> void:
	current_settlement = null
	active_map_data = null
	active_astar_grid = null
	active_building_container = null

func has_current_settlement() -> bool:
	return current_settlement != null

# --- ECONOMY DELEGATION (Unchanged) ---

func calculate_payout() -> Dictionary:
	return EconomyManager.calculate_payout()

func deposit_resources(loot: Dictionary) -> void:
	EconomyManager.deposit_resources(loot)

func attempt_purchase(item_cost: Dictionary) -> bool:
	return EconomyManager.attempt_purchase(item_cost)

func apply_raid_damages() -> Dictionary:
	return EconomyManager.apply_raid_damages()

func get_total_ship_capacity_squads() -> int:
	var total_capacity = 3
	if not current_settlement: return total_capacity
	for entry in current_settlement.placed_buildings:
		var data = load(entry["resource_path"]) as BuildingData
		if data:
			total_capacity += data.fleet_capacity_bonus
	return total_capacity

# --- WORKER & UNIT LOGIC (Unchanged) ---

func get_idle_peasants() -> int:
	if not current_settlement: return 0
	var employed = 0
	for entry in current_settlement.placed_buildings:
		employed += entry.get("peasant_count", 0)
	for entry in current_settlement.pending_construction_buildings:
		employed += entry.get("peasant_count", 0)
	return current_settlement.population_peasants - employed

func get_idle_thralls() -> int:
	if not current_settlement: return 0
	var employed = 0
	for entry in current_settlement.placed_buildings:
		employed += entry.get("thrall_count", 0)
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
	for i in completed_indices:
		current_settlement.pending_construction_buildings.remove_at(i)
		
	save_settlement()
	# Refresh grid to update territory from completed buildings
	_refresh_grid_state()

func complete_building_construction(building_instance: BaseBuilding) -> void:
	pass

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
			
	for bad_apple in deserters:
		current_settlement.warbands.erase(bad_apple)
	if not deserters.is_empty() or not warnings.is_empty():
		save_settlement()
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
	# 1. OPTIMIZATION: Check the Tag first (O(1) Lookup)
	if "grid_coordinate" in building:
		var tagged_pos = building.grid_coordinate
		if tagged_pos != Vector2i(-999, -999):
			# Search Placed
			for entry in current_settlement.placed_buildings:
				if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == tagged_pos:
					return entry
			# Search Pending
			for entry in current_settlement.pending_construction_buildings:
				if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == tagged_pos:
					return entry
	
	# 2. FALLBACK: Old Math (Only used if tag is missing/corrupted)
	var cell_size = get_active_grid_cell_size()
	var half_size = (Vector2(building.data.grid_size) * cell_size) / 2.0
	# Use round() to be safer with float errors
	var top_left = building.global_position - half_size
	var grid_pos = Vector2i(round(top_left.x / cell_size.x), round(top_left.y / cell_size.y))
	
	for entry in current_settlement.placed_buildings:
		if Vector2i(entry["grid_position"].x, entry["grid_position"].y) == grid_pos: 
			# Self-Repair: Fix the missing tag for next time
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

	# [FIX] Strict State Checking
	# Determine EXACTLY which list to search. Do not search both.
	var search_placed = true
	
	if "current_state" in building_instance:
		# If it is ANYTHING other than ACTIVE, it is a construction project.
		if building_instance.current_state != BaseBuilding.BuildingState.ACTIVE:
			search_placed = false
	
	var target_list = data_to_search.placed_buildings if search_placed else data_to_search.pending_construction_buildings

	# 1. OPTIMIZATION: Check the Tag
	if "grid_coordinate" in building_instance:
		var tagged_pos = building_instance.get("grid_coordinate")
		if tagged_pos != Vector2i(-999, -999):
			for i in range(target_list.size()):
				var entry = target_list[i]
				var pos = entry["grid_position"]
				if Vector2i(pos.x, pos.y) == tagged_pos:
					return i

	# 2. FALLBACK: Math
	var cell_size = get_active_grid_cell_size()
	var size = Vector2i(1, 1)
	if "data" in building_instance and building_instance.data:
		size = building_instance.data.grid_size
		
	var grid_pos = Vector2i((building_instance.global_position - (Vector2(size) * cell_size / 2.0)) / cell_size)
	
	# Only search the VALID list
	for i in range(target_list.size()):
		var entry = target_list[i]
		var pos = entry["grid_position"]
		if Vector2i(pos.x, pos.y) == grid_pos: 
			return i
			
	return -1

func queue_seasonal_recruit(unit_data: UnitData, count: int) -> void:
	for i in range(count):
		pending_seasonal_recruits.append(unit_data)

func commit_seasonal_recruits() -> void:
	"""
	Called when Winter Ends. 
	Converts pending individual recruits into consolidated Warbands.
	"""
	if pending_seasonal_recruits.is_empty(): return
	if not current_settlement: return
	
	var new_warbands: Array[WarbandData] = []
	var current_batch_wb: WarbandData = null
	
	# Iterate through every individual soldier promised
	for u_data in pending_seasonal_recruits:
		
		# 1. Do we need a new Warband?
		# (If we don't have one, or the current one is full, or the unit type doesn't match)
		if current_batch_wb == null or \
		   current_batch_wb.current_manpower >= WarbandData.MAX_MANPOWER or \
		   current_batch_wb.unit_type != u_data:
			
			# Create new Squad Container
			current_batch_wb = WarbandData.new(u_data)
			current_batch_wb.is_seasonal = true
			current_batch_wb.current_manpower = 0 # Start empty, add 1 below
			current_batch_wb.custom_name = "Drengir (%s)" % _generate_oath_name()
			current_batch_wb.add_history("Swore the oath at Yule")
			
			current_settlement.warbands.append(current_batch_wb)
			new_warbands.append(current_batch_wb)
		
		# 2. Add the man to the current squad
		current_batch_wb.current_manpower += 1
		
	Loggie.msg("Spring Arrival: %d men organized into %d Warbands." % [pending_seasonal_recruits.size(), new_warbands.size()]).domain("SETTLEMENT").info()
	pending_seasonal_recruits.clear()
	
	save_settlement()
	EventBus.settlement_loaded.emit(current_settlement)

func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
	return "The %s" % names.pick_random()
