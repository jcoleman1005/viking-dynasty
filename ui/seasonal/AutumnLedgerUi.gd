## Handles the end-of-season accounting logic and display.
class_name AutumnLedgerUI
extends Control

# --- Nodes ---
@onready var settlement_name_label: Label = %SettlementName
@onready var food_stock_label: Label = %FoodStock
@onready var food_status_label: Label = %FoodStatus
@onready var wood_stock_label: Label = %WoodStock
@onready var wood_status_label: Label = %WoodStatus
@onready var outlook_label: Label = %WinterOutlookLabel
@onready var sign_button: Button = %SignButton

# --- State ---
var current_report: AutumnReport
var active_tween: Tween
var is_animation_finished: bool = false

# --- Configuration ---
const MAX_STORAGE_CAP_PLACEHOLDER: int = 999 # Placeholder for future storage system
const COLOR_OK = Color("55ff55") # Neon Green
const COLOR_FAIL = Color("ff5555") # Soft Red
const COLOR_WARN = Color("ffaa00") # Gold/Orange
const COLOR_TEXT_DEFAULT = Color("f0e6d2") # Antique White

func _ready() -> void:
	_setup_connections()
	visible = false
	_apply_text_colors()

func _apply_text_colors() -> void:
	var labels = [settlement_name_label, food_stock_label, wood_stock_label]
	for lbl in labels:
		if lbl: lbl.add_theme_color_override("font_color", COLOR_TEXT_DEFAULT)

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

func _animate_sequence() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	active_tween = create_tween()
	
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	
	# Initial set with full formula
	_update_resource_label(0, food_stock_label, current_report.winter_demand, current_report.harvest_yield)
	_update_resource_label(0, wood_stock_label, 0, 0)
	
	food_status_label.modulate.a = 0
	wood_status_label.modulate.a = 0
	outlook_label.modulate.a = 0
	
	var duration = 1.5
	active_tween.set_parallel(true)
	
	# Animate Food Stockpile using the complex formatter
	active_tween.tween_method(
		func(val): _update_resource_label(val, food_stock_label, current_report.winter_demand, current_report.harvest_yield),
		0, food_held, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Animate Wood Stockpile
	active_tween.tween_method(
		func(val): _update_resource_label(val, wood_stock_label, 0, 0),
		0, wood_held, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	active_tween.chain().tween_callback(_reveal_verdict)

## Updated Helper to show: [Stockpile] / [Cap] - [Consumption] + [Harvest]
func _update_resource_label(current_val: int, label: Label, demand: int, harvest: int) -> void:
	if not label: return
	
	# Format: Stockpile / Cap
	var base_str = "%d / %d" % [current_val, MAX_STORAGE_CAP_PLACEHOLDER]
	
	# Append math context if relevant (Consumption and Harvest)
	var math_str = ""
	if demand > 0:
		math_str += " - %d" % demand
	if harvest > 0:
		math_str += " + %d" % harvest
		
	label.text = base_str + math_str

func _reveal_verdict() -> void:
	is_animation_finished = true
	_hide_sign_button()
	
	# --- Fetch Fuzzy Display Data (Task 4.1) ---
	var forecast_ranges = EconomyManager.get_forecast_display_data()
	var food_range_txt = forecast_ranges.get(GameResources.FOOD, {}).get("text", "???")
	var wood_range_txt = forecast_ranges.get(GameResources.WOOD, {}).get("text", "???")
	
	# --- Food Status ---
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var total_food_available = food_held + current_report.harvest_yield
	var is_food_safe = total_food_available >= current_report.winter_demand
	
	# Update Text with Range
	var food_verdict = "[ SECURE ]" if is_food_safe else "[ STARVATION RISK ]"
	food_status_label.text = "%s\n(Est. %s)" % [food_verdict, food_range_txt]
	
	food_status_label.modulate = COLOR_OK if is_food_safe else COLOR_FAIL
	
	# --- Wood Status ---
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	
	# Exact math for the verdict color (Task 1.5 logic)
	var required_heating = EconomyManager.get_total_heating_demand()
	var is_wood_ok = wood_held >= required_heating
	
	# Update Text with Range
	var wood_verdict = "[ STOCKPILED ]" if is_wood_ok else "[ LOW ]"
	wood_status_label.text = "%s\n(Est. %s)" % [wood_verdict, wood_range_txt]
	
	wood_status_label.modulate = COLOR_OK if is_wood_ok else COLOR_WARN
	
	# --- Animations ---
	var fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property(food_status_label, "modulate:a", 1.0, 0.5)
	fade_tween.tween_property(wood_status_label, "modulate:a", 1.0, 0.5)
	
	# --- Winter Outlook ---
	var outlook_text = "WINTER OUTLOOK: " + ("SECURE" if is_food_safe else "DANGEROUS")
	if WinterManager.upcoming_severity == WinterManager.WinterSeverity.HARSH:
		outlook_text += " (HARSH)"
	elif WinterManager.upcoming_severity == WinterManager.WinterSeverity.MILD:
		outlook_text += " (MILD)"
		
	outlook_label.text = outlook_text
	outlook_label.modulate = COLOR_OK if is_food_safe else COLOR_FAIL
	fade_tween.tween_property(outlook_label, "modulate:a", 1.0, 0.5)
	
	EventBus.autumn_resolved.emit()
	Loggie.msg("Autumn Ledger: Verdict revealed with fuzzy ranges.").domain(LogDomains.UI).info()

func _on_sign_pressed() -> void:
	if not is_animation_finished:
		_skip_animation()

func _skip_animation() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	
	_update_resource_label(food_held, food_stock_label, current_report.winter_demand, current_report.harvest_yield)
	_update_resource_label(wood_held, wood_stock_label, 0, 0)
	
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
