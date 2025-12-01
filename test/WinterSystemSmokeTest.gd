# res://test/WinterCrisisTest.gd
extends Node2D

const WINTER_UI_SCENE = "res://ui/WinterCourt_UI.tscn"

# --- TEST CONFIGURATION ---
# Change these values to test different scenarios!
const STARTING_GOLD = 5000
const STARTING_FOOD = 0     # Set to 0 for Crisis, 1000 for Safety
const STARTING_WOOD = 100
const POPULATION_COUNT = 50 # 50 Peasants = 50 Food Demand
# --------------------------

func _ready() -> void:
	print("\n❄️ --- STARTING WINTER CRISIS SMOKE TEST --- ❄️")
	
	# 1. SETUP MOCK DATA
	_setup_scenario()
	
	# 2. TRIGGER CALCULATION
	# Force DynastyManager to calculate needs based on our mock data
	print("🔹 Running Winter Calculation via DynastyManager...")
	DynastyManager._calculate_winter_needs()
	
	# 3. VERIFY STATE (Code Level)
	_verify_logic_state()
	
	# 4. SPAWN UI (Visual Level)
	print("🔹 Spawning UI for visual confirmation...")
	_spawn_ui()
	
	print("\n👉 TEST COMPLETE.")
	if DynastyManager.winter_crisis_active:
		print("   State: CRISIS ACTIVE. UI should be locked.")
		print("   Action: Click the flashing RED button to resolve.")
	else:
		print("   State: SAFE. UI should be normal.")
		print("   Action: Click 'Enter Court' on the popup.")

func _setup_scenario() -> void:
	# Mock Jarl (Rich in Renown/Actions)
	var jarl = JarlData.new()
	jarl.display_name = "Jarl Testor"
	jarl.current_hall_actions = 3
	jarl.renown = 1000
	DynastyManager.current_jarl = jarl
	
	# Mock Settlement
	var settlement = SettlementData.new()
	settlement.population_peasants = POPULATION_COUNT
	
	# --- FIX: Use clear() to respect typed Array[WarbandData] ---
	settlement.warbands.clear() 
	# ------------------------------------------------------------
	
	settlement.treasury = {
		"food": STARTING_FOOD,
		"wood": STARTING_WOOD,
		"gold": STARTING_GOLD
	}
	
	SettlementManager.current_settlement = settlement
	print("✅ Mock Data Created:")
	print("   - Pop: %d" % POPULATION_COUNT)
	print("   - Food: %d" % STARTING_FOOD)
	print("   - Gold: %d" % STARTING_GOLD)

func _verify_logic_state() -> void:
	var report = DynastyManager.winter_consumption_report
	var is_crisis = DynastyManager.winter_crisis_active
	
	print("\n📊 --- LOGIC REPORT ---")
	print("   Demand: %d Food, %d Wood" % [report.get("food_cost", 0), report.get("wood_cost", 0)])
	print("   Deficit: %d Food" % report.get("food_deficit", 0))
	print("   Crisis Active: %s" % str(is_crisis))
	
	# Automated Assertion
	if STARTING_FOOD < report.get("food_cost", 0):
		if is_crisis:
			print("✅ PASS: Low food correctly triggered Crisis Mode.")
		else:
			printerr("❌ FAIL: Food was low, but Crisis did not trigger!")
	else:
		if not is_crisis:
			print("✅ PASS: Sufficient food correctly avoided Crisis Mode.")
		else:
			printerr("❌ FAIL: Food was sufficient, but Crisis triggered anyway!")

func _spawn_ui() -> void:
	if not ResourceLoader.exists(WINTER_UI_SCENE):
		printerr("❌ CRITICAL: UI Scene not found at ", WINTER_UI_SCENE)
		return
		
	var ui = load(WINTER_UI_SCENE).instantiate()
	$CanvasLayer.add_child(ui)
