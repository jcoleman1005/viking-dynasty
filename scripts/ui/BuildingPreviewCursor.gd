#res://scripts/ui/BuildingPreviewCursor.gd
extends Node2D
class_name BuildingPreviewCursor

const ISO_PLACEHOLDER_SCRIPT = "res://scripts/utility/IsoPlaceholder.gd"

# --- Components ---
var current_building_data: BuildingData
var preview_visuals: Node2D 
var is_active: bool = false
var error_label: Label 

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

signal placement_completed
signal placement_cancelled

func _ready() -> void:
	z_index = 100 
	
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
	
	EventBus.building_ready_for_placement.connect(set_building_preview)
	
	visible = false
	set_process(false)
	set_process_input(false)

func set_building_preview(building_data: BuildingData) -> void:
	if not building_data: return
	current_building_data = building_data
	
	_cleanup_preview()
	
	# --- 1. Determine Visuals ---
	var tex_to_use: Texture2D = null
	
	# FIX: Prioritize the In-Game Sprite (building_texture) over the UI Icon
	if "building_texture" in building_data and building_data.building_texture:
		tex_to_use = building_data.building_texture
	# Priority 2: Extract from Scene (AI/Generated Content)
	elif building_data.scene_to_spawn:
		tex_to_use = _extract_texture_from_scene(building_data.scene_to_spawn)
	# Priority 3: Fallback to Icon (better than nothing, but might be a square)
	elif building_data.icon:
		tex_to_use = building_data.icon
	
	if tex_to_use:
		# A. Create Sprite
		var sprite = Sprite2D.new()
		sprite.texture = tex_to_use
		sprite.centered = true
		sprite.offset = Vector2(0, -tex_to_use.get_height() / 2.0)
		preview_visuals = sprite
	else:
		# B. Create Procedural Placeholder
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

func _input(event: InputEvent) -> void:
	if not is_active: return
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_building()
			get_viewport().set_input_as_handled() 
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()
			get_viewport().set_input_as_handled()

func _try_place_building() -> void:
	if not is_active or not can_place: return
	
	if SettlementManager:
		SettlementManager.place_building(current_building_data, current_grid_pos, true)
		EventBus.purchase_successful.emit("Construction Started")
	
	placement_completed.emit()
	
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_preview()

func cancel_preview() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_process_input(false)
	
	current_building_data = null
	_cleanup_preview()
	
	placement_cancelled.emit()
	Loggie.msg("Placement Cancelled").domain(LogDomains.UI).debug()

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
		
	# Isometric Basis Vectors (Standard Iso Down)
	# Moving 1 in Grid X moves (32, 16) in pixels
	# Moving 1 in Grid Y moves (-32, 16) in pixels
	var half_w = tile_size.x * 0.5 # 32
	var half_h = tile_size.y * 0.5 # 16
	
	var basis_x = Vector2(half_w, half_h)
	var basis_y = Vector2(-half_w, half_h)
	
	var w = float(grid_size.x)
	var h = float(grid_size.y)
	
	# Calculate Corners relative to Center (0,0 local)
	# Center of grid (w, h) is at (w/2, h/2)
	# So Top-Left (0,0) is at (-w/2, -h/2)
	
	var top_left_grid = Vector2(-w * 0.5, -h * 0.5)
	
	# Convert grid corners to pixel offsets
	var p_top_left = (basis_x * top_left_grid.x) + (basis_y * top_left_grid.y)
	var p_top_right = (basis_x * (top_left_grid.x + w)) + (basis_y * top_left_grid.y)
	var p_bot_right = (basis_x * (top_left_grid.x + w)) + (basis_y * (top_left_grid.y + h))
	var p_bot_left = (basis_x * top_left_grid.x) + (basis_y * (top_left_grid.y + h))
	
	var rect = Line2D.new()
	# Draw loop: TL -> TR -> BR -> BL -> TL
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
