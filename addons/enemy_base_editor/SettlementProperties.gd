@tool
extends VBoxContainer
class_name SettlementProperties

signal treasury_changed(new_treasury: Dictionary)
signal units_changed(new_units: Dictionary)

# UI Elements
var treasury_group: CollapsibleGroup
var units_group: CollapsibleGroup

# Treasury controls
var gold_spinbox: SpinBox
var wood_spinbox: SpinBox
var food_spinbox: SpinBox
var stone_spinbox: SpinBox

# Units controls
var units_container: VBoxContainer
var add_unit_button: Button
var unit_selection_dialog: AcceptDialog

# Data
var current_settlement: SettlementData
var available_units: Array[String] = []

func _ready():
	name = "SettlementProperties"
	setup_ui()
	load_available_units()

func setup_ui():
	# Header
	var header = Label.new()
	header.text = "Settlement Properties"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)
	
	var separator = HSeparator.new()
	add_child(separator)
	
	# Treasury section
	setup_treasury_section()
	
	# Units section
	setup_units_section()

func setup_treasury_section():
	treasury_group = CollapsibleGroup.new()
	treasury_group.title = "Treasury"
	treasury_group.expanded = true
	add_child(treasury_group)
	
	var treasury_container = VBoxContainer.new()
	treasury_group.add_child(treasury_container)
	
	# Gold
	var gold_container = create_resource_control("Gold:", 0, 99999)
	gold_spinbox = gold_container.get_child(1) as SpinBox
	gold_spinbox.value_changed.connect(_on_treasury_changed)
	treasury_container.add_child(gold_container)
	
	# Wood
	var wood_container = create_resource_control("Wood:", 0, 99999)
	wood_spinbox = wood_container.get_child(1) as SpinBox
	wood_spinbox.value_changed.connect(_on_treasury_changed)
	treasury_container.add_child(wood_container)
	
	# Food
	var food_container = create_resource_control("Food:", 0, 99999)
	food_spinbox = food_container.get_child(1) as SpinBox
	food_spinbox.value_changed.connect(_on_treasury_changed)
	treasury_container.add_child(food_container)
	
	# Stone
	var stone_container = create_resource_control("Stone:", 0, 99999)
	stone_spinbox = stone_container.get_child(1) as SpinBox
	stone_spinbox.value_changed.connect(_on_treasury_changed)
	treasury_container.add_child(stone_container)

func setup_units_section():
	units_group = CollapsibleGroup.new()
	units_group.title = "Garrisoned Units"
	units_group.expanded = false
	add_child(units_group)
	
	var units_main_container = VBoxContainer.new()
	units_group.add_child(units_main_container)
	
	# Add unit button
	add_unit_button = Button.new()
	add_unit_button.text = "Add Unit Type"
	add_unit_button.pressed.connect(_on_add_unit_pressed)
	units_main_container.add_child(add_unit_button)
	
	# Units list
	units_container = VBoxContainer.new()
	units_main_container.add_child(units_container)

func create_resource_control(label_text: String, min_val: float, max_val: float) -> HBoxContainer:
	var container = HBoxContainer.new()
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = 1
	spinbox.custom_minimum_size = Vector2(120, 0)
	container.add_child(spinbox)
	
	return container

func set_settlement(settlement: SettlementData):
	current_settlement = settlement
	_update_ui()

func _update_ui():
	if not current_settlement:
		return
	
	# Update treasury values
	gold_spinbox.value = current_settlement.treasury.get("gold", 0)
	wood_spinbox.value = current_settlement.treasury.get("wood", 0)
	food_spinbox.value = current_settlement.treasury.get("food", 0)
	stone_spinbox.value = current_settlement.treasury.get("stone", 0)
	
	# Update units
	_update_units_list()

func _update_units_list():
	# Clear existing unit controls
	for child in units_container.get_children():
		child.queue_free()
	
	if not current_settlement:
		return
	
	# Create controls for each unit type
	for unit_path in current_settlement.garrisoned_units:
		var count = current_settlement.garrisoned_units[unit_path]
		_create_unit_control(unit_path, count)

func _create_unit_control(unit_path: String, count: int):
	var container = HBoxContainer.new()
	units_container.add_child(container)
	
	# Unit name
	var unit_name = unit_path.get_file().get_basename()
	var label = Label.new()
	label.text = unit_name + ":"
	label.custom_minimum_size = Vector2(100, 0)
	container.add_child(label)
	
	# Count spinbox
	var spinbox = SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = 999
	spinbox.step = 1
	spinbox.value = count
	spinbox.custom_minimum_size = Vector2(80, 0)
	spinbox.value_changed.connect(_on_unit_count_changed.bind(unit_path))
	container.add_child(spinbox)
	
	# Remove button
	var remove_button = Button.new()
	remove_button.text = "X"
	remove_button.custom_minimum_size = Vector2(30, 0)
	remove_button.pressed.connect(_on_remove_unit_pressed.bind(unit_path))
	container.add_child(remove_button)

func load_available_units():
	available_units.clear()
	
	# Load all unit data files
	var dir = DirAccess.open("res://data/units")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				available_units.append("res://data/units/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _on_treasury_changed(value: float):
	if not current_settlement:
		return
	
	# Update settlement treasury
	current_settlement.treasury["gold"] = int(gold_spinbox.value)
	current_settlement.treasury["wood"] = int(wood_spinbox.value)
	current_settlement.treasury["food"] = int(food_spinbox.value)
	current_settlement.treasury["stone"] = int(stone_spinbox.value)
	
	# Emit signal
	treasury_changed.emit(current_settlement.treasury)

func _on_unit_count_changed(unit_path: String, new_count: float):
	if not current_settlement:
		return
	
	var count = int(new_count)
	if count <= 0:
		current_settlement.garrisoned_units.erase(unit_path)
	else:
		current_settlement.garrisoned_units[unit_path] = count
	
	# Emit signal
	units_changed.emit(current_settlement.garrisoned_units)

func _on_remove_unit_pressed(unit_path: String):
	if not current_settlement:
		return
	
	current_settlement.garrisoned_units.erase(unit_path)
	_update_units_list()
	
	# Emit signal
	units_changed.emit(current_settlement.garrisoned_units)

func _on_add_unit_pressed():
	_show_unit_selection_dialog()

func _show_unit_selection_dialog():
	# Create unit selection dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Select Unit Type"
	dialog.custom_minimum_size = Vector2(400, 300)
	add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)
	
	var units_list = VBoxContainer.new()
	scroll.add_child(units_list)
	
	# Add buttons for each available unit
	for unit_path in available_units:
		var button = Button.new()
		var unit_name = unit_path.get_file().get_basename()
		button.text = unit_name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_unit_selected.bind(unit_path, dialog))
		units_list.add_child(button)
	
	dialog.popup_centered()

func _on_unit_selected(unit_path: String, dialog: AcceptDialog):
	if not current_settlement:
		return
	
	# Add unit with count of 1
	current_settlement.garrisoned_units[unit_path] = 1
	_update_units_list()
	
	# Emit signal
	units_changed.emit(current_settlement.garrisoned_units)
	
	# Close dialog
	dialog.queue_free()

# CollapsibleGroup is now in its own file
