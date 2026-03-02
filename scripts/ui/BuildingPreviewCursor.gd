#res://scripts/ui/BuildingPreviewCursor.gd
extends Node2D
class_name BuildingPreviewCursor

const ISO_PLACEHOLDER_SCRIPT = "res://scripts/utility/IsoPlaceholder.gd"

# --- Components ---
var current_building_data: BuildingData
var preview_visuals: Node2D 
var is_active: bool = false
var error_label: Label 

# --- Decree Mode State ---
var is_decree_mode: bool = false
var _decree_building_data: BuildingData = null
var _decree_footprints: Dictionary = {} # maps Vector2i grid_pos to Line2D node
var footprint_container: Node2D

# --- Grid & Placement ---
var grid_overlay: Node2D
var can_place: bool = false
var current_grid_pos: Vector2i = Vector2i.ZERO

# --- Visual Settings ---
var valid_color: Color = Color(0.4, 1.0, 0.4, 0.7)    # Greenish
var invalid_color: Color = Color(1.0, 0.4, 0.4, 0.7)  # Reddish

# --- Tether Settings ---
var nearest_node: Node2D = null 
var tether_color_valid: Color = Color(0.2, 1.0, 0.2, 0.8) 
var tether_color_invalid: Color = Color(1.0, 0.2, 0.2, 0.8)

func _ready() -> void:
	z_index = 100 
	
	footprint_container = Node2D.new()
	footprint_container.name = "FootprintContainer"
	add_child(footprint_container)
	
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	
	error_label = Label.new()
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.add_theme_color_override("font_outline_color", Color.BLACK)
	error_label.add_theme_constant_override("outline_size", 4)
	error_label.add_theme_font_size_override("font_size", 24)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.position = Vector2(-100, -80) 
	error_label.custom_minimum_size = Vector2(200, 30)
	error_label.visible = false
	add_child(error_label)
	
	# Listen for placement requests
	if EventBus.has_signal("building_ready_for_placement"):
		EventBus.building_ready_for_placement.connect(set_building_preview)
	
	if EventBus.has_signal("decree_selection_mode_started"):
		EventBus.decree_selection_mode_started.connect(_on_decree_selection_mode_started)
	
	EventBus.decree_authorized.connect(_on_decree_authorized)
	EventBus.decree_sealed.connect(_on_decree_sealed)
	EventBus.decree_cancelled.connect(_on_decree_cancelled)
	EventBus.decree_interaction_finished.connect(_on_decree_interaction_finished)
	
	visible = false
	set_process(false)
	set_process_input(false)

func set_building_preview(building_data: BuildingData) -> void:
	if not building_data: return
	current_building_data = building_data
	
	_cleanup_preview()
	
	# --- 1. Determine Visuals ---
	var tex_to_use: Texture2D = null
	
	if "building_texture" in building_data and building_data.building_texture:
		tex_to_use = building_data.building_texture
	elif building_data.scene_to_spawn:
		tex_to_use = _extract_texture_from_scene(building_data.scene_to_spawn)
	elif building_data.icon:
		tex_to_use = building_data.icon
	
	if tex_to_use:
		var sprite = Sprite2D.new()
		sprite.texture = tex_to_use
		sprite.centered = true
		sprite.offset = Vector2(0, -tex_to_use.get_height() / 2.0)
		preview_visuals = sprite
	else:
		Loggie.msg("No texture for %s, generating procedural placeholder." % building_data.display_name).domain(LogDomains.UI).debug()
		preview_visuals = _create_procedural_placeholder(building_data)

	if preview_visuals:
		preview_visuals.modulate = valid_color
		add_child(preview_visuals)
	
	# --- 2. Create Isometric Outline ---
	_create_grid_outline(building_data.grid_size)
	
	# --- 3. Activate ---
	is_active = true
	visible = true
	set_process(true)
	set_process_input(true)
	
	Loggie.msg("Placement Mode Started: %s" % building_data.display_name).domain(LogDomains.UI).debug()

func _create_procedural_placeholder(data: BuildingData) -> Node2D:
	var placeholder = Node2D.new()
	if ResourceLoader.exists(ISO_PLACEHOLDER_SCRIPT):
		var script = load(ISO_PLACEHOLDER_SCRIPT)
		placeholder.set_script(script)
		if "grid_size" in placeholder:
			placeholder.set("grid_size", data.grid_size)
		elif "data" in placeholder:
			placeholder.set("data", data)
		placeholder.queue_redraw()
	else:
		Loggie.msg("IsoPlaceholder script missing!").domain(LogDomains.UI).error()
	return placeholder

func _extract_texture_from_scene(packed_scene: PackedScene) -> Texture2D:
	if not packed_scene: return null
	var instance = packed_scene.instantiate()
	var found_tex: Texture2D = null
	if instance is Sprite2D:
		found_tex = instance.texture
	else:
		for child in instance.get_children():
			if child is Sprite2D:
				found_tex = child.texture
				break
	instance.queue_free()
	return found_tex

func _process(_delta: float) -> void:
	if not is_active or not current_building_data: return
	
	var mouse_pos = get_global_mouse_position()
	
	if SettlementManager:
		current_grid_pos = SettlementManager.world_to_grid(mouse_pos)
		
		if SettlementManager.has_method("get_footprint_center"):
			global_position = SettlementManager.get_footprint_center(current_grid_pos, current_building_data.grid_size)
		else:
			global_position = SettlementManager.grid_to_world(current_grid_pos)
			
		var error = SettlementManager.get_placement_error(current_grid_pos, current_building_data.grid_size, current_building_data)
		can_place = (error == "")
		
		if can_place:
			error_label.visible = false
		else:
			error_label.text = error
			error_label.visible = true
			
	else:
		global_position = mouse_pos
		can_place = true
		error_label.visible = false
	
	_find_nearest_resource_node(global_position)
	_update_visual_feedback()
	queue_redraw()

func _on_decree_selection_mode_started(building_data: BuildingData) -> void:
	is_decree_mode = true
	_decree_building_data = building_data
	set_building_preview(building_data)
	Loggie.msg("Decree Selection Mode Active: Select a resource node").domain(LogDomains.UI).info()

func _on_decree_authorized(decree: ConstructionDecree) -> void:
	Loggie.msg("BuildingPreviewCursor: Decree authorized signal received").domain(LogDomains.UI).info()
	if not SettlementManager.active_tilemap_layer:
		Loggie.msg("BuildingPreviewCursor: No active tilemap layer").domain(LogDomains.UI).warn()
		return

	# The green preview is still visible, so remove it first.
	_cleanup_preview()
		
	# Create a new Line2D for the footprint
	var tile_size = Vector2(64, 32)
	if SettlementManager.has_method("get_active_grid_cell_size"):
		tile_size = SettlementManager.get_active_grid_cell_size()
		
	var half_w = tile_size.x * 0.5
	var half_h = tile_size.y * 0.5
	var basis_x = Vector2(half_w, half_h)
	var basis_y = Vector2(-half_w, half_h)
	
	var w = float(decree.building_data.grid_size.x)
	var h = float(decree.building_data.grid_size.y)
	var top_left_grid = Vector2(-w * 0.5, -h * 0.5)
	
	var p_top_left = (basis_x * top_left_grid.x) + (basis_y * top_left_grid.y)
	var p_top_right = (basis_x * (top_left_grid.x + w)) + (basis_y * top_left_grid.y)
	var p_bot_right = (basis_x * (top_left_grid.x + w)) + (basis_y * (top_left_grid.y + h))
	var p_bot_left = (basis_x * top_left_grid.x) + (basis_y * (top_left_grid.y + h))
	
	var footprint = Line2D.new()
	footprint.name = "DecreeFootprint_%s" % str(decree.resolved_grid_pos)
	footprint.points = PackedVector2Array([
		p_top_left,
		p_top_right,
		p_bot_right,
		p_bot_left,
		p_top_left
	])
	
	footprint.width = 2.0
	footprint.default_color = Color(0.8, 0.6, 0.15, 0.85) # Muted Gold
	
	# Position the outline
	footprint_container.add_child(footprint)
	footprint.global_position = SettlementManager.get_footprint_center(decree.resolved_grid_pos, decree.building_data.grid_size)
	_decree_footprints[decree.resolved_grid_pos] = footprint
	
	# Ensure the cursor node itself is visible so children are rendered
	visible = true
	Loggie.msg("BuildingPreviewCursor: Footprint added at " + str(decree.resolved_grid_pos)).domain(LogDomains.UI).info()

func _on_decree_interaction_finished() -> void:
	_cancel_decree_mode()

func _on_decree_sealed(grid_pos: Vector2i) -> void:
	if _decree_footprints.has(grid_pos):
		var footprint = _decree_footprints[grid_pos]
		if is_instance_valid(footprint):
			footprint.queue_free()
		_decree_footprints.erase(grid_pos)
		
	if _decree_footprints.is_empty() and not is_active:
		visible = false

func _on_decree_cancelled(grid_pos: Vector2i) -> void:
	if _decree_footprints.has(grid_pos):
		var footprint = _decree_footprints[grid_pos]
		if is_instance_valid(footprint):
			footprint.queue_free()
		_decree_footprints.erase(grid_pos)
		
	# This signal can now mean the whole flow is cancelled
	_cancel_decree_mode()

func _input(event: InputEvent) -> void:
	if not is_active: return
	
	if event is InputEventMouseButton and event.is_pressed():
		# GUI GUARD: Prevent placement if mouse is hovering an active UI element
		var hovered_control = get_viewport().gui_get_hovered_control()
		
		# If we are hovering a valid control that DOES NOT ignore mouse inputs, we check it.
		if hovered_control and hovered_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			
			# [FIX] Exception logic: If the blocker is the SelectionBox, ignore it and allow placement.
			# This prevents the full-screen selection overlay from breaking the game.
			var blocker_name = hovered_control.name.to_lower()
			if "selection" in blocker_name or "grid" in blocker_name or "overlay" in blocker_name:
				# It's likely an overlay; allow placement.
				pass
			else:
				# It's a Button or Window; Block placement.
				# Loggie.msg("Placement blocked by UI").context(hovered_control.name).debug()
				
				# Allow cancelling via Right Click even over UI
				if event.button_index == MOUSE_BUTTON_RIGHT:
					if is_decree_mode:
						_cancel_decree_mode()
					else:
						cancel_preview()
					get_viewport().set_input_as_handled()
				return 

		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_decree_mode:
				_try_issue_decree()
			else:
				_try_place_building()
			get_viewport().set_input_as_handled() 
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if is_decree_mode:
				_cancel_decree_mode()
			else:
				cancel_preview()
			get_viewport().set_input_as_handled()

func _try_issue_decree() -> void:
	if not nearest_node:
		Loggie.msg("No valid resource node selected").domain(LogDomains.UI).warn()
		return
		
	# Verify resource type matches
	var economic_data = _decree_building_data as EconomicBuildingData
	if not economic_data or not "resource_type" in nearest_node or nearest_node.resource_type != economic_data.resource_type:
		Loggie.msg("Selected node does not match building resource type").domain(LogDomains.UI).warn()
		return

	var decree = ConstructionAuthority.issue_decree(_decree_building_data, nearest_node)
	if decree:
		_open_decree_popup(decree)
		# Freeze the cursor in place while the popup is open.
		# The full cleanup is handled by the interaction finished/cancelled signals.
		set_process(false)
	else:
		Loggie.msg("Failed to issue decree - No valid placement found near node").domain(LogDomains.UI).error()

func _cancel_decree_mode() -> void:
	is_decree_mode = false
	_decree_building_data = null
	cancel_preview()

func _open_decree_popup(decree: ConstructionDecree) -> void:
	if EventBus:
		EventBus.construction_decree_issued.emit(decree)
	else:
		Loggie.msg("EventBus missing, cannot open decree popup").domain(LogDomains.UI).error()

func _try_place_building() -> void:
	if not is_active or not can_place: return
	
	if SettlementManager:
		SettlementManager.place_building(current_building_data, current_grid_pos, true)
		EventBus.purchase_successful.emit("Construction Started")
	
	EventBus.building_placed.emit(current_building_data)
	
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_preview()

func cancel_preview() -> void:
	var refunded_data = current_building_data

	is_active = false
	if _decree_footprints.is_empty():
		visible = false
		
	set_process(false)
	set_process_input(false)
	
	current_building_data = null
	_cleanup_preview()
	
	EventBus.building_placement_cancelled.emit(refunded_data)
	Loggie.msg("Placement Cancelled").domain(LogDomains.UI).debug()
	queue_redraw()

func _cleanup_preview() -> void:
	if preview_visuals: 
		preview_visuals.queue_free()
		preview_visuals = null
	_clear_grid_overlay()

func _update_visual_feedback() -> void:
	if not preview_visuals: return
	preview_visuals.modulate = valid_color if can_place else invalid_color

func _find_nearest_resource_node(world_pos: Vector2) -> void:
	nearest_node = null
	if not current_building_data is EconomicBuildingData: return
		
	var target_type = (current_building_data as EconomicBuildingData).resource_type
	var min_dist = INF
	
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	
	for node in nodes:
		if "resource_type" in node and node.resource_type == target_type:
			if node.has_method("is_depleted") and node.is_depleted(): continue
			
			var dist = world_pos.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_node = node

func _draw() -> void:
	# DEBUG CROSSHAIR
	draw_line(Vector2(-30, 0), Vector2(30, 0), Color.GREEN, 2.0)
	draw_line(Vector2(0, -30), Vector2(0, 30), Color.GREEN, 2.0)
	
	if is_active and nearest_node:
		var start = Vector2.ZERO 
		var end = to_local(nearest_node.global_position)
		var dist = global_position.distance_to(nearest_node.global_position)
		
		var radius = 300.0
		if "district_radius" in nearest_node:
			radius = nearest_node.district_radius
			
		var is_in_range = dist <= radius
		var color = tether_color_valid if is_in_range else tether_color_invalid
		
		draw_line(start, end, color, 2.0)
		draw_circle(end, 5.0, color)

func _create_grid_outline(grid_size: Vector2i) -> void:
	_clear_grid_overlay()
	
	var tile_size = Vector2(64, 32)
	if SettlementManager and SettlementManager.has_method("get_active_grid_cell_size"):
		tile_size = SettlementManager.get_active_grid_cell_size()
	
	var half_w = tile_size.x * 0.5
	var half_h = tile_size.y * 0.5
	
	var basis_x = Vector2(half_w, half_h)
	var basis_y = Vector2(-half_w, half_h)
	
	var w = float(grid_size.x)
	var h = float(grid_size.y)
	
	var top_left_grid = Vector2(-w * 0.5, -h * 0.5)
	
	var p_top_left = (basis_x * top_left_grid.x) + (basis_y * top_left_grid.y)
	var p_top_right = (basis_x * (top_left_grid.x + w)) + (basis_y * top_left_grid.y)
	var p_bot_right = (basis_x * (top_left_grid.x + w)) + (basis_y * (top_left_grid.y + h))
	var p_bot_left = (basis_x * top_left_grid.x) + (basis_y * (top_left_grid.y + h))
	
	var rect = Line2D.new()
	rect.points = PackedVector2Array([
		p_top_left,
		p_top_right,
		p_bot_right,
		p_bot_left,
		p_top_left
	])
	
	rect.width = 2.0
	rect.default_color = Color(0.2, 1.0, 0.2, 0.8)
	grid_overlay.add_child(rect)

func _clear_grid_overlay() -> void:
	for child in grid_overlay.get_children(): child.queue_free()
