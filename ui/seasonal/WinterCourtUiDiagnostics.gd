@tool
class_name WinterCourtDiagnostic
extends Node

## WINTER COURT DIAGNOSTIC TOOL
## A standalone component to audit the health of the Winter Court UI system.
## Now includes "Reality Checks" for container overflow and actual card sizes.

@export_group("Controls")
## Trigger the check manually in the Editor
@export_tool_button("Run Full Diagnostics") var _run_check_action = _run_diagnostics
## Key to trigger diagnostics during gameplay
@export var hotkey: Key = KEY_F6

@export_group("Reference Checks")
## List of unique nodes expected in the parent UI
@export var critical_node_properties: Array[String] = [
	"severity_label",
	"deficit_container",
	"action_points_label",
	"cards_container",
	"jarl_name_label"
]

## List of signals expected to be connected on the EventBus
@export var required_bus_signals: Array[String] = [
	"season_changed",
	"hall_action_updated",
	"treasury_updated"
]

@export_group("Layout Symmetry Settings")
## Target Aspect Ratio for cards (Width / Height). Standard Poker is ~0.71. 2:3 is 0.66.
@export var target_aspect_ratio: float = 0.66
## Minimum spacing between cards in pixels
@export var preferred_gutter_px: int = 40
## Minimum outer margins (left/right) in pixels
@export var preferred_margin_px: int = 60

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process_input(true)
		print_rich("[color=gray][Diagnostics] WinterCourt Monitor initialized. Press F6 to scan.[/color]")

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event is InputEventKey and event.pressed and event.keycode == hotkey:
		_run_diagnostics()

func _run_diagnostics() -> void:
	print_rich("\n[b][color=yellow]--- WINTER COURT SYSTEM DIAGNOSTIC START ---[/color][/b]")
	
	var parent = get_parent()
	if not parent:
		push_error("Diagnostic Node has no parent! Attach to WinterCourtUI.")
		return
	
	var passed_checks = 0
	var total_checks = 0
	
	# --------------------------------------------------------------------------
	# 1. Dependency & Hierarchy Check
	# --------------------------------------------------------------------------
	print_rich("[b]1. Dependency & Node Audit[/b]")
	
	total_checks += 1
	if parent.get_class() == "Control" or parent.is_class("Control"):
		_pass("Parent is valid Control/UI node.")
		passed_checks += 1
	else:
		_fail("Parent is not a Control node (Found: %s)" % parent.get_class())

	for prop_name in critical_node_properties:
		total_checks += 1
		var val = parent.get(prop_name)
		if val == null:
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
	print_rich("\n[b]2. Resource Integrity[/b]")
	
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
	print_rich("\n[b]3. Signal Bus Integrity[/b]")
	
	var event_bus = get_node_or_null("/root/EventBus")
	if not event_bus:
		_warn("Cannot access /root/EventBus (Normal in Editor unless plugin used). Skipping live signal check.")
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
	print_rich("\n[b]4. Visibility & Input Blockers[/b]")
	
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
	print_rich("\n[b]5. Data Flow (Dry Run)[/b]")
	
	var econ = get_node_or_null("/root/EconomyManager")
	var settlement = get_node_or_null("/root/SettlementManager")
	
	if econ and settlement:
		total_checks += 1
		var forecast = econ.get_winter_forecast() if econ.has_method("get_winter_forecast") else {}
		if forecast.is_empty():
			_warn("EconomyManager returned empty forecast.")
		else:
			print_rich("   [color=cyan]Forecast:[/color] %s" % str(forecast))
			_pass("Economy Data Accessible.")
			passed_checks += 1
	else:
		_warn("Cannot access Managers (Editor Mode?). Skipping Dry Run.")

	# --------------------------------------------------------------------------
	# 6. Layout Symmetry & Reality Check (NEW)
	# --------------------------------------------------------------------------
	print_rich("\n[b]6. Layout Symmetry & Reality Check[/b]")
	
	var container = parent.get("cards_container")
	if container and container is Control and container.is_inside_tree():
		# A. THEORETICAL CHECK
		var metrics = get_trio_layout_metrics()
		
		# B. REALITY CHECK (NEW): Does the container overflow the Parent UI?
		total_checks += 1
		var cont_rect = container.get_global_rect()
		var parent_rect = parent.get_global_rect()
		
		# Check if container is wider than parent (with tolerance)
		var overflow_x = false
		if cont_rect.position.x < parent_rect.position.x - 10 or cont_rect.end.x > parent_rect.end.x + 10:
			overflow_x = true
			
		var overflow_y = false
		if cont_rect.position.y < parent_rect.position.y - 10 or cont_rect.end.y > parent_rect.end.y + 10:
			overflow_y = true
			
		if overflow_x or overflow_y:
			_fail("CONTAINER OVERFLOW: The CardsContainer is bigger than the Screen/Root!")
			print_rich("   [color=red]Root Size:[/color] %s vs [color=red]Container Size:[/color] %s" % [parent_rect.size, cont_rect.size])
			print_rich("   [color=yellow]Fix:[/color] Cards are forcing the container to expand. Check 'Custom Minimum Size' on Card Prefabs.")
		else:
			_pass("Container fits within Screen/Root bounds.")
			passed_checks += 1

		# C. ASSET CHECK (NEW): What size are the actual cards?
		total_checks += 1
		var children = container.get_children()
		var actual_card_found = false
		for child in children:
			if child is Control and child.visible:
				actual_card_found = true
				var size = child.size
				var min_size = child.custom_minimum_size
				
				# Compare Actual vs Optimal
				var ratio = size.x / size.y if size.y > 0 else 0
				print_rich("   [color=cyan]Actual Card:[/color] %.1f x %.1f (Ratio: %.2f)" % [size.x, size.y, ratio])
				print_rich("   [color=gray]Optimal:[/color] %.1f x %.1f (Ratio: %.2f)" % [metrics.card_width, metrics.card_height, target_aspect_ratio])
				
				if size.x > metrics.card_width + 5:
					_warn("Card is WIDER than optimal calculation. This causes clipping.")
					_warn("Please reduce 'Custom Minimum Width' on Card Prefab to ~%.0f" % metrics.card_width)
				elif size.y > metrics.card_height + 5:
					_warn("Card is TALLER than optimal. This causes clipping.")
				else:
					_pass("Card asset size is within optimal bounds.")
					passed_checks += 1
				break # Only check first valid card
		
		if not actual_card_found:
			_warn("No cards visible in container to measure.")

	else:
		_warn("Cannot perform layout check: Cards container not found or not in tree.")

	# --------------------------------------------------------------------------
	# CONCLUSION
	# --------------------------------------------------------------------------
	print_rich("\n[b]--------------------------------------------------[/b]")
	if passed_checks == total_checks:
		print_rich("[b][color=green]STATUS: READY (%d/%d Checks Passed)[/color][/b]" % [passed_checks, total_checks])
	else:
		print_rich("[b][color=red]STATUS: UNSTABLE (%d/%d Checks Passed)[/color][/b]" % [passed_checks, total_checks])
	print_rich("[b]--------------------------------------------------[/b]\n")

# ------------------------------------------------------------------------------
# SYMMETRY ENGINE
# ------------------------------------------------------------------------------
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
	var constraint_type = ""
	
	if w_based_on_h * 3.0 + (preferred_gutter_px * 2) > available_w:
		final_w = w_based_on_w
		final_h = final_w / target_aspect_ratio
		constraint_type = "Width Constrained"
	else:
		final_w = w_based_on_h
		final_h = max_h_safe
		constraint_type = "Height Constrained"
	
	var total_content_width = (final_w * 3) + (preferred_gutter_px * 2)
	var centering_offset = (cont_w - total_content_width) / 2.0
	var is_safe = final_h <= cont_h
	
	return {
		"card_width": final_w,
		"card_height": final_h,
		"spacing": preferred_gutter_px,
		"constraint_type": constraint_type,
		"is_safe": is_safe
	}

# Helpers
func _pass(msg: String) -> void:
	print_rich(" [color=green]PASS[/color] " + msg)

func _fail(msg: String) -> void:
	print_rich(" [color=red]FAIL[/color] " + msg)
	push_error("[WinterCourt Diagnostic] " + msg)

func _warn(msg: String) -> void:
	print_rich(" [color=yellow]WARN[/color] " + msg)
