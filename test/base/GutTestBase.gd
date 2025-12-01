# res://test/base/GutTestBase.gd
class_name GutTestBase
extends GutTest

# This runs before EVERY test in ANY script that extends GutTestBase
func before_each():
	# 1. Reset Singletons
	# We reset state to prevent "pollution" from previous tests
	if SettlementManager:
		SettlementManager.reset_manager_state()
		SettlementManager.current_settlement = null
		
	if DynastyManager:
		DynastyManager.winter_crisis_active = false
		DynastyManager.winter_consumption_report.clear()
		DynastyManager.active_year_modifiers.clear()
		DynastyManager.current_jarl = null
		
	# 2. Silence Logs during testing (Optional, keeps output clean)
	# Loggie.set_domain_enabled(LogDomains.SYSTEM, false)

# --- FACTORY HELPERS (Reduces boilerplate in tests) ---

func create_mock_jarl(authority: int = 3, renown: int = 100) -> JarlData:
	var jarl = JarlData.new()
	jarl.display_name = "Test Jarl"
	jarl.current_authority = authority
	jarl.max_authority = authority
	jarl.renown = renown
	DynastyManager.current_jarl = jarl
	return jarl

func create_mock_settlement(pop: int = 10, food: int = 100) -> SettlementData:
	var s = SettlementData.new()
	s.population_peasants = pop
	s.treasury = {
		GameResources.FOOD: food,
		GameResources.WOOD: 100,
		GameResources.GOLD: 100
	}
	s.warbands.clear() # Safety clear
	SettlementManager.current_settlement = s
	return s

func create_mock_warband(unit_data: UnitData = null) -> WarbandData:
	if not unit_data:
		# Load a real one if none provided, or mock one
		unit_data = load("res://data/units/Unit_PlayerRaider.tres")
	
	var wb = WarbandData.new(unit_data)
	wb.current_manpower = 10
	return wb
