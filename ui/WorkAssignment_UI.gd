# res://ui/WorkAssignment_UI.gd
extends CanvasLayer

signal assignments_confirmed(assignments: Dictionary)

@onready var total_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TotalPopLabel
@onready var available_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/AvailablePopLevel
@onready var sliders_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/SlidersContainer
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ConfirmButton

# Settings
var current_settlement: SettlementData
var temp_assignments: Dictionary = {}
var total_population: int = 0
var available_population: int = 0

# UI Element Cache
var sliders: Dictionary = {} # Key: category_name, Value: HSlider
var labels: Dictionary = {}  # Key: category_name, Value: Label

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	hide()

func setup(settlement: SettlementData) -> void:
	current_settlement = settlement
	total_population = settlement.population_total
	
	# Initialize temp assignments with defaults (0)
	temp_assignments = {
		"construction": 0,
		"food": 0,
		"wood": 0,
		"stone": 0,
		"gold": 0
	}
	
	_rebuild_ui()
	_update_calculations()
	show()

func _rebuild_ui() -> void:
	# Clear existing
	for child in sliders_container.get_children():
		child.queue_free()
	sliders.clear()
	labels.clear()
	
	# Create sliders for each category
	var categories = ["construction", "food", "wood", "stone", "gold"]
	
	for category in categories:
		_create_slider_row(category)

func _create_slider_row(category: String) -> void:
	var row = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = category.capitalize()
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)
	
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = total_population
	slider.value = 0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(category))
	row.add_child(slider)
	sliders[category] = slider
	
	var value_label = Label.new()
	value_label.text = "0"
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	labels[category] = value_label
	
	sliders_container.add_child(row)

func _on_slider_changed(value: float, category: String) -> void:
	var new_val = int(value)
	var old_val = temp_assignments[category]
	var _diff = new_val - old_val
	
	# Calculate current usage EXCLUDING this category's *new* potential value
	var current_usage = 0
	for key in temp_assignments:
		if key != category:
			current_usage += temp_assignments[key]
	
	# Validation: Can we afford this increase?
	if current_usage + new_val > total_population:
		# Clamp to max available
		new_val = total_population - current_usage
		sliders[category].set_value_no_signal(new_val)
	
	temp_assignments[category] = new_val
	_update_calculations()

func _update_calculations() -> void:
	var assigned_count = 0
	for key in temp_assignments:
		assigned_count += temp_assignments[key]
		
		# Update label text
		if labels.has(key):
			labels[key].text = str(temp_assignments[key])
	
	available_population = total_population - assigned_count
	
	total_pop_label.text = "Total Population: %d" % total_population
	available_pop_label.text = "Idle: %d" % available_population
	
	if available_population < 0:
		available_pop_label.modulate = Color.RED
		confirm_button.disabled = true
	else:
		available_pop_label.modulate = Color.GREEN
		confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	hide()
	assignments_confirmed.emit(temp_assignments)
