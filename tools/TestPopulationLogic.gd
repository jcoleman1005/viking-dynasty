#res://tools/TestPopulationLogic.gd
@tool
extends EditorScript

# --- Constants from EconomyManager ---
const FOOD_PER_PERSON = 10
const BASE_GROWTH = 0.02
const STARVATION_RATE = -0.15
const UNREST_PER_EXCESS = 2

func _run():
	print("--- 📊 POPULATION LOGIC SIMULATION ---")
	
	# Scenario 1: The "Good Year"
	# 10 People, 200 Food (Abundance), 15 Land Capacity
	_test_scenario("Abundance", 10, 200, 15)
	
	# Scenario 2: "The Squeeze" (Land Hunger)
	# 20 People, 200 Food (Sufficient), 10 Land Capacity (Overpopulated)
	_test_scenario("Land Hunger", 20, 200, 10)
	
	# Scenario 3: "The Winter of Death" (Famine)
	# 10 People, 50 Food (Starvation), 15 Land Capacity
	_test_scenario("Famine", 10, 50, 15)

func _test_scenario(title: String, pop: int, food: int, land_cap: int) -> void:
	print("\n[%s] Start: Pop %d | Food %d | Land Cap %d" % [title, pop, food, land_cap])
	
	var food_req = pop * FOOD_PER_PERSON
	var growth_rate = BASE_GROWTH
	var status = "Normal"
	
	# 1. Food Check
	if food < food_req:
		growth_rate = STARVATION_RATE
		status = "STARVATION"
	elif food > (food_req * 1.5):
		growth_rate += 0.01
		status = "Booming"
		
	# 2. Calc New Pop
	var net_change = int(pop * growth_rate)
	# Force at least 1 change if rate is non-zero
	if growth_rate > 0 and net_change == 0: net_change = 1
	
	var new_pop = pop + net_change
	
	print(" > Food Status: %s (Req: %d)" % [status, food_req])
	print(" > Growth: %d%% -> Net Change: %+d" % [growth_rate * 100, net_change])
	print(" > New Population: %d" % new_pop)
	
	# 3. Land Hunger Check
	if new_pop > land_cap:
		var excess = new_pop - land_cap
		var unrest = excess * UNREST_PER_EXCESS
		print(" > ⚔️ UNREST! %d landless men generate +%d Unrest" % [excess, unrest])
	else:
		print(" > ✅ Stable. Capacity for %d more." % (land_cap - new_pop))
