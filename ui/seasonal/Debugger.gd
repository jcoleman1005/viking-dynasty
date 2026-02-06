extends Control

## DIAGNOSTIC TOOL: Autumn Ledger PROBE (V7.1 - Detailed Clipper Stripper)
## "Kidnapping" worked, "Z-Index" failed. This confirms CLIPPING is the culprit.
## This script will forcefully DISABLE 'clip_contents' on all ancestors.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	_perform_clipper_strip()

func _perform_clipper_strip() -> void:
	var parent = get_parent()
	if not parent: return
	
	Loggie.msg("--- V7.1 AUDIT: CLIPPER STRIPPER (DETAILED) ---").domain("UI_DEBUG").info()

	var target_label = parent.find_child("FoodStock", true, false) as Label
	if not target_label: 
		Loggie.msg("CRITICAL: Target 'FoodStock' not found.").domain("UI_DEBUG").error()
		return

	# 1. Setup Target & Log Initial State
	Loggie.msg("Target Found: '%s' (%s)" % [target_label.name, target_label.get_path()]).domain("UI_DEBUG").info()
	Loggie.msg("   > Global Pos: %s | Size: %s" % [target_label.get_global_position(), target_label.get_size()]).domain("UI_DEBUG").info()
	Loggie.msg("   > Global Rect: %s" % [target_label.get_global_rect()]).domain("UI_DEBUG").info()

	target_label.text = "NO CLIPPING"
	target_label.modulate = Color.YELLOW
	target_label.visible = true
	target_label.z_index = 0 
	
	# 2. WALK UP THE CHAIN
	var current = target_label.get_parent()
	var safety_break = 0
	
	while current is Control and safety_break < 20:
		var node_name = current.name
		var node_class = current.get_class()
		var node_size = current.get_size()
		var node_min = current.custom_minimum_size
		var is_clipping = current.clip_contents
		
		# Log generic ancestor info
		Loggie.msg("Inspecting Ancestor [%d]: '%s' (%s)" % [safety_break, node_name, node_class]).domain("UI_DEBUG").info()
		Loggie.msg("   > Size: %s | MinSize: %s | Visible: %s" % [node_size, node_min, current.visible]).domain("UI_DEBUG").info()
		Loggie.msg("   > Global Rect: %s" % current.get_global_rect()).domain("UI_DEBUG").info()
		
		# Check for Clipping
		if is_clipping:
			Loggie.msg("⚔️ FOUND CLIPPER: '%s' had clip_contents=ON. Disabling..." % node_name).domain("UI_DEBUG").warn()
			current.clip_contents = false
			_mark_culprit(current)
		else:
			Loggie.msg("   > Clip Contents: OFF (OK)").domain("UI_DEBUG").info()
		
		# Check for Constriction (Zero Size)
		if node_size.x < 10 or node_size.y < 10:
			Loggie.msg("⚠️ CONSTRICTED: Ancestor '%s' is extremely small %s." % [node_name, str(node_size)]).domain("UI_DEBUG").warn()
			Loggie.msg("   > Attempting Force-Expand to (500, 500)...").domain("UI_DEBUG").warn()
			current.custom_minimum_size = Vector2(500, 500) 
		
		# Check Size Flags (common layout killer)
		var h_flag = current.size_flags_horizontal
		var v_flag = current.size_flags_vertical
		Loggie.msg("   > Flags H:%d V:%d (Expand=3, Fill=1)" % [h_flag, v_flag]).domain("UI_DEBUG").info()

		current = current.get_parent()
		safety_break += 1
		
	Loggie.msg("--- AUDIT COMPLETE ---").domain("UI_DEBUG").info()

func _mark_culprit(node: Control) -> void:
	var rect = ReferenceRect.new()
	rect.editor_only = false
	rect.border_color = Color.RED
	rect.border_width = 4.0
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(rect)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var parent = get_parent()
	if not parent: return
	var target = parent.find_child("FoodStock", true, false) as Control
	if target:
		var target_local_pos = get_global_transform().affine_inverse() * target.get_global_position()
		draw_rect(Rect2(target_local_pos, target.size), Color.YELLOW, false, 2.0)
