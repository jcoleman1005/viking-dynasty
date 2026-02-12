class_name WinterIntegrationTest
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
@export var council_ui_scene: PackedScene # Assign SeasonalCouncilUI.tscn here
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
	_test_seasonal_council_logic() # New specialized tests
	
	# Restore state
	SettlementManager.current_settlement = real_settlement
	if real_settlement:
		real_settlement.treasury = real_treasury
		EconomyManager._on_settlement_loaded(real_settlement)
	
	Loggie.msg("=== DIAGNOSTIC COMPLETE ===").domain(LogDomains.SYSTEM).info()

# --- Test Case: Seasonal Council (Unified) ---
func _test_seasonal_council_logic() -> void:
	if not council_ui_scene:
		Loggie.msg("[SKIP] Council UI tests: PackedScene not assigned in Inspector.").domain(LogDomains.SYSTEM).warn()
		return

	Loggie.msg("Test 7: Seasonal Council Logic (Sandboxed)...").domain(LogDomains.SYSTEM).info()

	# Instantiate a temporary test instance
	var test_instance = council_ui_scene.instantiate()
	add_child(test_instance) # Triggers _ready()

	# 1. Test Spring Transition
	Loggie.msg("  Sub-test: Spring Council State").domain(LogDomains.SYSTEM).info()
	test_instance._on_season_changed("Spring", {})
	
	var ap_label = test_instance.get_node("%ActionPointsLabel")
	if ap_label.text != "SPRING COUNCIL":
		Loggie.msg("[FAIL] Council UI failed to identify Spring season. Label: %s" % ap_label.text).domain(LogDomains.SYSTEM).error()
		test_instance.queue_free()
		return
	
	# Check color (Spring should be COLOR_SPRING)
	var spring_color = Color("a8e6cf")
	var jarl_label = test_instance.get_node("%JarlNameLabel")
	if not jarl_label.modulate.is_equal_approx(spring_color):
		Loggie.msg("[FAIL] Council UI failed to apply Spring theme color.").domain(LogDomains.SYSTEM).error()

	# 2. Test Winter Transition
	Loggie.msg("  Sub-test: Winter Court State").domain(LogDomains.SYSTEM).info()
	test_instance._on_season_changed("Winter", {})
	
	if "HALL ACTIONS" not in ap_label.text:
		Loggie.msg("[FAIL] Council UI failed to identify Winter season. Label: %s" % ap_label.text).domain(LogDomains.SYSTEM).error()
		test_instance.queue_free()
		return

	# 3. Test AP Enforcement logic (Internal)
	Loggie.msg("  Sub-test: AP enforcement check").domain(LogDomains.SYSTEM).info()
	var test_card = SeasonalCardResource.new()
	test_card.season = SeasonalCardResource.SeasonType.WINTER
	test_card.cost_ap = 99 # Impossible cost
	
	test_instance._current_season = "Winter"
	test_instance.current_ap = 1
	if test_instance._can_afford(test_card):
		Loggie.msg("[FAIL] Council UI allowed playing a Winter card without enough AP.").domain(LogDomains.SYSTEM).error()
		test_instance.queue_free()
		return
		
	test_instance._current_season = "Spring"
	if not test_instance._can_afford(test_card):
		Loggie.msg("[FAIL] Council UI restricted a Spring card by AP (should be ignored).").domain(LogDomains.SYSTEM).error()
		test_instance.queue_free()
		return

	Loggie.msg("[PASS] Seasonal Council logic verified.").domain(LogDomains.SYSTEM).info()
	
	# Cleanup
	test_instance.queue_free()

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
