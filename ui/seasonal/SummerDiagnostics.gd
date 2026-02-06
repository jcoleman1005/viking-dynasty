#res://ui/seasonal/SummerDiagnostics.gd
extends Node
class_name SummerUIDiagnostic

## A comprehensive diagnostic tool for the SummerWorkspace_UI.
## Validates connections, node assignments, and input handling.

@export var target_ui: SummerWorkspace_UI
@export var audit_interval: float = 1.0

var _timer: float = 0.0

func _ready() -> void:
	# Wait one frame to ensure parent UI _ready has completed
	await get_tree().process_frame 
	
	if not target_ui:
		printerr("[DIAGNOSTIC CRITICAL] No Target UI assigned to SummerUIDiagnostic!")
		return

	Loggie.msg("--- STARTING DEEP DIAGNOSTICS FOR SUMMER UI ---").domain(LogDomains.UI).info()
	
	_validate_node_assignments()
	_hook_inputs()
	_check_visibility_and_process()
	
	# Initial State Dump for Collapse Panel
	if target_ui.container_raid_command:
		_log_state("Initial Collapse State", target_ui.container_raid_command)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= audit_interval:
		_timer = 0.0
		_run_periodic_audit()

# --- 1. Startup Validation ---

func _validate_node_assignments() -> void:
	var nodes_to_check = {
		"btn_collapse_toggle": target_ui.btn_collapse_toggle,
		"btn_world_map": target_ui.btn_world_map,
		"btn_proceed": target_ui.btn_proceed,
		"job_row_farmers": target_ui.job_row_farmers,
		"job_row_builders": target_ui.job_row_builders,
		"job_row_raiders": target_ui.job_row_raiders,
		"container_raid_command": target_ui.container_raid_command
	}
	
	for name in nodes_to_check:
		var node = nodes_to_check[name]
		if node == null:
			_log_error("Node reference missing: target_ui.%s is NULL" % name)
		else:
			if not node.is_inside_tree():
				_log_error("Node %s is assigned but NOT in scene tree!" % name)

func _check_visibility_and_process() -> void:
	if not target_ui.visible:
		_log_warn("Target UI is currently HIDDEN (visible=false). Inputs will fail.")
	
	if target_ui.process_mode == Node.PROCESS_MODE_DISABLED:
		_log_warn("Target UI is DISABLED (process_mode=Disabled).")

	if target_ui.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_log_warn("Target UI root is ignoring mouse events (MOUSE_FILTER_IGNORE).")

# --- 2. Input Spying & Collapse Diagnostics ---

func _hook_inputs() -> void:
	# 1. Main Buttons
	if target_ui.btn_collapse_toggle:
		target_ui.btn_collapse_toggle.pressed.connect(_on_collapse_clicked_diagnostic)
	else:
		_log_error("Cannot hook Collapse Toggle (Node Missing)")

	if target_ui.btn_world_map:
		target_ui.btn_world_map.pressed.connect(func(): _log_input("World Map Clicked"))
		
	if target_ui.btn_proceed:
		target_ui.btn_proceed.pressed.connect(func(): _log_input("Proceed Clicked"))

	# 2. Job Rows
	var rows = {
		"Farmers": target_ui.job_row_farmers,
		"Builders": target_ui.job_row_builders, 
		"Raiders": target_ui.job_row_raiders
	}
	
	for key in rows:
		var row = rows[key]
		if row:
			row.change_requested.connect(func(amount): _log_input("%s Change Requested: %d" % [key, amount]))
			if row.btn_plus: row.btn_plus.pressed.connect(func(): _log_input("%s RAW PLUS Clicked" % key))
			if row.btn_minus: row.btn_minus.pressed.connect(func(): _log_input("%s RAW MINUS Clicked" % key))

func _on_collapse_clicked_diagnostic() -> void:
	_log_input("Collapse Toggle Clicked - Starting Transition Audit")
	var container = target_ui.container_raid_command
	var logic_state = target_ui.is_raid_panel_open
	
	print_rich("[color=orange]=== COLLAPSE TRANSITION START ===[/color]")
	print("Logic State (is_raid_panel_open): ", logic_state)
	_log_state("BEFORE Tween", container)
	
	# Wait for animation duration (0.2s) + buffer
	await get_tree().create_timer(0.3).timeout
	
	print_rich("[color=orange]=== COLLAPSE TRANSITION END ===[/color]")
	print("Logic State (is_raid_panel_open): ", target_ui.is_raid_panel_open)
	_log_state("AFTER Tween", container)
	
	# Logic Check
	if target_ui.is_raid_panel_open == false and container.visible == true:
		_log_error("COLLAPSE FAILURE: Logic says CLOSED, but Container is VISIBLE.")
	elif target_ui.is_raid_panel_open == true and container.modulate.a < 0.1:
		_log_error("COLLAPSE FAILURE: Logic says OPEN, but Container is INVISIBLE (Alpha ~0).")
	else:
		print_rich("[color=green]>> State Sync Logic OK[/color]")

func _log_state(prefix: String, node: Control) -> void:
	if not node: return
	print("%s >> Visible: %s | Modulate Alpha: %.2f | Size: %s" % [
		prefix, 
		str(node.visible), 
		node.modulate.a, 
		str(node.size)
	])

# --- 3. Periodic Audit ---

func _run_periodic_audit() -> void:
	if not target_ui.visible: return

	# Check Data Logic
	if SettlementManager.current_settlement:
		var real_idle = SettlementManager.get_idle_peasants()
		var planned = target_ui.planned_raiders
		var visual_idle = real_idle - planned
		
		if visual_idle > 0:
			if target_ui.job_row_farmers and target_ui.job_row_farmers.btn_plus.disabled:
				_log_warn("Logic Error: Idle peasants exist (%d), but Farmer Plus button is DISABLED." % visual_idle)

# --- Helpers ---

func _log_warn(msg: String) -> void:
	print_rich("[color=yellow][DIAGNOSTIC WARN] %s[/color]" % msg)
	Loggie.msg(msg).domain(LogDomains.UI).warn()

func _log_error(msg: String) -> void:
	print_rich("[color=red][DIAGNOSTIC FAIL] %s[/color]" % msg)
	Loggie.msg(msg).domain(LogDomains.UI).error()

func _log_input(msg: String) -> void:
	print_rich("[color=cyan][DIAGNOSTIC INPUT] %s[/color]" % msg)
