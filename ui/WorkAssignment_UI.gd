# res://ui/WorkAssignment_UI.gd
extends CanvasLayer

signal assignments_confirmed(assignments: Dictionary)

@onready var total_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TotalPopLabel
@onready var available_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/AvailablePopLevel
@onready var sliders_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/SlidersContainer
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ConfirmButton

# --- NEW: Prediction Label ---
var prediction_label: RichTextLabel
# -----------------------------

# Settings
var current_settlement: SettlementData
var temp_assignments: Dictionary = {}
var total_population: int = 0
var available_population: int = 0

# UI Element Cache
var sliders: Dictionary = {} 
var labels: Dictionary = {}  

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.text = "Confirm Assignments"
	# --- NEW: Create Prediction Label Dynamically ---
	# We add it above the confirm button
	prediction_label = RichTextLabel.new()
	prediction_label.name = "PredictionLabel"
	prediction_label.fit_content = true
	prediction_label.bbcode_enabled = true
	prediction_label.custom_minimum_size = Vector2(0, 60)
	
	# Insert before the button (last child is usually button, so add as second to last)
	var container = $PanelContainer/MarginContainer/VBoxContainer
	container.add_child(prediction_label)
	container.move_child(prediction_label, container.get_child_count() - 2)
	# ------------------------------------------------
	
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
	for child in sliders_container.get_children():
		child.queue_free()
	sliders.clear()
	labels.clear()
	
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
	
	var current_usage = 0
	for key in temp_assignments:
		if key != category:
			current_usage += temp_assignments[key]
	
	if current_usage + new_val > total_population:
		new_val = total_population - current_usage
		sliders[category].set_value_no_signal(new_val)
	
	temp_assignments[category] = new_val
	_update_calculations()

func _update_calculations() -> void:
	var assigned_count = 0
	for key in temp_assignments:
		assigned_count += temp_assignments[key]
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

	# --- NEW: Call Prediction ---
	if SettlementManager.has_method("simulate_turn"):
		var prediction = SettlementManager.simulate_turn(temp_assignments)
		_update_prediction_display(prediction)

func _update_prediction_display(data: Dictionary) -> void:
	if not prediction_label: return
	
	var text = "[b]Estimated Outcome:[/b]\n"
	
	# Resources
	var res = data.get("resources_gained", {})
	var res_str = ""
	for r in res:
		if res[r] > 0:
			var color_tag = "[color=white]"
			if r == "food": color_tag = "[color=salmon]"
			elif r == "wood": color_tag = "[color=burlywood]"
			elif r == "gold": color_tag = "[color=gold]"
			
			res_str += "%s+%d %s[/color]  " % [color_tag, res[r], r.capitalize()]
	
	if res_str != "":
		text += res_str + "\n"
	else:
		text += "[color=gray]No resource gain[/color]\n"
		
	# Buildings
	var completed = data.get("buildings_completing", [])
	if not completed.is_empty():
		text += "[color=green]Completing: " + ", ".join(completed) + "[/color]"
	
	prediction_label.text = text

func _on_confirm_pressed() -> void:
	hide()
	assignments_confirmed.emit(temp_assignments)
