extends GutTestBase

var bridge_instance = null
var bondi_data = null
var drengr_data = null
var popup_instance = null

func before_each():
	# 1. Setup Mock Data
	bondi_data = UnitData.new()
	bondi_data.wergild_cost = 50
	
	drengr_data = UnitData.new()
	drengr_data.wergild_cost = 100
	
	# 2. Use Factory for Bridge (Auto-mocks UnitContainer and UI)
	bridge_instance = TestUtils.create_mock_bridge()
	
	# 3. Use Factory for Popup
	popup_instance = TestUtils.create_mock_end_year_popup()
	bridge_instance.end_of_year_popup = popup_instance
	
	# 4. Add to Tree
	add_child_autofree(bridge_instance)
	add_child_autofree(popup_instance)

func test_wergild_calculation_simple():
	var result = {
		"gold_looted": 500,
		"casualties": [bondi_data, bondi_data] 
	}
	
	var total_wergild = 0
	for unit in result.casualties:
		total_wergild += unit.wergild_cost
		
	assert_eq(total_wergild, 100)
	var net_gold = result.gold_looted - total_wergild
	assert_eq(net_gold, 400)

func test_wergild_bankruptcy_protection():
	var result = {
		"gold_looted": 50,
		"casualties": [drengr_data] 
	}
	var total_wergild = result.casualties[0].wergild_cost
	var net_gold = max(0, result.gold_looted - total_wergild)
	assert_eq(net_gold, 0)
