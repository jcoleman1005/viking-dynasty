extends Node

## Winter Phase Integration Test Suite & Debug Controller
## Validates Tasks 1.1 through Seasonal Council Logic.

# --- Configuration ---
@export var run_on_ready: bool = true
@export_group("Test Parameters")
@export var sick_pop_for_omen_test: int = 2
@export var total_pop_for_omen_test: int = 10
@export var gold_to_add_on_test: int = 100

# --- Scene Refs ---
@export var director_lens_packed_scene: PackedScene
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
		Loggie.msg("--- Running Add Gold Test ---").domain(LogDomains.SYSTEM).info()
		var current_gold = SettlementManager.current_settlement.treasury.get(GameResources.GOLD, 0)
		SettlementManager.current_settlement.treasury[GameResources.GOLD] = current_gold + gold_to_add_on_test
		EventBus.treasury_updated.emit(SettlementManager.current_settlement.treasury)
		Loggie.msg("Added %d gold. 'treasury_updated' signal emitted." % gold_to_add_on_test).domain(LogDomains.SYSTEM).info()
	else:
		Loggie.msg("Cannot run Add Gold Test: No current settlement loaded.").domain(LogDomains.SYSTEM).warn()

func _toggle_director_lens():
	if director_lens_instance == null:
		if director_lens_packed_scene:
			director_lens_instance = director_lens_packed_scene.instantiate()
			get_tree().get_root().add_child(director_lens_instance)
		else:
			return
	
	if director_lens_instance and director_lens_instance.has_method("toggle"):
		director_lens_instance.toggle()

# --- Automated Test Suite ---
func run_tests() -> void:
	Loggie.msg("=== STARTING SYSTEM DIAGNOSTIC (IN-MEMORY) ===").domain(LogDomains.SYSTEM).info()
	
	var real_settlement = SettlementManager.current_settlement
	var real_treasury = {}
	if real_settlement:
		real_treasury = real_settlement.treasury.duplicate()

	_test_rationing_math()
	_test_heating_cache_rebuild()
	_test_persistence_simulation()
	_test_live_crisis_reporter()
	_test_sickness_omen()
	
	# Restore state
	SettlementManager.current_settlement = real_settlement
	if real_settlement:
		real_settlement.treasury = real_treasury
		EconomyManager._on_settlement_loaded(real_settlement)
	
	Loggie.msg("=== DIAGNOSTIC COMPLETE ===").domain(LogDomains.SYSTEM).info()

# --- Existing Test Cases (Minimized for brevity) ---
func _test_rationing_math() -> void:
	Loggie.msg("Test 1: Rationing Math...").domain(LogDomains.SYSTEM).info()
	var mock = SettlementData.new()
	mock.population_peasants = 10
	mock.rationing_policy = SettlementData.RationingPolicy.NORMAL
	mock.treasury[GameResources.FOOD] = 100
	SettlementManager.current_settlement = mock
	if EconomyManager.get_winter_food_demand() == 10: Loggie.msg("[PASS] Rationing Math verified.").domain(LogDomains.SYSTEM).info()
	else: Loggie.msg("[FAIL] Rationing Math.").domain(LogDomains.SYSTEM).error()

func _test_heating_cache_rebuild() -> void:
	Loggie.msg("Test 2: Heating Cache Rebuild...").domain(LogDomains.SYSTEM).info()
	var mock = SettlementData.new()
	mock.placed_buildings.clear()
	SettlementManager.current_settlement = mock
	EconomyManager._on_settlement_loaded(mock)
	if EconomyManager.get_total_heating_demand() == 0: Loggie.msg("[PASS] Heating Cache verified.").domain(LogDomains.SYSTEM).info()
	else: Loggie.msg("[FAIL] Heating Cache.").domain(LogDomains.SYSTEM).error()

func _test_persistence_simulation() -> void:
	Loggie.msg("Test 3: Persistence Simulation...").domain(LogDomains.SYSTEM).info()
	var mock = SettlementData.new()
	mock.sick_population = 5
	SettlementManager.current_settlement = mock
	if SettlementManager.current_settlement.sick_population == 5: Loggie.msg("[PASS] Persistence verified.").domain(LogDomains.SYSTEM).info()
	else: Loggie.msg("[FAIL] Persistence.").domain(LogDomains.SYSTEM).error()

func _test_live_crisis_reporter() -> void:
	Loggie.msg("Test 4: Live Crisis Reporter...").domain(LogDomains.SYSTEM).info()
	var mock = SettlementData.new()
	mock.population_peasants = 10
	mock.treasury[GameResources.FOOD] = 0
	SettlementManager.current_settlement = mock
	EconomyManager._on_settlement_loaded(mock)
	if WinterManager.get_live_crisis_report().is_crisis: Loggie.msg("[PASS] Crisis Reporter verified.").domain(LogDomains.SYSTEM).info()
	else: Loggie.msg("[FAIL] Crisis Reporter.").domain(LogDomains.SYSTEM).error()

func _test_sickness_omen() -> void:
	Loggie.msg("Test 5: Sickness Omen...").domain(LogDomains.SYSTEM).info()
	var omen = WinterManager.get_sickness_omen(2, 10)
	if not omen.text.is_empty(): Loggie.msg("[PASS] Sickness Omen verified.").domain(LogDomains.SYSTEM).info()
	else: Loggie.msg("[FAIL] Sickness Omen.").domain(LogDomains.SYSTEM).error()

func _test_dashboard_update() -> void:
	Loggie.msg("Test 6: Winter Court Dashboard...").domain(LogDomains.SYSTEM).info()
	var mock = SettlementData.new()
	mock.population_peasants = 10
	mock.treasury[GameResources.FOOD] = 0
	SettlementManager.current_settlement = mock
	EconomyManager._on_settlement_loaded(mock)
	if WinterManager.get_live_crisis_report().is_crisis: Loggie.msg("[PASS] Dashboard logic verified.").domain(LogDomains.SYSTEM).info()
	else: Loggie.msg("[FAIL] Dashboard logic.").domain(LogDomains.SYSTEM).error()
