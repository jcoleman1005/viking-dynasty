#res://scripts/buildings/SettlementBridge.gd
# res://scripts/buildings/SettlementBridge.gd
extends LevelBase

const MAP_WIDTH = 60
const MAP_HEIGHT = 60

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/MacroMap.tscn"

# --- REACTIVE DEBUG SETTINGS ---
@export_group("Loggie Debug Settings")
@export var show_ui_logs: bool = false:
	set(value):
		show_ui_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("UI", value)
@export var show_settlement_logs: bool = false:
	set(value):
		show_settlement_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("SETTLEMENT", value)
@export var show_building_logs: bool = false:
	set(value):
		show_building_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("BUILDING", value)
@export var show_debug_logs: bool = true:
	set(value):
		show_debug_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("DEBUG", value)
@export var show_raid_logs: bool = true:
	set(value):
		show_raid_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled(LogDomains.RAID, value)

# --- New Game Configuration ---
@export_group("New Game Settings")
@export var start_gold: int = 1000
@export var start_wood: int = 500
@export var start_food: int = 100
@export var start_stone: int = 200
@export var start_population: int = 10

# --- Default Assets ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_end_of_year_popup: PackedScene = preload("res://ui/EndOfYear_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var building_cursor: Node2D = $BuildingCursor

# --- Local Node References ---
@onready var building_container: Node2D = $BuildingContainer
@onready var rts_controller: RTSController = $RTSController
@onready var unit_spawner: UnitSpawner = $UnitSpawner

# --- UI State ---
var end_of_year_popup: PanelContainer

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null

func _ready() -> void:
	Loggie.set_domain_enabled("UI", show_ui_logs)
	Loggie.set_domain_enabled("SETTLEMENT", show_settlement_logs)
	Loggie.set_domain_enabled("BUILDING", show_building_logs)
	Loggie.set_domain_enabled("DEBUG", show_debug_logs)
	
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	
	if unit_spawner:
		unit_spawner.unit_container = unit_container
		unit_spawner.rts_controller = rts_controller
	
	# PRESERVED: Set default UI state BEFORE checking for raid results
	
	if end_of_year_popup: end_of_year_popup.hide()

	# PRESERVED: Test Data Injection
	if not DynastyManager.current_jarl:
		var test_jarl = DynastyTestDataGenerator.generate_test_dynasty()
		DynastyManager.current_jarl = test_jarl
		DynastyManager.jarl_stats_updated.emit(test_jarl)
	
	# Check for Raid Return via RaidManager
	if RaidManager.pending_raid_result != null:
		_process_raid_return()

	# PRESERVED: RTS Debug Connections
	if rts_controller and not EventBus.select_command.is_connected(rts_controller._on_select_command):
		print("DIAGNOSTIC: Forcing RTSController connections.")
		EventBus.select_command.connect(rts_controller._on_select_command)
		EventBus.move_command.connect(rts_controller._on_move_command)
		EventBus.attack_command.connect(rts_controller._on_attack_command)
		EventBus.interact_command.connect(rts_controller._on_interact_command)
	
func _exit_tree() -> void:
	# CRITICAL: When this node leaves the scene tree (scene change/quit),
	# we MUST release the Singleton's grip on our nodes.
	# Even with WeakRefs, this prevents logical state errors.
	if SettlementManager.active_building_container == $BuildingContainer:
		SettlementManager.unregister_active_scene_nodes()

func _connect_signals() -> void:
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.settlement_loaded.connect(_sync_villagers)
	
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	EventBus.building_right_clicked.connect(_on_building_right_clicked)
	EventBus.dynasty_view_requested.connect(_toggle_dynasty_view)
	
	EventBus.request_worker_assignment.connect(_on_worker_requested)
	EventBus.request_worker_removal.connect(_on_worker_removal_requested)

func _setup_default_resources() -> void:
	if not test_building_data: test_building_data = default_test_building
	if not raider_scene: raider_scene = load("res://scenes/units/VikingRaider.tscn")
	if not end_of_year_popup_scene: end_of_year_popup_scene = default_end_of_year_popup

func _setup_ui() -> void:
	# End Year Popup
	end_of_year_popup = end_of_year_popup_scene.instantiate()
	ui_layer.add_child(end_of_year_popup)
	end_of_year_popup.collect_button_pressed.connect(_on_payout_collected)

# =========================================================
# === WORKER ASSIGNMENT LOGIC ===
# =========================================================

func _on_worker_requested(target: BaseBuilding) -> void:
	var index = SettlementManager.get_building_index(target)
	if index == -1: 
		Loggie.msg("Building Index Not Found").domain("SETTLEMENT").error()
		return
	
	var is_construction = (target.current_state != BaseBuilding.BuildingState.ACTIVE)
	var entry
	
	if is_construction:
		entry = SettlementManager.current_settlement.pending_construction_buildings[index]
	else:
		entry = SettlementManager.current_settlement.placed_buildings[index]
	
	var current_count = entry.get("peasant_count", 0)
	var incoming_count = target.get_meta("incoming_workers", 0)
	var total_allocated = current_count + incoming_count
	
	var capacity = 0
	if is_construction:
		capacity = target.data.base_labor_capacity
	else:
		var eco_data = target.data as EconomicBuildingData
		if eco_data: capacity = eco_data.peasant_capacity
		
	if total_allocated >= capacity:
		EventBus.floating_text_requested.emit("Full (Incoming)", target.global_position, Color.RED)
		return

	if SettlementManager.get_idle_peasants() <= 0:
		EventBus.floating_text_requested.emit("No Peasants", target.global_position, Color.RED)
		return

	var civilians = get_tree().get_nodes_in_group("civilians")
	var nearest_civ: CivilianUnit = null
	var min_dist = INF
	
	for civ in civilians:
		if civ.has_meta("booked") or civ.is_queued_for_deletion(): continue
		
		if civ.fsm and civ.fsm.current_state == UnitAIConstants.State.IDLE:
			var dist = civ.global_position.distance_to(target.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_civ = civ
	
	if nearest_civ:
		nearest_civ.set_meta("booked", true)
		target.set_meta("incoming_workers", incoming_count + 1)
		
		var tween = create_tween()
		var walk_speed = 100.0
		var time = min_dist / walk_speed
		
		tween.tween_property(nearest_civ, "global_position", target.global_position, time)
		var civ_ref = weakref(nearest_civ)
		
		tween.tween_callback(func(): 
			var current_inc = target.get_meta("incoming_workers", 1)
			target.set_meta("incoming_workers", max(0, current_inc - 1))
			
			var civ = civ_ref.get_ref()
			if civ:
				_finalize_worker_assignment(target, civ)
			else:
				Loggie.msg("Worker died en route.").domain("SETTLEMENT").warn()
		)
	else:
		_finalize_worker_assignment(target, null)

func _finalize_worker_assignment(target: BaseBuilding, unit_node: Node2D) -> void:
	var index = SettlementManager.get_building_index(target)
	if index != -1:
		var is_construction = (target.current_state != BaseBuilding.BuildingState.ACTIVE)
		var entry
		if is_construction:
			entry = SettlementManager.current_settlement.pending_construction_buildings[index]
		else:
			entry = SettlementManager.current_settlement.placed_buildings[index]
			
		var current = entry.get("peasant_count", 0)
		var cap = target.data.base_labor_capacity if is_construction else (target.data as EconomicBuildingData).peasant_capacity
		
		if current < cap:
			if is_construction:
				SettlementManager.assign_construction_worker(index, "peasant", 1)
			else:
				SettlementManager.assign_worker(index, "peasant", 1)
				
			EventBus.floating_text_requested.emit("+1 Worker", target.global_position, Color.GREEN)
			
			if is_instance_valid(unit_node):
				unit_node.queue_free()
		else:
			Loggie.msg("Building full on arrival. Releasing unit.").domain("SETTLEMENT").warn()
			if is_instance_valid(unit_node):
				unit_node.set_meta("booked", null)
	else:
		if is_instance_valid(unit_node):
			unit_node.set_meta("booked", null)

	_force_inspector_refresh(target)

func _on_worker_removal_requested(target: BaseBuilding) -> void:
	var index = SettlementManager.get_building_index(target)
	if index == -1: return
	
	var entry
	var is_construction = (target.current_state != BaseBuilding.BuildingState.ACTIVE)
	
	if is_construction:
		entry = SettlementManager.current_settlement.pending_construction_buildings[index]
	else:
		entry = SettlementManager.current_settlement.placed_buildings[index]
		
	var current_workers = entry.get("peasant_count", 0)
	
	if current_workers > 0:
		if unit_spawner:
			var random_offset = Vector2(randf_range(-20, 20), randf_range(20, 40))
			var spawn_pos = target.global_position + random_offset
			unit_spawner.spawn_worker_at(spawn_pos)
			
		if is_construction:
			SettlementManager.assign_construction_worker(index, "peasant", -1)
		else:
			SettlementManager.assign_worker(index, "peasant", -1)
			
		EventBus.floating_text_requested.emit("Worker Removed", target.global_position, Color.YELLOW)
		_force_inspector_refresh(target)
	else:
		Loggie.msg("Cannot remove: 0 workers").domain("SETTLEMENT").warn()

func _force_inspector_refresh(target: BaseBuilding) -> void:
	var inspector = ui_layer.get_node_or_null("BuildingInspector")
	if inspector and inspector.visible and inspector.current_building == target:
		inspector.call("_refresh_data")

# =========================================================
# === WINTER PHASE TRANSITION ===
# =========================================================

func _on_payout_collected(payout: Dictionary) -> void:
	if payout.has("renown"):
		var amount = payout["renown"]
		if amount != 0:
			DynastyManager.award_renown(amount)
			var msg = "Renown %s %d (Loot Distribution)" % ["gained" if amount > 0 else "lost", abs(amount)]
			Loggie.msg(msg).domain(LogDomains.DYNASTY).info()
		payout.erase("renown")
	
	SettlementManager.deposit_resources(payout)
	
	# Reset Managers
	RaidManager.pending_raid_result = null
	
	

func _close_all_popups() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui: dynasty_ui.hide()
	if end_of_year_popup: end_of_year_popup.hide()

func _clear_all_buildings() -> void:
	if is_instance_valid(building_container):
		for child in building_container.get_children(): child.queue_free()
		await get_tree().process_frame
	
	if is_instance_valid(unit_container):
		for child in unit_container.get_children(): child.queue_free()
		await get_tree().process_frame
	
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.placed_buildings.clear()
		SettlementManager.current_settlement.pending_construction_buildings.clear()
		SettlementManager.current_settlement.warbands.clear()
		SettlementManager._refresh_grid_state()
	
	great_hall_instance = null
	game_is_over = false
	awaiting_placement = null

func _initialize_settlement() -> void:
	# 1. SETUP DATA
	home_base_data = _create_default_settlement() 
	SettlementManager.register_active_scene_nodes(building_container)
	SettlementManager.load_settlement(home_base_data) 
	home_base_data = SettlementManager.current_settlement 

	# 2. GENERATE TERRAIN
	# We must generate the visual tiles before we can scan them for navigation.
	if has_node("TileMapLayer"):
		TerrainGenerator.generate_base_terrain(
			$TileMapLayer,
			MAP_WIDTH, # Or use a constant from a global config
			MAP_HEIGHT,
			home_base_data.map_seed 
		)

	# This calls the function in LevelBase.gd
	# It handles the wait time AND the NavigationManager setup for you.
	await setup_level_navigation(
		$TileMapLayer, 
		MAP_WIDTH, 
		MAP_HEIGHT
	)
	
	NavigationManager.initialize_grid_from_tilemap(
		$TileMapLayer,
		Vector2i(MAP_WIDTH, MAP_HEIGHT),
		Vector2i(64, 32) # Your Tile Dimensions
	)
	
	# 5. SPAWN BUILDINGS
	# This will automatically punch holes in the Navigation Grid we just made.
	_spawn_placed_buildings()
	# 6. SPAWN UNITS
	# Now they can safely request spawn points because the grid is ready.
	_sync_villagers()
	_spawn_player_garrison()
	
func _spawn_placed_buildings() -> void:
	if not SettlementManager.current_settlement: return
	
	for child in building_container.get_children(): child.queue_free()
	great_hall_instance = null 
	
	for building_entry in SettlementManager.current_settlement.placed_buildings:
		var b = _spawn_single_building(building_entry, false) 
		if b and b.data.is_territory_hub: 
			great_hall_instance = b
			print("SettlementBridge: Great Hall registered at ", b.global_position)
		
	for building_entry in SettlementManager.current_settlement.pending_construction_buildings:
		var b = _spawn_single_building(building_entry, true)
		if b:
			var progress = building_entry.get("progress", 0)
			if progress > 0:
				b.construction_progress = progress
				b.set_state(BaseBuilding.BuildingState.UNDER_CONSTRUCTION)
				if b.has_method("update_visual_state"): b.update_visual_state() 
			else:
				b.set_state(BaseBuilding.BuildingState.BLUEPRINT)
	
	if unit_spawner: unit_spawner.clear_units()
	

func _spawn_single_building(entry: Dictionary, is_new: bool) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var grid_pos = Vector2i(entry["grid_position"].x, entry["grid_position"].y)
	var building_data = load(res_path) as BuildingData
	
	if not building_data: return null

	var new_building = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	new_building.grid_coordinate = grid_pos
	
	# --- FIX: ISOMETRIC POSITIONING ---
	# 1. Calculate the logical center of the building on the grid
	var center_grid_x = float(grid_pos.x) + (float(building_data.grid_size.x) / 2.0)
	var center_grid_y = float(grid_pos.y) + (float(building_data.grid_size.y) / 2.0)
	
	# 2. Convert Grid Center -> World Pixels (Isometric Formula)
	#    Formula matches SettlementManager.place_building logic
	var final_x = (center_grid_x - center_grid_y) * SettlementManager.TILE_HALF_SIZE.x
	var final_y = (center_grid_x + center_grid_y) * SettlementManager.TILE_HALF_SIZE.y
	
	new_building.global_position = Vector2(final_x, final_y)
	# ----------------------------------
	
	building_container.add_child(new_building)
	
	if is_new:
		new_building.set_state(BaseBuilding.BuildingState.UNDER_CONSTRUCTION)
	else:
		new_building.set_state(BaseBuilding.BuildingState.ACTIVE)
		
	return new_building

func _create_default_settlement() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = { "gold": start_gold, "wood": start_wood, "food": start_food, "stone": start_stone }
	settlement.population_peasants = start_population
	settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
	var great_hall_entry = { "resource_path": "res://data/buildings/GreatHall.tres", "grid_position": Vector2i(28, 18) }
	settlement.placed_buildings.append(great_hall_entry)
	return settlement

func _on_settlement_loaded(_settlement_data: SettlementData) -> void:
	pass

func _setup_great_hall(hall_instance: BaseBuilding) -> void:
	if not is_instance_valid(hall_instance): return
	great_hall_instance = hall_instance
	great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)

func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
	game_is_over = true
	if is_instance_valid(unit_container):
		for enemy in unit_container.get_children(): enemy.queue_free()

func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	awaiting_placement = building_data
	building_cursor.set_building_preview(building_data)

func _on_building_placement_cancelled(_building_data: BuildingData) -> void: pass

func _on_building_placement_completed() -> void:
	if awaiting_placement and SettlementManager.current_settlement:
		# --- FIX: Use Manager API for Coordinate Conversion ---
		# This handles the Isometric Math automatically
		var grid_pos = SettlementManager.world_to_grid(building_cursor.global_position)
		SettlementManager.place_building(awaiting_placement, grid_pos, true)
	awaiting_placement = null

func _on_building_placement_cancelled_by_cursor() -> void:
	if awaiting_placement:
		SettlementManager.deposit_resources(awaiting_placement.build_cost)
		awaiting_placement = null

func _on_building_right_clicked(building: BaseBuilding) -> void:
	if building_cursor.is_active: return
	var data = building.data
	var cost = data.build_cost
	SettlementManager.deposit_resources(cost)
	SettlementManager.remove_building(building)
	if SettlementManager.attempt_purchase(cost):
		EventBus.building_ready_for_placement.emit(data)

# --- Process Raid Return ---
func _process_raid_return() -> void:
	if RaidManager.pending_raid_result == null:
		return
		
	var result: RaidResultData = RaidManager.pending_raid_result
	var outcome = result.outcome
	
	Loggie.msg("Processing Raid Return: %s" % outcome).domain(LogDomains.SETTLEMENT).info()
	
	var raw_gold = result.loot.get("gold", 0)
	var total_wergild = 0
	var dead_count = 0
	
	for u_data in result.casualties:
		if u_data:
			total_wergild += u_data.wergild_cost
			dead_count += 1
	
	var net_gold = max(0, raw_gold - total_wergild)
	
	if outcome == "victory":
		RaidManager.last_raid_outcome = "victory"
	elif outcome == "retreat":
		RaidManager.last_raid_outcome = "defeat"
	else:
		RaidManager.last_raid_outcome = "neutral"
		
	if SettlementManager.current_settlement:
		var warbands_to_disband: Array[WarbandData] = []
		
		for warband in SettlementManager.current_settlement.warbands:
			if warband.is_bondi or warband.is_seasonal:
				if warband.is_bondi and warband.current_manpower > 0:
					SettlementManager.current_settlement.population_peasants += warband.current_manpower
					Loggie.msg("Bondi returned to fields.").domain("SETTLEMENT").info()
				
				if warband.is_seasonal:
					Loggie.msg("Seasonal Drengir have departed.").domain("SETTLEMENT").info()
				
				warbands_to_disband.append(warband)
		
		for wb in warbands_to_disband:
			SettlementManager.current_settlement.warbands.erase(wb)
			
		_sync_villagers()

	var grade = result.victory_grade
	var xp_gain = 0
	
	if outcome == "victory": 
		xp_gain = 50
		if grade == "Decisive": xp_gain = 75
		elif grade == "Pyrrhic": xp_gain = 25
	elif outcome == "retreat": 
		xp_gain = 20
	
	if xp_gain > 0 and DynastyManager.active_year_modifiers.has("BLOT_ODIN"):
		xp_gain = int(xp_gain * 1.5)
		
	if SettlementManager.current_settlement and xp_gain > 0:
		for warband in SettlementManager.current_settlement.warbands:
			if not warband.is_wounded:
				warband.experience += xp_gain

	var loot_summary = result.loot.duplicate()
	loot_summary["gold"] = net_gold
	
	var title_text = "Raid Result"
	
	if outcome == "victory":
		var difficulty = RaidManager.current_raid_difficulty
		var bonus = 200 + (difficulty * 50)
		if grade == "Decisive": bonus += 100
		
		loot_summary["gold"] = net_gold + bonus
		
		if not loot_summary.has("thrall"):
			loot_summary["population"] = randi_range(2, 4) * difficulty
		
		title_text = "Victory! (%s)" % grade
		
		var jarl = DynastyManager.get_current_jarl()
		if jarl:
			jarl.offensive_wins += 1
			jarl.battles_won += 1
			jarl.successful_raids += 1
			if jarl.has_trait("Warlord") and grade == "Decisive":
				DynastyManager.current_jarl.current_authority += 1
			DynastyManager.jarl_stats_updated.emit(jarl)
			
	elif outcome == "retreat":
		title_text = "Retreat"
		var total_loot_count = 0
		for k in loot_summary:
			if k != "gold": total_loot_count += loot_summary[k]
		total_loot_count += net_gold
		
		if total_loot_count > 0:
			title_text += "\n(Loot Secured)"
		else:
			title_text += "\n(Empty Handed)"

	if dead_count > 0:
		title_text += "\n(Wergild Paid: -%d Gold)" % total_wergild

	if result.renown_earned != 0:
		loot_summary["renown"] = result.renown_earned

	if not is_instance_valid(end_of_year_popup):
		var popup = default_end_of_year_popup.instantiate()
		ui_layer.add_child(popup)
		end_of_year_popup = popup
		
	end_of_year_popup.display_payout(loot_summary, title_text)
	
	RaidManager.pending_raid_result = null
	RaidManager.reset_raid_state()
	
func _sync_villagers(_data: SettlementData = null) -> void:
	if not SettlementManager.has_current_settlement(): return
	if not is_instance_valid(great_hall_instance): return
	if not unit_spawner: return
	
	var idle_count = SettlementManager.get_idle_peasants()
	var origin = great_hall_instance.global_position
	
	unit_spawner.sync_civilians(idle_count, origin)

func _toggle_dynasty_view() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui:
		if dynasty_ui.visible:
			dynasty_ui.hide()
		else:
			 
			dynasty_ui.show()
			Loggie.msg("Opening Dynasty View").domain("UI").info()
	else:
		Loggie.msg("Error: Dynasty_UI node not found in SettlementBridge/UI").domain("UI").error()

func _spawn_player_garrison() -> void:
	if not SettlementManager.has_current_settlement(): return
	if not is_instance_valid(great_hall_instance): return
	if not unit_spawner: return
	
	var warbands = SettlementManager.current_settlement.warbands
	var origin = great_hall_instance.global_position
	
	unit_spawner.spawn_garrison(warbands, origin)
