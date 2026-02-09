@tool
class_name WinterCourtDiagnostic
extends Node

## WINTER COURT DIAGNOSTIC TOOL
## A standalone component to audit the health of the Winter Court UI system.
## NOW INCLUDES: REVERSE-ENGINEERING AUDIT to track missing resources.

@export_group("Controls")
## Trigger the check manually in the Editor
@export_tool_button("Run Full Diagnostics") var _run_check_action = _run_diagnostics
## Key to trigger diagnostics during gameplay
@export var hotkey: Key = KEY_F6

@export_group("Reference Checks")
@export var critical_node_properties: Array[String] = [
	"severity_label",
	"resource_totem", 
	"action_points_label",
	"cards_container",
	"jarl_name_label"
]

@export var required_bus_signals: Array[String] = [
	"season_changed",
	"hall_action_updated",
	"treasury_updated"
]

@export_group("Layout Symmetry Settings")
@export var target_aspect_ratio: float = 0.66
@export var preferred_gutter_px: int = 40
@export var preferred_margin_px: int = 60

# --- SPY STATE ---
var _last_known_food: int = -9999
var _spy_active: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process_input(true)
		Loggie.msg("[Diagnostics] WinterCourt Monitor initialized. Press F6 to scan.").domain(LogDomains.UI).info()
		
		# ACTIVATE SPY
		if get_node_or_null("/root/EventBus"):
			var bus = get_node("/root/EventBus")
			if bus.has_signal("treasury_updated"):
				bus.treasury_updated.connect(_on_treasury_spy_event)
				_spy_active = true
				Loggie.msg("[Spy] Live Treasury Monitor ACTIVE.").domain(LogDomains.ECONOMY).info()
				
				# Initialize baseline
				if get_node_or_null("/root/SettlementManager"):
					var sm = get_node("/root/SettlementManager")
					if sm.current_settlement:
						_last_known_food = sm.current_settlement.treasury.get("food", 0)

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event is InputEventKey and event.pressed and event.keycode == hotkey:
		_run_diagnostics()

# --- SPY HANDLER ---
func _on_treasury_spy_event(new_treasury: Dictionary) -> void:
	var new_food = new_treasury.get("food", 0)
	
	# Detect change
	if _last_known_food != -9999 and new_food != _last_known_food:
		var delta = new_food - _last_known_food
		var direction = "GAINED" if delta > 0 else "LOST"
		
		Loggie.msg("[Spy] TREASURY CHANGED: Food %d -> %d (%s %d)" % [_last_known_food, new_food, direction, abs(delta)]).domain(LogDomains.ECONOMY).debug()
		
		if delta < -50:
			Loggie.msg("[Spy] !!! MASSIVE DROP DETECTED !!! Check WinterManager Consumption Logic.").domain(LogDomains.ECONOMY).error()
			# print_stack() # Optional: Uncomment to trace calls
			
	_last_known_food = new_food

func _run_diagnostics() -> void:
	Loggie.msg("--- WINTER COURT SYSTEM DIAGNOSTIC START ---").domain(LogDomains.UI).info()
	
	var parent = get_parent()
	if not parent:
		Loggie.msg("Diagnostic Node has no parent! Attach to WinterCourtUI.").domain(LogDomains.UI).error()
		return
	
	var passed_checks = 0
	var total_checks = 0
	
	# --------------------------------------------------------------------------
	# 1. Dependency & Hierarchy Check
	# --------------------------------------------------------------------------
	Loggie.msg("1. Dependency & Node Audit").domain(LogDomains.UI).info()
	
	total_checks += 1
	if parent.get_class() == "Control" or parent.is_class("Control"):
		_pass("Parent is valid Control/UI node.")
		passed_checks += 1
	else:
		_fail("Parent is not a Control node (Found: %s)" % parent.get_class())

	for prop_name in critical_node_properties:
		if prop_name == "deficit_container":
			_warn("Skipping legacy property 'deficit_container'. Please reset 'Critical Node Properties' in Inspector.")
			continue
			
		total_checks += 1
		var val = parent.get(prop_name)
		if val == null:
			if prop_name == "resource_totem" and parent.get("deficit_container") != null:
				_fail("Architecture Mismatch: Script expects 'resource_totem' but Parent has 'deficit_container'. Update Parent Script.")
			else:
				_fail("Critical Node Reference missing: %s" % prop_name)
		elif val is Node:
			if not val.is_inside_tree():
				_fail("Reference '%s' is assigned but NOT in Scene Tree (Orphaned Node)." % prop_name)
			else:
				_pass("Reference '%s' linked to: %s" % [prop_name, val.name])
				passed_checks += 1
		else:
			_fail("Property '%s' exists but is not a Node (Val: %s)" % [prop_name, val])

	# --------------------------------------------------------------------------
	# 2. Resource Integrity
	# --------------------------------------------------------------------------
	Loggie.msg("2. Resource Integrity").domain(LogDomains.UI).info()
	
	total_checks += 1
	var cards = parent.get("available_court_cards")
	if cards == null:
		_fail("Parent missing 'available_court_cards' variable.")
	elif cards.is_empty():
		_warn("Card deck is empty. (This is normal if setup hasn't run, bad if In-Game)")
	else:
		var null_cards = 0
		for c in cards:
			if c == null: null_cards += 1
		if null_cards > 0:
			_fail("Found %d NULL entries in 'available_court_cards'!" % null_cards)
		else:
			_pass("Card Deck Valid: %d cards loaded." % cards.size())
			passed_checks += 1
			
	total_checks += 1
	var prefab = parent.get("card_prefab")
	if prefab == null:
		_fail("Card Prefab is MISSING.")
	else:
		_pass("Card Prefab loaded.")
		passed_checks += 1

	# --------------------------------------------------------------------------
	# 3. Signal Bus Integrity
	# --------------------------------------------------------------------------
	Loggie.msg("3. Signal Bus Integrity").domain(LogDomains.UI).info()
	
	var event_bus = get_node_or_null("/root/EventBus")
	if not event_bus:
		_warn("Cannot access /root/EventBus. Skipping signal check.")
	else:
		for sig_name in required_bus_signals:
			total_checks += 1
			if event_bus.has_signal(sig_name):
				var connections = event_bus.get_signal_connection_list(sig_name)
				var is_connected = false
				for conn in connections:
					if conn["callable"].get_object() == parent:
						is_connected = true
						break
				if is_connected:
					_pass("Connected to EventBus.%s" % sig_name)
					passed_checks += 1
				else:
					_fail("Parent NOT connected to EventBus.%s" % sig_name)
			else:
				_fail("EventBus missing signal: %s" % sig_name)

	# --------------------------------------------------------------------------
	# 4. Visibility & Input Check
	# --------------------------------------------------------------------------
	Loggie.msg("4. Visibility & Input Blockers").domain(LogDomains.UI).info()
	
	total_checks += 1
	if parent.visible:
		_pass("UI is Visible.")
		passed_checks += 1
	else:
		_warn("UI is Hidden (visible = false). Inputs will be ignored.")
	
	total_checks += 1
	var blocker_found = false
	var root = parent.get_parent()
	if root:
		for i in range(root.get_child_count()):
			var sibling = root.get_child(i)
			if sibling == parent: break
			if sibling.get_index() > parent.get_index() and sibling is Control:
				if sibling.mouse_filter == Control.MOUSE_FILTER_STOP:
					if sibling.get_global_rect().intersects(parent.get_global_rect()):
						_warn("Sibling '%s' draws on top of WinterCourtUI and might block input!" % sibling.name)
						blocker_found = true
	
	if not blocker_found:
		_pass("No obvious input blockers found.")
		passed_checks += 1
	else:
		_fail("Input blocked by UI overlay.")

	# --------------------------------------------------------------------------
	# 5. Data Flow (Dry Run)
	# --------------------------------------------------------------------------
	Loggie.msg("5. Data Flow (Dry Run)").domain(LogDomains.UI).info()
	
	var econ = get_node_or_null("/root/EconomyManager")
	var settlement = get_node_or_null("/root/SettlementManager")
	
	if econ and settlement:
		total_checks += 1
		var forecast = econ.get_winter_forecast() if econ.has_method("get_winter_forecast") else {}
		if forecast.is_empty():
			_warn("EconomyManager returned empty forecast.")
		else:
			Loggie.msg("   Forecast: %s" % str(forecast)).domain(LogDomains.ECONOMY).debug()
			_pass("Economy Data Accessible.")
			passed_checks += 1
	else:
		_warn("Cannot access Managers (Editor Mode?). Skipping Dry Run.")

	# --------------------------------------------------------------------------
	# 6. Layout Symmetry & Reality Check
	# --------------------------------------------------------------------------
	Loggie.msg("6. Layout Symmetry & Reality Check").domain(LogDomains.UI).info()
	
	var container = parent.get("cards_container")
	if container and container is Control and container.is_inside_tree():
		var metrics = get_trio_layout_metrics()
		
		total_checks += 1
		var cont_rect = container.get_global_rect()
		var parent_rect = parent.get_global_rect()
		
		var overflow_x = cont_rect.position.x < parent_rect.position.x - 10 or cont_rect.end.x > parent_rect.end.x + 10
		var overflow_y = cont_rect.position.y < parent_rect.position.y - 10 or cont_rect.end.y > parent_rect.end.y + 10
			
		if overflow_x or overflow_y:
			_fail("CONTAINER OVERFLOW: The CardsContainer is bigger than the Screen/Root!")
		else:
			_pass("Container fits within Screen/Root bounds.")
			passed_checks += 1

		total_checks += 1
		var children = container.get_children()
		var actual_card_found = false
		for child in children:
			if child is Control and child.visible:
				actual_card_found = true
				var size = child.size
				if size.x > metrics.card_width + 5:
					_warn("Card is WIDER than optimal. Reduce 'Custom Minimum Width' to ~%.0f" % metrics.card_width)
				else:
					_pass("Card asset size is within optimal bounds.")
					passed_checks += 1
				break
		if not actual_card_found: _warn("No cards visible in container to measure.")
	else:
		_warn("Cannot perform layout check: Cards container not found.")

	# --------------------------------------------------------------------------
	# 7. FORENSIC ECONOMY AUDIT
	# --------------------------------------------------------------------------
	Loggie.msg("7. FORENSIC ECONOMY AUDIT").domain(LogDomains.ECONOMY).info()
	total_checks += 1
	
	if econ and settlement:
		var treasury = settlement.current_settlement.treasury
		var forecast = econ.get_winter_forecast()
		var severity = "NORMAL"
		
		if get_node_or_null("/root/WinterManager"):
			var wm = get_node("/root/WinterManager")
			if wm.has_method("get_severity_name"):
				severity = wm.get_severity_name()
			elif "winter_consumption_report" in wm:
				severity = wm.winter_consumption_report.get("severity_name", "NORMAL")
		
		# REVERSE ENGINEERING
		var food_stock = treasury.get("food", 0)
		var food_demand = forecast.get("food", 0)
		var wood_stock = treasury.get("wood", 0)
		var wood_demand = forecast.get("wood", 0)
		
		var implied_start_food = food_stock + food_demand # Assuming deficit was met or consumption applied
		var implied_start_wood = wood_stock + wood_demand
		
		Loggie.msg("   LIVE SNAPSHOT: Food %d | Wood %d" % [food_stock, wood_stock]).domain(LogDomains.ECONOMY).info()
		Loggie.msg("   CONSUMPTION:   Food %d | Wood %d" % [food_demand, wood_demand]).domain(LogDomains.ECONOMY).info()
		Loggie.msg("   IMPLIED START: Food %d | Wood %d" % [implied_start_food, implied_start_wood]).domain(LogDomains.ECONOMY).warn()
		
		if implied_start_food < 50:
			Loggie.msg("   >>> SUSPICIOUS: Started Winter with only %d Food. Harvest likely missing." % implied_start_food).domain(LogDomains.ECONOMY).error()
		
		# Check for Caps (If implemented)
		if econ.has_method("get_storage_cap"):
			var food_cap = econ.get_storage_cap("food")
			Loggie.msg("   STORAGE CAP:   %d" % food_cap).domain(LogDomains.ECONOMY).info()
			if implied_start_food == food_cap:
				Loggie.msg("   >>> CAUSE FOUND: Resources clamped to Storage Cap!").domain(LogDomains.ECONOMY).warn()
		
		_pass("Forensic Audit Complete.")
		passed_checks += 1
	else:
		_fail("Cannot run Forensic Audit: Managers missing.")

	# --------------------------------------------------------------------------
	# CONCLUSION
	# --------------------------------------------------------------------------
	if passed_checks == total_checks:
		Loggie.msg("STATUS: READY (%d/%d Checks Passed)" % [passed_checks, total_checks]).domain(LogDomains.UI).info()
	else:
		Loggie.msg("STATUS: UNSTABLE (%d/%d Checks Passed)" % [passed_checks, total_checks]).domain(LogDomains.UI).error()

func get_trio_layout_metrics() -> Dictionary:
	var container = get_parent().get("cards_container")
	if not container: return {}
	var cont_rect = container.get_rect()
	var cont_w = cont_rect.size.x
	var cont_h = cont_rect.size.y
	var max_h_safe = cont_h * 0.9
	var w_based_on_h = max_h_safe * target_aspect_ratio
	var available_w = cont_w - (preferred_margin_px * 2) - (preferred_gutter_px * 2)
	var w_based_on_w = available_w / 3.0
	var final_w = 0.0
	var final_h = 0.0
	if w_based_on_h * 3.0 + (preferred_gutter_px * 2) > available_w:
		final_w = w_based_on_w
		final_h = final_w / target_aspect_ratio
	else:
		final_w = w_based_on_h
		final_h = max_h_safe
	var is_safe = final_h <= cont_h
	return { "card_width": final_w, "card_height": final_h, "is_safe": is_safe }

# Helpers
func _pass(msg: String) -> void: 
	Loggie.msg("[PASS] " + msg).domain(LogDomains.UI).info()

func _fail(msg: String) -> void: 
	Loggie.msg("[FAIL] " + msg).domain(LogDomains.UI).error()

func _warn(msg: String) -> void: 
	Loggie.msg("[WARN] " + msg).domain(LogDomains.UI).warn()
