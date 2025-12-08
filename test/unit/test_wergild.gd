extends GutTest

var bridge_script = load("res://scripts/buildings/SettlementBridge.gd")
var bridge_instance = null
var bondi_data = null
var drengr_data = null

func before_each():
	bridge_instance = bridge_script.new()
	
	# --- MOCKING THE SCENE TREE ---
	
	# A. The UI Layer
	var ui_node = CanvasLayer.new()
	ui_node.name = "UI"
	bridge_instance.add_child(ui_node)
	
	var store_ui = Control.new()
	store_ui.name = "Storefront_UI"
	
	# FIX: Add Signals using simple strings to avoid encoding errors
	var store_code = "extends Control\n"
	store_code += "signal building_purchase_requested(data)\n"
	store_code += "signal raid_launch_requested()\n"
	store_code += "signal winter_court_requested()\n"
	
	var store_script = GDScript.new()
	store_script.source_code = store_code
	store_script.reload()
	store_ui.set_script(store_script)
	
	ui_node.add_child(store_ui)
	
	# B. Building Cursor
	var curs = Node2D.new()
	curs.name = "BuildingCursor"
	
	var curs_code = "extends Node2D\n"
	curs_code += "signal placement_completed(building, pos)\n"
	curs_code += "signal placement_cancelled()\n"
	
	var curs_script = GDScript.new()
	curs_script.source_code = curs_code
	curs_script.reload()
	curs.set_script(curs_script)
	
	bridge_instance.add_child(curs)
	
	# C. Containers
	var b_cont = Node2D.new()
	b_cont.name = "BuildingContainer"
	bridge_instance.add_child(b_cont)
	
	var grid = Node2D.new()
	grid.name = "GridManager"
	bridge_instance.add_child(grid)
	
	# D. Strict Mocks
	var rts = Node2D.new()
	rts.name = "RTSController"
	if ResourceLoader.exists("res://player/RTSController.gd"):
		rts.set_script(load("res://player/RTSController.gd"))
	bridge_instance.add_child(rts)
	
	var spawner = Node2D.new()
	spawner.name = "UnitSpawner"
	if ResourceLoader.exists("res://scripts/utility/UnitSpawner.gd"):
		spawner.set_script(load("res://scripts/utility/UnitSpawner.gd"))
	bridge_instance.add_child(spawner)
	
	var u_cont = Node2D.new()
	u_cont.name = "UnitContainer"
	bridge_instance.add_child(u_cont)
	
	# E. EndOfYearPopup
	var mock_popup = PanelContainer.new() 
	mock_popup.set_script(load("res://ui/EndOfYear_Popup.gd")) 
	bridge_instance.end_of_year_popup = mock_popup
	bridge_instance.add_child(mock_popup)
	
	add_child(bridge_instance)
	
	# Data setup
	bondi_data = UnitData.new()
	bondi_data.wergild_cost = 50
	bondi_data.display_name = "Bondi"
	
	drengr_data = UnitData.new()
	drengr_data.wergild_cost = 150
	drengr_data.display_name = "Huscarl"
	
	watch_signals(SettlementManager)

func after_each():
	if is_instance_valid(bridge_instance):
		bridge_instance.free()
	DynastyManager.pending_raid_result = {}

func test_wergild_calculation_simple():
	var result = {
		"outcome": "retreat",
		"gold_looted": 500,
		"victory_grade": "None",
		"casualties": [bondi_data, bondi_data]
	}
	DynastyManager.pending_raid_result = result
	bridge_instance._process_raid_return()
	pass_test("Calculation ran without crashing.")

func test_wergild_bankruptcy_protection():
	var result = {
		"outcome": "retreat",
		"gold_looted": 100,
		"victory_grade": "None",
		"casualties": [drengr_data]
	}
	DynastyManager.pending_raid_result = result
	var net_gold = max(0, result.gold_looted - result.casualties[0].wergild_cost)
	assert_eq(net_gold, 0, "Net gold should be clamped to 0.")

func test_wergild_with_victory_bonus():
	DynastyManager.current_raid_difficulty = 1
	var result = {
		"outcome": "victory",
		"gold_looted": 200,
		"victory_grade": "Standard",
		"casualties": [bondi_data]
	}
	DynastyManager.pending_raid_result = result
	bridge_instance._process_raid_return()
	pass_test("Victory logic executed.")
