# res://ui/WorkAssignment_UI.gd
extends CanvasLayer

signal assignments_confirmed(assignments: Dictionary)

@onready var total_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TotalPopLabel
@onready var available_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/AvailablePopLabel
@onready var sliders_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/SlidersContainer
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ConfirmButton

var prediction_label: RichTextLabel

var current_settlement: SettlementData
var temp_assignments: Dictionary = {}
var total_population: int = 0
var available_population: int = 0

# --- NEW: Capacity Tracking ---
var labor_capacities: Dictionary = {} 
# ------------------------------

var sliders: Dictionary = {} 
var labels: Dictionary = {}  

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.text = "Confirm Assignments"
	
	prediction_label = RichTextLabel.new()
	prediction_label.name = "PredictionLabel"
	prediction_label.fit_content = true
	prediction_label.bbcode_enabled = true
	prediction_label.custom_minimum_size = Vector2(0, 60)
	
	var container = $PanelContainer/MarginContainer/VBoxContainer
	container.add_child(prediction_label)
	container.move_child(prediction_label, container.get_child_count() - 2)
	
	hide()

func setup(settlement: SettlementData) -> void:
	current_settlement = settlement
	total_population = settlement.population_peasants
	
	# --- NEW: Fetch Capacities ---
	if SettlementManager.has_method("get_labor_capacities"):
		labor_capacities = SettlementManager.get_labor_capacities()
	else:
		labor_capacities = {"construction": 100, "food": 100, "wood": 100, "stone": 100}
	# -----------------------------
	
	# Initialize temp assignments (Gold Removed)
	temp_assignments = {
		"construction": 0,
		"food": 0,
		"wood": 0,
		"stone": 0
	}
	
	# Restore saved values if valid
	for key in temp_assignments:
		if current_settlement.worker_assignments.has(key):
			# Clamp to current capacity in case buildings were lost
			temp_assignments[key] = min(current_settlement.worker_assignments[key], labor_capacities.get(key, 0))
	
	_rebuild_ui()
	_update_calculations()
	show()

func _rebuild_ui() -> void:
	for child in sliders_container.get_children():
		child.queue_free()
	sliders.clear()
	labels.clear()
	
	# --- MODIFIED: Gold Removed ---
	var categories = ["construction", "food", "wood", "stone"]
	
	for category in categories:
		_create_slider_row(category)

func _create_slider_row(category: String) -> void:
	var row = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = category.capitalize()
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)
	
	# --- NEW: Capacity Logic ---
	var capacity = labor_capacities.get(category, 0)
	# The absolute max is capped by BOTH total population AND building capacity
	var max_assignable = min(total_population, capacity)
	
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = max_assignable
	slider.value = temp_assignments.get(category, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Disable slider if no capacity (e.g., no blueprints for construction)
	if max_assignable == 0:
		slider.editable = false
		slider.modulate = Color(0.5, 0.5, 0.5)
	
	slider.value_changed.connect(_on_slider_changed.bind(category))
	row.add_child(slider)
	sliders[category] = slider
	
	var value_label = Label.new()
	# Display as "Assigned / Capacity"
	value_label.text = "%d / %d" % [slider.value, capacity]
	value_label.custom_minimum_size = Vector2(60, 0)
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
	
	# Check Global Pop Limit
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
			var capacity = labor_capacities.get(key, 0)
			labels[key].text = "%d / %d" % [temp_assignments[key], capacity]
	
	available_population = total_population - assigned_count
	
	total_pop_label.text = "Total Population: %d" % total_population
	available_pop_label.text = "Idle: %d" % available_population
	
	if available_population < 0:
		available_pop_label.modulate = Color.RED
		confirm_button.disabled = true
	else:
		available_pop_label.modulate = Color.GREEN
		confirm_button.disabled = false

	if SettlementManager.has_method("simulate_turn"):
		var prediction = SettlementManager.simulate_turn(temp_assignments)
		_update_prediction_display(prediction)

func _update_prediction_display(data: Dictionary) -> void:
	if not prediction_label: return
	
	var text = "[b]Estimated Outcome:[/b]\n"
	var res = data.get("resources_gained", {})
	var res_str = ""
	
	for r in res:
		if res[r] > 0:
			var color_tag = "[color=white]"
			if r == "food": color_tag = "[color=salmon]"
			elif r == "wood": color_tag = "[color=burlywood]"
			
			res_str += "%s+%d %s[/color]  " % [color_tag, res[r], r.capitalize()]
	
	if res_str != "":
		text += res_str + "\n"
	else:
		text += "[color=gray]No resource gain[/color]\n"
		
	var completed = data.get("buildings_completing", [])
	if not completed.is_empty():
		text += "[color=green]Completing: " + ", ".join(completed) + "[/color]"
	
	prediction_label.text = text

func _on_confirm_pressed() -> void:
	hide()
	assignments_confirmed.emit(temp_assignments)
