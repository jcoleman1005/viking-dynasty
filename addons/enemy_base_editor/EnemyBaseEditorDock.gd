@tool
extends Control
class_name EnemyBaseEditorDock

# Core components
var current_settlement: SettlementData
var grid_editor: SettlementGridEditor
var building_palette: BuildingPalette
var property_panel: SettlementProperties

# UI References
@onready var main_container: VBoxContainer = $VBoxContainer
@onready var toolbar: HBoxContainer = $VBoxContainer/Toolbar
@onready var content_hsplit: HSplitContainer = $VBoxContainer/ContentHSplit
@onready var grid_scroll: ScrollContainer = $VBoxContainer/ContentHSplit/GridScrollContainer
@onready var right_panel: VBoxContainer = $VBoxContainer/ContentHSplit/RightPanel

# UI Elements
var new_button: Button
var load_button: Button
var save_button: Button
var save_as_button: Button
var validate_button: Button
var file_dialog: FileDialog
var current_file_label: Label

# Available buildings cache
var available_buildings: Array[BuildingData] = []

# Selected building for placement
var selected_building: BuildingData = null

# Undo/Redo system
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS = 50

func _ready():
	name = "Enemy Base Editor"
	setup_ui()
	load_available_buildings()
	create_new_settlement()

func setup_ui():
	# Create main layout
	if not main_container:
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		add_child(vbox)
		main_container = vbox
	
	# Create toolbar
	create_toolbar()
	
	# Create content area
	create_content_area()
	
	# Setup file dialog
	setup_file_dialog()

func create_toolbar():
	var toolbar_container = HBoxContainer.new()
	toolbar_container.name = "Toolbar"
	main_container.add_child(toolbar_container)
	toolbar = toolbar_container
	
	# File operations
	new_button = Button.new()
	new_button.text = "New"
	new_button.tooltip_text = "Create a new settlement"
	new_button.pressed.connect(_on_new_pressed)
	toolbar.add_child(new_button)
	
	load_button = Button.new()
	load_button.text = "Load"
	load_button.tooltip_text = "Load an existing settlement"
	load_button.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_button)
	
	save_button = Button.new()
	save_button.text = "Save"
	save_button.tooltip_text = "Save current settlement"
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)
	
	save_as_button = Button.new()
	save_as_button.text = "Save As"
	save_as_button.tooltip_text = "Save settlement with new name"
	save_as_button.pressed.connect(_on_save_as_pressed)
	toolbar.add_child(save_as_button)
	
	# Add separator
	var separator1 = VSeparator.new()
	toolbar.add_child(separator1)
	
	# Templates dropdown
	var templates_button = MenuButton.new()
	templates_button.text = "Templates"
	templates_button.tooltip_text = "Load settlement templates"
	var templates_popup = templates_button.get_popup()
	for template_name in SettlementTemplates.get_template_names():
		templates_popup.add_item(template_name)
	templates_popup.id_pressed.connect(_on_template_selected)
	toolbar.add_child(templates_button)
	
	# Add separator
	var separator2 = VSeparator.new()
	toolbar.add_child(separator2)
	
	# Validation
	validate_button = Button.new()
	validate_button.text = "Validate"
	validate_button.tooltip_text = "Check settlement for errors"
	validate_button.pressed.connect(_on_validate_pressed)
	toolbar.add_child(validate_button)
	
	# Current file label
	current_file_label = Label.new()
	current_file_label.text = "New Settlement"
	current_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(current_file_label)

func create_content_area():
	var hsplit = HSplitContainer.new()
	hsplit.name = "ContentHSplit"
	hsplit.split_offset = 600
	main_container.add_child(hsplit)
	content_hsplit = hsplit
	
	# Left side - Grid editor
	var scroll = ScrollContainer.new()
	scroll.name = "GridScrollContainer"
	scroll.custom_minimum_size = Vector2(600, 400)
	hsplit.add_child(scroll)
	grid_scroll = scroll
	
	# Create grid editor
	grid_editor = SettlementGridEditor.new()
	grid_editor.building_placed.connect(_on_building_placed)
	grid_editor.building_removed.connect(_on_building_removed)
	grid_editor.building_selected.connect(_on_building_selected)
	scroll.add_child(grid_editor)
	
	# Right side - Controls
	var right_vbox = VBoxContainer.new()
	right_vbox.name = "RightPanel"
	right_vbox.custom_minimum_size = Vector2(300, 0)
	hsplit.add_child(right_vbox)
	right_panel = right_vbox
	
	# Building palette
	building_palette = BuildingPalette.new()
	building_palette.building_selected.connect(_on_palette_building_selected)
	right_panel.add_child(building_palette)
	
	# Property panel
	property_panel = SettlementProperties.new()
	property_panel.treasury_changed.connect(_on_treasury_changed)
	property_panel.units_changed.connect(_on_units_changed)
	right_panel.add_child(property_panel)

func setup_file_dialog():
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.tres", "Settlement Data Files")
	file_dialog.current_dir = "res://data/settlements"
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

func load_available_buildings():
	available_buildings.clear()
	
	# Load all building data files
	var dir = DirAccess.open("res://data/buildings")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var building_data = load("res://data/buildings/" + file_name) as BuildingData
				if building_data:
					available_buildings.append(building_data)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Update building palette
	if building_palette:
		building_palette.set_buildings(available_buildings)
	
	print("Enemy Base Editor: Loaded %d building types" % available_buildings.size())

func create_new_settlement():
	current_settlement = SettlementData.new()
	current_settlement.treasury = {"gold": 1000, "wood": 500, "food": 300, "stone": 200}
	current_settlement.placed_buildings = []
	current_settlement.garrisoned_units = {}
	
	_update_ui()
	_clear_undo_history()
	current_file_label.text = "New Settlement"
	print("Enemy Base Editor: Created new settlement")

func _update_ui():
	if grid_editor:
		grid_editor.set_settlement(current_settlement)
	if property_panel:
		property_panel.set_settlement(current_settlement)
	
	# Update save button state
	if save_button:
		save_button.disabled = not current_settlement or current_settlement.resource_path.is_empty()

func _on_new_pressed():
	create_new_settlement()

func _on_load_pressed():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_save_pressed():
	if not current_settlement:
		return
	
	if current_settlement.resource_path.is_empty():
		_on_save_as_pressed()
		return
	
	_save_settlement(current_settlement.resource_path)

func _on_save_as_pressed():
	if not current_settlement:
		return
	
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_validate_pressed():
	if not current_settlement:
		return
	
	var errors = _validate_settlement()
	var dialog = AcceptDialog.new()
	
	if errors.is_empty():
		dialog.dialog_text = "✅ Settlement validation passed!\n\nNo errors found."
		dialog.title = "Validation Success"
	else:
		dialog.dialog_text = "❌ Settlement validation failed:\n\n" + "\n".join(errors)
		dialog.title = "Validation Errors"
	
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_file_selected(path: String):
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_load_settlement(path)
	else:
		_save_settlement(path)

func _load_settlement(path: String):
	var settlement = load(path) as SettlementData
	if not settlement:
		_show_error("Failed to load settlement from: " + path)
		return
	
	current_settlement = settlement
	current_settlement.resource_path = path
	_update_ui()
	_clear_undo_history()
	current_file_label.text = path.get_file()
	print("Enemy Base Editor: Loaded settlement from " + path)

func _save_settlement(path: String):
	if not current_settlement:
		return
	
	current_settlement.resource_path = path
	var error = ResourceSaver.save(current_settlement, path)
	
	if error == OK:
		current_file_label.text = path.get_file()
		_update_ui()
		print("Enemy Base Editor: Saved settlement to " + path)
		_show_success("Settlement saved successfully!")
	else:
		_show_error("Failed to save settlement to: " + path + "\nError: " + str(error))

func _on_palette_building_selected(building_data: BuildingData):
	selected_building = building_data
	if grid_editor:
		grid_editor.set_selected_building(building_data)

func _on_building_placed(building_data: BuildingData, position: Vector2i):
	if not current_settlement:
		return
	
	# Save state for undo
	_save_state_for_undo()
	
	# Add building to settlement data
	var building_entry = {
		"resource_path": building_data.resource_path,
		"grid_position": position
	}
	current_settlement.placed_buildings.append(building_entry)
	
	# Refresh the grid editor to show the new building
	if grid_editor:
		grid_editor.set_settlement(current_settlement)
	
	print("Enemy Base Editor: Placed %s at %s" % [building_data.display_name, position])

func _on_building_removed(position: Vector2i):
	if not current_settlement:
		return
	
	# Save state for undo
	_save_state_for_undo()
	
	# Remove building from settlement data
	for i in range(current_settlement.placed_buildings.size() - 1, -1, -1):
		var building = current_settlement.placed_buildings[i]
		if building["grid_position"] == position:
			current_settlement.placed_buildings.remove_at(i)
			print("Enemy Base Editor: Removed building at %s" % position)
			break
	
	# Refresh the grid editor to update the visual
	if grid_editor:
		grid_editor.set_settlement(current_settlement)

func _on_building_selected(building_data: BuildingData, position: Vector2i):
	# Update property panel to show building details
	pass

func _on_treasury_changed(new_treasury: Dictionary):
	if current_settlement:
		current_settlement.treasury = new_treasury

func _on_units_changed(new_units: Dictionary):
	if current_settlement:
		current_settlement.garrisoned_units = new_units

func _validate_settlement() -> Array[String]:
	var errors: Array[String] = []
	
	if not current_settlement:
		errors.append("No settlement loaded")
		return errors
	
	# Check for building overlaps
	var occupied_positions: Array[Vector2i] = []
	for building_entry in current_settlement.placed_buildings:
		var pos = building_entry["grid_position"]
		if pos in occupied_positions:
			errors.append("Building overlap detected at position " + str(pos))
		else:
			occupied_positions.append(pos)
	
	# Validate building positions are in bounds
	for building_entry in current_settlement.placed_buildings:
		var pos = building_entry["grid_position"]
		if pos.x < 0 or pos.x >= 120 or pos.y < 0 or pos.y >= 80:
			errors.append("Building at " + str(pos) + " is outside grid bounds")
	
	# Check if settlement has essential buildings
	var has_main_hall = false
	for building_entry in current_settlement.placed_buildings:
		var building_data = load(building_entry["resource_path"]) as BuildingData
		if building_data and "hall" in building_data.display_name.to_lower():
			has_main_hall = true
			break
	
	if not has_main_hall:
		errors.append("Settlement should have a main hall or similar central building")
	
	return errors

func _save_state_for_undo():
	if not current_settlement:
		return
	
	var state = {
		"buildings": current_settlement.placed_buildings.duplicate(true),
		"treasury": current_settlement.treasury.duplicate(),
		"units": current_settlement.garrisoned_units.duplicate()
	}
	
	undo_stack.append(state)
	redo_stack.clear()
	
	# Limit undo stack size
	while undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()

func _clear_undo_history():
	undo_stack.clear()
	redo_stack.clear()

func _show_error(message: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "❌ Error: " + message
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_success(message: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "✅ " + message
	dialog.title = "Success"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_template_selected(id: int):
	var template_names = SettlementTemplates.get_template_names()
	if id >= 0 and id < template_names.size():
		var template_name = template_names[id]
		
		# Show confirmation dialog with template description
		var dialog = ConfirmationDialog.new()
		dialog.title = "Load Template: " + template_name
		dialog.dialog_text = SettlementTemplates.get_template_description(template_name) + "

This will replace the current settlement. Continue?"
		
		dialog.confirmed.connect(_load_template.bind(template_name))
		dialog.canceled.connect(func(): dialog.queue_free())
		
		add_child(dialog)
		dialog.popup_centered()

func _load_template(template_name: String):
	# Save state for undo
	_save_state_for_undo()
	
	# Load template
	current_settlement = SettlementTemplates.create_template_by_name(template_name)
	_update_ui()
	current_file_label.text = "Template: " + template_name
	
	_show_success("Loaded template: " + template_name)
	print("Enemy Base Editor: Loaded template '%s' with %d buildings" % [template_name, current_settlement.placed_buildings.size()])

func show_legacy_analysis():
	# Legacy function for backwards compatibility
	if not current_settlement:
		_show_error("No settlement loaded for analysis")
		return
	
	print("=== ENEMY BASE LAYOUT ANALYSIS ===")
	print("Buildings: %d" % current_settlement.placed_buildings.size())
	
	for i in range(current_settlement.placed_buildings.size()):
		var building = current_settlement.placed_buildings[i]
		var pos = building["grid_position"]
		var building_data: BuildingData = load(building["resource_path"])
		var name = building_data.display_name if building_data else "Unknown"
		print("%d. %s @ %d,%d" % [i+1, name, pos.x, pos.y])
	
	print("=== ANALYSIS COMPLETE ===")
