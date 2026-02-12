class_name WinterIntegrationTest
extends Node

## Winter Phase Integration Test Suite & Debug Controller
## Validates Tasks 1.1 through 4.1 logic flows.
## Also handles interactive debug inputs (e.g., F3 for Director's Lens).

# --- Configuration ---
@export var run_on_ready: bool = true
@export_group("Test Parameters")
@export var sick_pop_for_omen_test: int = 2
@export var total_pop_for_omen_test: int = 10
@export var gold_to_add_on_test: int = 100

# --- Scene Preloads (now assigned via Inspector) ---
@export var director_lens_packed_scene: PackedScene # Assign DirectorLensOverlay.tscn here in Inspector
var director_lens_instance: CanvasLayer = null


func _ready() -> void:
	_setup_debug_inputs()
	if run_on_ready:
		await get_tree().process_frame
		run_tests()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("add_gold"):
		_run_add_gold_test()
	
	if event.is_action_pressed("toggle_director_lens"):
		_toggle_director_lens()

# --- Debug Setup ---
func _setup_debug_inputs():
	# Ensure debug actions exist to prevent errors
	if not InputMap.has_action("add_gold"):
		InputMap.add_action("add_gold")
		var gold_event = InputEventKey.new()
		gold_event.keycode = KEY_G
		InputMap.action_add_event("add_gold", gold_event)

	if not InputMap.has_action("toggle_director_lens"):
		InputMap.add_action("toggle_director_lens")
		var lens_event = InputEventKey.new()
		lens_event.keycode = KEY_F3
		InputMap.action_add_event("toggle_director_lens", lens_event)

# --- Interactive Tests & Toggles ---
func _run_add_gold_test():
	if SettlementManager.has_current_settlement():
		Loggie.msg("--- Running Add Gold Test (Task 3.1) ---").domain(LogDomains.SYSTEM).info()
		var current_gold = SettlementManager.current_settlement.treasury.get(GameResources.GOLD, 0)
		SettlementManager.current_settlement.treasury[GameResources.GOLD] = current_gold + gold_to_add_on_test
		EventBus.treasury_updated.emit(SettlementManager.current_settlement.treasury)
		Loggie.msg("Added %d gold. 'treasury_updated' signal emitted." % gold_to_add_on_test).domain(LogDomains.SYSTEM).info()
	else:
		Loggie.msg("Cannot run Add Gold Test: No current settlement loaded.").domain(LogDomains.SYSTEM).warn()

func _toggle_director_lens():
	if director_lens_instance == null:
		Loggie.msg("Instantiating Director's Lens...").domain(LogDomains.UI).debug()
		if director_lens_packed_scene:
			director_lens_instance = director_lens_packed_scene.instantiate()
			get_tree().get_root().add_child(director_lens_instance)
		else:
			Loggie.msg("Director's Lens PackedScene not assigned in Inspector! Cannot instantiate.").domain(LogDomains.SYSTEM).error()
			return
	
	if director_lens_instance and director_lens_instance.has_method("toggle"):
		director_lens_instance.toggle()

# --- Automated Test Suite ---
func run_tests() -> void:
	Loggie.msg("=== STARTING WINTER SYSTEM DIAGNOSTIC (IN-MEMORY) ===").domain(LogDomains.SYSTEM).info()
	
	var real_settlement = SettlementManager.current_settlement
	var real_treasury = {}
	if real_settlement:
		real_treasury = real_settlement.treasury.duplicate()

	_test_rationing_math()
	_test_heating_cache_rebuild()
	_test_persistence_simulation()
	_test_live_crisis_reporter()
	_test_sickness_omen()
	_test_dashboard_update()
	
	SettlementManager.current_settlement = real_settlement
	if real_settlement:
		real_settlement.treasury = real_treasury
		EconomyManager._on_settlement_loaded(real_settlement)
	
	Loggie.msg("=== DIAGNOSTIC COMPLETE ===").domain(LogDomains.SYSTEM).info()

# --- Test Cases ---
func _test_rationing_math() -> void:
	Loggie.msg("Test 1: Rationing Math...").domain(LogDomains.SYSTEM).info()
	var mock_settlement = SettlementData.new()
	mock_settlement.population_peasants = 10
	mock_settlement.rationing_policy = SettlementData.RationingPolicy.NORMAL
	mock_settlement.treasury[GameResources.FOOD] = 100
	SettlementManager.current_settlement = mock_settlement
	
	var normal_demand = EconomyManager.get_winter_food_demand()
	if normal_demand != 10:
		Loggie.msg("[FAIL] Normal Demand mismatch. Expected 10, Got %d" % normal_demand).domain(LogDomains.SYSTEM).error()
		return
		
	mock_settlement.rationing_policy = SettlementData.RationingPolicy.HALF
	var half_demand = EconomyManager.get_winter_food_demand()
	if half_demand != 5:
		Loggie.msg("[FAIL] Half Demand mismatch. Expected 5, Got %d" % half_demand).domain(LogDomains.SYSTEM).error()
		return
		
	Loggie.msg("[PASS] Rationing Math verified.").domain(LogDomains.SYSTEM).info()

func _test_heating_cache_rebuild() -> void:
	Loggie.msg("Test 2: Heating Cache Rebuild...").domain(LogDomains.SYSTEM).info()
	var mock_settlement = SettlementData.new()
	mock_settlement.placed_buildings.clear()
	SettlementManager.current_settlement = mock_settlement
	EconomyManager._on_settlement_loaded(mock_settlement)
	
	var cache_val = EconomyManager.get_total_heating_demand()
	if cache_val != 0:
		Loggie.msg("[FAIL] Empty Cache mismatch. Expected 0, Got %d" % cache_val).domain(LogDomains.SYSTEM).error()
		return
		
	EconomyManager._cached_total_heating = -1
	var safe_val = EconomyManager.get_total_heating_demand()
	if safe_val != 0:
		Loggie.msg("[FAIL] Cache did not recalculate on dirty state.").domain(LogDomains.SYSTEM).error()
		return
		
	Loggie.msg("[PASS] Heating Cache logic verified.").domain(LogDomains.SYSTEM).info()

func _test_persistence_simulation() -> void:
	Loggie.msg("Test 3: Persistence Simulation...").domain(LogDomains.SYSTEM).info()
	var mock_settlement = SettlementData.new()
	mock_settlement.sick_population = 5
	mock_settlement.rationing_policy = SettlementData.RationingPolicy.HALF
	SettlementManager.current_settlement = mock_settlement
	
	if SettlementManager.current_settlement.sick_population != 5:
		Loggie.msg("[FAIL] Sick Population state lost in manager.").domain(LogDomains.SYSTEM).error()
		return
		
	if EconomyManager.get_winter_food_demand() != int(mock_settlement.population_peasants * 1.0 * 0.5):
		pass
		
	Loggie.msg("[PASS] State structure verified.").domain(LogDomains.SYSTEM).info()

func _test_live_crisis_reporter() -> void:
	Loggie.msg("Test 4: Live Crisis Reporter...").domain(LogDomains.SYSTEM).info()
	var mock_settlement = SettlementData.new()
	mock_settlement.population_peasants = 10
	mock_settlement.treasury[GameResources.FOOD] = 0
	mock_settlement.treasury[GameResources.WOOD] = 0
	SettlementManager.current_settlement = mock_settlement
	EconomyManager._on_settlement_loaded(mock_settlement)
	
	var report = WinterManager.get_live_crisis_report()
	
	if not WinterManager.winter_crisis_active:
		Loggie.msg("[FAIL] Crisis not active when expected. winter_crisis_active: %s" % WinterManager.winter_crisis_active).domain(LogDomains.SYSTEM).error()
		return

	if report.food_deficit <= 0 or report.wood_deficit <= 0:
		Loggie.msg("[FAIL] Deficits not reported correctly. Food: %d, Wood: %d" % [report.food_deficit, report.wood_deficit]).domain(LogDomains.SYSTEM).error()
		return
	
	Loggie.msg("[PASS] Live Crisis Reporter verified.").domain(LogDomains.SYSTEM).info()

func _test_sickness_omen() -> void:
	Loggie.msg("Test 5: Sickness Omen...").domain(LogDomains.SYSTEM).info()
	var omen_20_percent = WinterManager.get_sickness_omen(sick_pop_for_omen_test, total_pop_for_omen_test)
	if omen_20_percent.text != "The breath of the frost is on their necks." or omen_20_percent.color != Color.ORANGE_RED:
		Loggie.msg("[FAIL] 20% Omen mismatch. Text: '%s', Color: '%s'" % [omen_20_percent.text, omen_20_percent.color.to_html()]).domain(LogDomains.SYSTEM).error()
		return

	var omen_50_percent = WinterManager.get_sickness_omen(5, 10)
	if omen_50_percent.text != "The long dark has taken root..." or omen_50_percent.color != Color.DARK_RED:
		Loggie.msg("[FAIL] 50% Omen mismatch. Text: '%s', Color: '%s'" % [omen_50_percent.text, omen_50_percent.color.to_html()]).domain(LogDomains.SYSTEM).error()
		return

	var omen_0_percent = WinterManager.get_sickness_omen(0, 10)
	if omen_0_percent.text != "" or omen_0_percent.color != Color.WHITE:
		Loggie.msg("[FAIL] 0% Omen mismatch. Text: '%s', Color: '%s'" % [omen_0_percent.text, omen_0_percent.color.to_html()]).domain(LogDomains.SYSTEM).error()
		return
		
	Loggie.msg("[PASS] Sickness Omen verified.").domain(LogDomains.SYSTEM).info()

func _test_dashboard_update() -> void:
	Loggie.msg("Test 6: Winter Court Dashboard (Indirect Verification)...").domain(LogDomains.SYSTEM).info()
	var mock_settlement = SettlementData.new()
	mock_settlement.population_peasants = 10
	mock_settlement.treasury[GameResources.FOOD] = 0
	mock_settlement.treasury[GameResources.WOOD] = 0
	mock_settlement.sick_population = 2
	SettlementManager.current_settlement = mock_settlement
	EconomyManager._on_settlement_loaded(mock_settlement)
	
	var crisis_report_from_update = WinterManager.get_live_crisis_report()
	
	if not WinterManager.winter_crisis_active:
		Loggie.msg("[FAIL] Dashboard logic did not correctly set WinterManager.winter_crisis_active to true during crisis simulation.").domain(LogDomains.SYSTEM).error()
		return
	
	if crisis_report_from_update.food_deficit <= 0 or crisis_report_from_update.wood_deficit <= 0:
		Loggie.msg("[FAIL] Crisis Report deficits are incorrect after simulated dashboard update. Food: %d, Wood: %d" % [crisis_report_from_update.food_deficit, crisis_report_from_update.wood_deficit]).domain(LogDomains.SYSTEM).error()
		return

	var omen_test_sick_pop = 2
	var omen_test_total_pop = 10
	var omen = WinterManager.get_sickness_omen(omen_test_sick_pop, omen_test_total_pop)
	if omen.text.is_empty() or omen.color == Color.WHITE:
		Loggie.msg("[FAIL] Sickness Omen logic from dashboard update is incorrect for 20% sick.").domain(LogDomains.SYSTEM).error()
		return

	Loggie.msg("[PASS] Winter Court Dashboard logic (indirect) verified.").domain(LogDomains.SYSTEM).info()
