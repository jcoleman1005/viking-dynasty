@tool
extends Control
class_name EnemyBaseEditorDock

# Data/state
var current_settlement: SettlementData
var available_buildings: Array[BuildingData] = []
var selected_building: BuildingData = null

# Undo/Redo system
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS := 50

# Scene-driven UI references
@onready var main_container: VBoxContainer = $VBoxContainer
@onready var toolbar: HBoxContainer = $VBoxContainer/Toolbar
@onready var content_hsplit: HSplitContainer = $VBoxContainer/ContentHSplit
@onready var grid_scroll: ScrollContainer = $VBoxContainer/ContentHSplit/GridScrollContainer
@onready var right_panel: VBoxContainer = $VBoxContainer/ContentHSplit/RightPanel

@onready var grid_editor: SettlementGridEditor = $VBoxContainer/ContentHSplit/GridScrollContainer/SettlementGridEditor
@onready var building_palette: BuildingPalette = $VBoxContainer/ContentHSplit/RightPanel/BuildingPalette
@onready var property_panel: SettlementProperties = $VBoxContainer/ContentHSplit/RightPanel/SettlementProperties

@onready var new_button: Button = $VBoxContainer/Toolbar/New
@onready var load_button: Button = $VBoxContainer/Toolbar/Load
@onready var save_button: Button = $VBoxContainer/Toolbar/Save
@onready var save_as_button: Button = $VBoxContainer/Toolbar/SaveAs
@onready var validate_button: Button = $VBoxContainer/Toolbar/Validate
@onready var templates_button: MenuButton = $VBoxContainer/Toolbar/Templates
@onready var current_file_label: Label = $VBoxContainer/Toolbar/CurrentFileLabel
@onready var file_dialog: FileDialog = $VBoxContainer/FileDialog

func _ready() -> void:
	name = "EnemyBaseEditorDock"
	# Defer initialization to ensure children (_ready) have run in editor
	call_deferred("_initialize_dock")

func _initialize_dock() -> void:
	# Wire UI and signals (no programmatic node creation)
	_connect_signals()
	_setup_templates_menu()
	_setup_file_dialog()
	
	# Initialize systems after children are ready (call_deferred ensures this)
	load_available_buildings()
	create_new_settlement()

func _connect_signals() -> void:
	# Toolbar
	new_button.pressed.connect(_on_new_pressed)
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	save_as_button.pressed.connect(_on_save_as_pressed)
	validate_button.pressed.connect(_on_validate_pressed)
	
	# Grid editor
	grid_editor.building_placed.connect(_on_building_placed)
	grid_editor.building_removed.connect(_on_building_removed)
	grid_editor.building_selected.connect(_on_building_selected)
	
	# Palette
	building_palette.building_selected.connect(_on_palette_building_selected)
	
	# Properties
	property_panel.treasury_changed.connect(_on_treasury_changed)
	property_panel.units_changed.connect(_on_units_changed)

func _setup_templates_menu() -> void:
	var popup := templates_button.get_popup()
	popup.clear()
	for template_name in SettlementTemplates.get_template_names():
		popup.add_item(template_name)
	if not popup.id_pressed.is_connected(_on_template_selected):
		popup.id_pressed.connect(_on_template_selected)
	# Ensure button is enabled and repopulates when opening
	templates_button.disabled = false
	if not templates_button.about_to_popup.is_connected(_on_templates_about_to_popup):
		templates_button.about_to_popup.connect(_on_templates_about_to_popup)

func _on_templates_about_to_popup() -> void:
	var popup := templates_button.get_popup()
	popup.clear()
	for template_name in SettlementTemplates.get_template_names():
		popup.add_item(template_name)

func _setup_file_dialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://data/settlements"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.tres; Settlement Data Files")
	if not file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.connect(_on_file_selected)

# --- Data ops ---
func load_available_buildings() -> void:
	available_buildings.clear()
	var dir := DirAccess.open("res://data/buildings")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				print("Enemy Base Editor: Attempting to load building file: ", file_name)
				var building_data := load("res://data/buildings/" + file_name) as BuildingData
				if building_data:
					print("Enemy Base Editor: Successfully loaded building: ", building_data.display_name)
					available_buildings.append(building_data)
				else:
					print("Enemy Base Editor: Failed to load building from: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Enemy Base Editor: Failed to open buildings directory")
	
	# Update building palette
	if building_palette:
		print("Enemy Base Editor: Setting buildings in palette: ", available_buildings.size())
		building_palette.set_buildings(available_buildings)
	
	print("Enemy Base Editor: Loaded %d building types" % available_buildings.size())

func create_new_settlement() -> void:
	current_settlement = SettlementData.new()
	current_settlement.treasury = {"gold": 1000, "wood": 500, "food": 300, "stone": 200}
	current_settlement.placed_buildings = []
	current_settlement.garrisoned_units = {}
	_update_ui()
	_clear_undo_history()
	current_file_label.text = "New Settlement"
	print("Enemy Base Editor: Created new settlement")

func _update_ui() -> void:
	if grid_editor:
		grid_editor.set_settlement(current_settlement)
	if property_panel:
		property_panel.set_settlement(current_settlement)
	# Update save button state
	if save_button:
		save_button.disabled = not current_settlement or current_settlement.resource_path.is_empty()

# --- Toolbar handlers ---
func _on_new_pressed() -> void:
	create_new_settlement()

func _on_load_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_save_pressed() -> void:
	if not current_settlement:
		return
	if current_settlement.resource_path.is_empty():
		_on_save_as_pressed()
		return
	_save_settlement(current_settlement.resource_path)

func _on_save_as_pressed() -> void:
	if not current_settlement:
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_validate_pressed() -> void:
	if not current_settlement:
		return
	var errors := _validate_settlement()
	var dialog := AcceptDialog.new()
	# Avoid saving this dialog into the scene
	add_child(dialog)
	dialog.owner = null
	if errors.is_empty():
		dialog.dialog_text = "✅ Settlement validation passed!\n\nNo errors found."
		dialog.title = "Validation Success"
	else:
		dialog.dialog_text = "❌ Settlement validation failed:\n\n" + "\n".join(errors)
		dialog.title = "Validation Errors"
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_load_settlement(path)
	else:
		_save_settlement(path)

# --- Load/Save ---
func _load_settlement(path: String) -> void:
	var settlement := load(path) as SettlementData
	if not settlement:
		_show_error("Failed to load settlement from: " + path)
		return
	current_settlement = settlement
	current_settlement.resource_path = path
	_update_ui()
	_clear_undo_history()
	current_file_label.text = path.get_file()
	print("Enemy Base Editor: Loaded settlement from " + path)

func _save_settlement(path: String) -> void:
	if not current_settlement:
		return
	current_settlement.resource_path = path
	var error := ResourceSaver.save(current_settlement, path)
	if error == OK:
		current_file_label.text = path.get_file()
		_update_ui()
		print("Enemy Base Editor: Saved settlement to " + path)
		_show_success("Settlement saved successfully!")
	else:
		_show_error("Failed to save settlement to: " + path + "\nError: " + str(error))

# --- Building placement callbacks ---
func _on_palette_building_selected(building_data: BuildingData) -> void:
	selected_building = building_data
	if grid_editor:
		grid_editor.set_selected_building(building_data)

func _on_building_placed(building_data: BuildingData, position: Vector2i) -> void:
	if not current_settlement:
		return
	_save_state_for_undo()
	var building_entry := {
		"resource_path": building_data.resource_path,
		"grid_position": position
	}
	current_settlement.placed_buildings.append(building_entry)
	if grid_editor:
		grid_editor.set_settlement(current_settlement)
	print("Enemy Base Editor: Placed %s at %s" % [building_data.display_name, position])

func _on_building_removed(position: Vector2i) -> void:
	if not current_settlement:
		return
	_save_state_for_undo()
	for i in range(current_settlement.placed_buildings.size() - 1, -1, -1):
		var building := current_settlement.placed_buildings[i]
		if building["grid_position"] == position:
			current_settlement.placed_buildings.remove_at(i)
			print("Enemy Base Editor: Removed building at %s" % position)
			break
	if grid_editor:
		grid_editor.set_settlement(current_settlement)

func _on_building_selected(building_data: BuildingData, position: Vector2i) -> void:
	# TODO: Hook into properties for per-building details if needed
	pass

# --- Property callbacks ---
func _on_treasury_changed(new_treasury: Dictionary) -> void:
	if current_settlement:
		current_settlement.treasury = new_treasury

func _on_units_changed(new_units: Dictionary) -> void:
	if current_settlement:
		current_settlement.garrisoned_units = new_units

# --- Validation ---
func _validate_settlement() -> Array[String]:
	var errors: Array[String] = []
	if not current_settlement:
		errors.append("No settlement loaded")
		return errors
	# Overlap check
	var occupied_positions: Array[Vector2i] = []
	for building_entry in current_settlement.placed_buildings:
		var pos: Vector2i = building_entry["grid_position"]
		if pos in occupied_positions:
			errors.append("Building overlap detected at position " + str(pos))
		else:
			occupied_positions.append(pos)
	# Bounds check (matches SettlementGridEditor constants)
	for building_entry in current_settlement.placed_buildings:
		var pos: Vector2i = building_entry["grid_position"]
		if pos.x < 0 or pos.x >= 120 or pos.y < 0 or pos.y >= 80:
			errors.append("Building at " + str(pos) + " is outside grid bounds")
	# Essential building
	var has_main_hall := false
	for building_entry in current_settlement.placed_buildings:
		var building_data := load(building_entry["resource_path"]) as BuildingData
		if building_data and "hall" in building_data.display_name.to_lower():
			has_main_hall = true
			break
	if not has_main_hall:
		errors.append("Settlement should have a main hall or similar central building")
	return errors

# --- Undo helpers ---
func _save_state_for_undo() -> void:
	if not current_settlement:
		return
	var state := {
		"buildings": current_settlement.placed_buildings.duplicate(true),
		"treasury": current_settlement.treasury.duplicate(),
		"units": current_settlement.garrisoned_units.duplicate()
	}
	undo_stack.append(state)
	redo_stack.clear()
	while undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()

func _clear_undo_history() -> void:
	undo_stack.clear()
	redo_stack.clear()

# --- UI helpers ---
func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "❌ Error: " + message
	dialog.title = "Error"
	add_child(dialog)
	dialog.owner = null
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_success(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "✅ " + message
	dialog.title = "Success"
	add_child(dialog)
	dialog.owner = null
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

# --- Templates ---
func _on_template_selected(id: int) -> void:
	var template_names := SettlementTemplates.get_template_names()
	if id < 0 or id >= template_names.size():
		return
	var template_name := template_names[id]
	var dialog := ConfirmationDialog.new()
	dialog.title = "Load Template: " + template_name
	dialog.dialog_text = SettlementTemplates.get_template_description(template_name) + "\n\nThis will replace the current settlement. Continue?"
	dialog.confirmed.connect(_load_template.bind(template_name))
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.owner = null
	dialog.popup_centered()

func _load_template(template_name: String) -> void:
	_save_state_for_undo()
	current_settlement = SettlementTemplates.create_template_by_name(template_name)
	_update_ui()
	current_file_label.text = "Template: " + template_name
	_show_success("Loaded template: " + template_name)
	print("Enemy Base Editor: Loaded template '%s' with %d buildings" % [template_name, current_settlement.placed_buildings.size()])

# Legacy function (kept for compatibility)
func show_legacy_analysis() -> void:
	if not current_settlement:
		_show_error("No settlement loaded for analysis")
		return
	print("=== ENEMY BASE LAYOUT ANALYSIS ===")
	print("Buildings: %d" % current_settlement.placed_buildings.size())
	for i in range(current_settlement.placed_buildings.size()):
		var building = current_settlement.placed_buildings[i]
		var pos: Vector2i = building["grid_position"]
		var building_data: BuildingData = load(building["resource_path"])
		var name := building_data.display_name if building_data else "Unknown"
		print("%d. %s @ %d,%d" % [i + 1, name, pos.x, pos.y])
	print("=== ANALYSIS COMPLETE ===")
