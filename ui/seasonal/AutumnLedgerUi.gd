## Handles the end-of-season accounting logic and display.
class_name AutumnLedgerUI
extends Control

# --- Nodes ---
@onready var settlement_name_label: Label = %SettlementName
@onready var outlook_label: Label = %WinterOutlookLabel
@onready var sign_button: Button = %SignButton

# --- NEW: Breakdown Labels (Replaces old stock/status labels) ---
@onready var food_starting_label: Label = %FoodStartingStockLabel
@onready var food_harvest_label: Label = %FoodHarvestLabel
@onready var food_demand_label: Label = %FoodDemandLabel
@onready var food_final_label: Label = %FoodFinalResultLabel

@onready var wood_starting_label: Label = %WoodStartingStockLabel2
@onready var wood_harvest_label: Label = %WoodHarvestLabel2
@onready var wood_demand_label: Label = %WoodDemandLabel2
@onready var wood_final_label: Label = %WoodFinalResultLabel2


# --- State ---
var current_report: AutumnReport
var active_tween: Tween
var is_animation_finished: bool = false

# --- Configuration ---
const COLOR_OK = Color("55ff55") # Neon Green
const COLOR_FAIL = Color("ff5555") # Soft Red
const COLOR_WARN = Color("ffaa00") # Gold/Orange
const COLOR_TEXT_DEFAULT = Color("f0e6d2") # Antique White

func _ready() -> void:
	_setup_connections()
	visible = false
	# _apply_text_colors() is no longer needed as colors are set in the animation

func _setup_connections() -> void:
	if sign_button and not sign_button.pressed.is_connected(_on_sign_pressed):
		sign_button.pressed.connect(_on_sign_pressed)
	
	if EventBus.has_signal("season_changed"):
		EventBus.season_changed.connect(_on_season_changed)
		
	if EventBus.has_signal("advance_season_requested"):
		EventBus.advance_season_requested.connect(_on_advance_requested)

func _on_season_changed(new_season_name: String, _context_data: Dictionary) -> void:
	if new_season_name == "Autumn":
		await get_tree().process_frame
		_start_ritual(_context_data)

func _on_advance_requested() -> void:
	if visible:
		_close_ledger()

func _start_ritual(context_data: Dictionary) -> void:
	current_report = AutumnReport.new()
	current_report.init_from_context(context_data)
	
	var fresh_forecast = EconomyManager.get_winter_forecast()
	var fresh_food_demand = fresh_forecast.get(GameResources.FOOD, 0)
	
	if fresh_food_demand != current_report.winter_demand:
		Loggie.msg("AutumnLedger: Correcting Stale Forecast (%d -> %d)" % [current_report.winter_demand, fresh_food_demand]).domain(LogDomains.UI).info()
		current_report.winter_demand = fresh_food_demand

	modulate.a = 1.0
	visible = true
	move_to_front()
	is_animation_finished = false
	
	if sign_button:
		sign_button.text = "Skip Animation"
		sign_button.modulate.a = 1.0
		sign_button.show()
		sign_button.disabled = false 
	
	_populate_header()
	_animate_sequence()

func _populate_header() -> void:
	var settlement = SettlementManager.current_settlement
	var display_name = "Settlement"
	if settlement:
		var raw_name = settlement.resource_path.get_file().get_basename()
		if not raw_name.is_empty():
			display_name = raw_name.replace("_", " ").capitalize()
	
	var year = DynastyManager.get_current_year()
	settlement_name_label.text = "%s - Year %d" % [display_name, year]

# --- REFACTORED ANIMATION & DISPLAY LOGIC ---

func _animate_sequence() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# --- Initial State ---
	var labels_to_clear = [
		food_starting_label, food_harvest_label, food_demand_label, food_final_label,
		wood_starting_label, wood_harvest_label, wood_demand_label, wood_final_label,
		outlook_label
	]
	for lbl in labels_to_clear:
		if lbl:
			lbl.text = ""
			lbl.modulate.a = 0

	# --- Animation Sequence ---
	active_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	var harvest = current_report.harvest_yield
	var food_demand = current_report.winter_demand
	var wood_demand = EconomyManager.get_winter_wood_demand()
	
	var final_food = food_held + harvest - food_demand
	var final_wood = wood_held - wood_demand

	# Animate rows sequentially for clarity
	active_tween.tween_callback(func(): _animate_label_reveal(food_starting_label, "Starting Stock: %d" % food_held))
	active_tween.tween_interval(0.3)
	active_tween.tween_callback(func(): _animate_label_reveal(wood_starting_label, "Starting Stock: %d" % wood_held))
	active_tween.tween_interval(0.5)
	
	active_tween.tween_callback(func(): _animate_label_reveal(food_harvest_label, "Harvest: +%d" % harvest, COLOR_OK))
	active_tween.tween_interval(0.3)
	active_tween.tween_callback(func(): _animate_label_reveal(wood_harvest_label, "Gathered: +0"))
	active_tween.tween_interval(0.5)

	active_tween.tween_callback(func(): _animate_label_reveal(food_demand_label, "Winter Demand: -%d" % food_demand, COLOR_FAIL))
	active_tween.tween_interval(0.3)
	active_tween.tween_callback(func(): _animate_label_reveal(wood_demand_label, "Winter Upkeep: -%d" % wood_demand, COLOR_FAIL))
	active_tween.tween_interval(0.8)

	active_tween.tween_callback(func(): _animate_label_reveal(food_final_label, "Surplus/Deficit: %s%d" % ["+" if final_food >= 0 else "", final_food], COLOR_OK if final_food >= 0 else COLOR_FAIL))
	active_tween.tween_interval(0.3)
	active_tween.tween_callback(func(): _animate_label_reveal(wood_final_label, "Surplus/Deficit: %s%d" % ["+" if final_wood >= 0 else "", final_wood], COLOR_OK if final_wood >= 0 else COLOR_FAIL))

	active_tween.chain().tween_callback(_reveal_verdict)

func _animate_label_reveal(label: Label, text: String, color: Color = COLOR_TEXT_DEFAULT) -> void:
	if not label: return
	label.text = text
	label.add_theme_color_override("font_color", color)
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.4)

func _reveal_verdict() -> void:
	is_animation_finished = true
	_hide_sign_button()
	
	var current_stockpile = SettlementManager.current_settlement.treasury.duplicate()
	current_stockpile[GameResources.FOOD] = current_stockpile.get(GameResources.FOOD, 0) + current_report.harvest_yield
	var survival_verdict = EconomyManager.get_survival_verdict(current_stockpile)
	
	var outlook_text = "WINTER OUTLOOK: "
	var outlook_color = COLOR_OK

	match survival_verdict:
		EconomyManager.SurvivalVerdict.SECURE:
			outlook_text += "SECURE"
			outlook_color = COLOR_OK
		EconomyManager.SurvivalVerdict.UNCERTAIN:
			outlook_text += "UNCERTAIN"
			outlook_color = COLOR_WARN
		EconomyManager.SurvivalVerdict.CRITICAL:
			outlook_text += "CRITICAL"
			outlook_color = COLOR_FAIL
			
	if WinterManager.upcoming_severity == WinterManager.WinterSeverity.HARSH:
		outlook_text += " (HARSH)"
	elif WinterManager.upcoming_severity == WinterManager.WinterSeverity.MILD:
		outlook_text += " (MILD)"
		
	outlook_label.text = outlook_text
	outlook_label.add_theme_color_override("font_color", outlook_color)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(outlook_label, "modulate:a", 1.0, 0.5)
	
	EventBus.autumn_resolved.emit()
	Loggie.msg("Autumn Ledger: Verdict revealed from single source.").domain(LogDomains.UI).info()

func _on_sign_pressed() -> void:
	if not is_animation_finished:
		_skip_animation()

func _skip_animation() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	# Manually set all labels to their final state
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	var harvest = current_report.harvest_yield
	var food_demand = current_report.winter_demand
	var wood_demand = EconomyManager.get_winter_wood_demand()
	var final_food = food_held + harvest - food_demand
	var final_wood = wood_held - wood_demand
	
	_animate_label_reveal(food_starting_label, "Starting Stock: %d" % food_held)
	_animate_label_reveal(wood_starting_label, "Starting Stock: %d" % wood_held)
	_animate_label_reveal(food_harvest_label, "Harvest: +%d" % harvest, COLOR_OK)
	_animate_label_reveal(wood_harvest_label, "Gathered: +0")
	_animate_label_reveal(food_demand_label, "Winter Demand: -%d" % food_demand, COLOR_FAIL)
	_animate_label_reveal(wood_demand_label, "Winter Upkeep: -%d" % wood_demand, COLOR_FAIL)
	_animate_label_reveal(food_final_label, "Surplus/Deficit: %s%d" % ["+" if final_food >= 0 else "", final_food], COLOR_OK if final_food >= 0 else COLOR_FAIL)
	_animate_label_reveal(wood_final_label, "Surplus/Deficit: %s%d" % ["+" if final_wood >= 0 else "", final_wood], COLOR_OK if final_wood >= 0 else COLOR_FAIL)
	
	_reveal_verdict()

func _hide_sign_button() -> void:
	if not sign_button: return
	var btween = create_tween()
	btween.tween_property(sign_button, "modulate:a", 0.0, 0.4)
	btween.tween_callback(sign_button.hide)

func _close_ledger() -> void:
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_out.tween_callback(func(): visible = false)
	Loggie.msg("Autumn Ledger: Closing UI.").domain(LogDomains.UI).debug()
