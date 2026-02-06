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
var can_interact: bool = false 

# --- Visual Configuration (High Contrast) ---
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
	if not sign_button.pressed.is_connected(_on_sign_pressed):
		sign_button.pressed.connect(_on_sign_pressed)
	
	if EventBus.has_signal("season_changed"):
		EventBus.season_changed.connect(_on_season_changed)

func _on_season_changed(new_season_name: String, context_data: Dictionary) -> void:
	if new_season_name == "Autumn":
		# FIX: Wait one frame to ensure WinterManager has processed the signal 
		# and rolled the new Severity/Weather before we display it.
		await get_tree().process_frame
		_start_ritual(context_data)

func _start_ritual(context_data: Dictionary) -> void:
	current_report = AutumnReport.new()
	current_report.init_from_context(context_data)
	
	# FIX: Force-refresh the winter demand using the Authoritative Source.
	# The 'context_data' might be stale (built before WinterManager rolled the dice).
	var fresh_forecast = EconomyManager.get_winter_forecast()
	var fresh_food_demand = fresh_forecast.get(GameResources.FOOD, 0)
	
	if fresh_food_demand != current_report.winter_demand:
		Loggie.msg("AutumnLedger: Correcting Stale Forecast (%d -> %d)" % [current_report.winter_demand, fresh_food_demand]).domain(LogDomains.UI).info()
		current_report.winter_demand = fresh_food_demand

	visible = true
	move_to_front()
	is_animation_finished = false
	can_interact = false
	
	sign_button.text = "Skip Animation"
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
	
	# Initial set
	_update_resource_label(0, food_stock_label, current_report.winter_demand)
	_update_resource_label(0, wood_stock_label, 0)
	
	food_status_label.modulate.a = 0
	wood_status_label.modulate.a = 0
	outlook_label.modulate.a = 0
	
	var duration = 1.5
	active_tween.set_parallel(true)
	
	# Animate Food
	active_tween.tween_method(_update_resource_label.bind(food_stock_label, current_report.winter_demand), 0, food_held, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Animate Wood
	active_tween.tween_method(_update_resource_label.bind(wood_stock_label, 0), 0, wood_held, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	active_tween.chain().tween_callback(_reveal_verdict)

## Generic helper to update label text: "Current / Demand"
func _update_resource_label(current_val: int, label: Label, demand: int) -> void:
	if demand > 0:
		label.text = "%d / %d" % [current_val, demand]
	else:
		label.text = "%d" % [current_val]

func _reveal_verdict() -> void:
	is_animation_finished = true
	sign_button.text = "Sign and Seal Ledger"
	
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var is_food_safe = food_held >= current_report.winter_demand
	
	if current_report.harvest_yield > 0:
		food_stock_label.text += " (+%d Harvest)" % current_report.harvest_yield
	
	var fade_tween = create_tween().set_parallel(true)
	
	# Food Status
	food_status_label.text = "[ SECURE ]" if is_food_safe else "[ STARVATION RISK ]"
	food_status_label.modulate = COLOR_OK if is_food_safe else COLOR_FAIL
	fade_tween.tween_property(food_status_label, "modulate:a", 1.0, 0.5)
	
	# Wood Status
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	var is_wood_ok = wood_held > 20 
	wood_status_label.text = "[ STOCKPILED ]" if is_wood_ok else "[ LOW ]"
	# Use Warning Color (Orange/Gold) for low wood instead of Red
	wood_status_label.modulate = COLOR_OK if is_wood_ok else COLOR_WARN
	fade_tween.tween_property(wood_status_label, "modulate:a", 1.0, 0.5)
	
	# Winter Outlook
	var outlook_text = "WINTER OUTLOOK: " + ("SECURE" if is_food_safe else "DANGEROUS")
	
	# NEW: Add context for Severity
	if WinterManager.upcoming_severity == WinterManager.WinterSeverity.HARSH:
		outlook_text += " (HARSH)"
	elif WinterManager.upcoming_severity == WinterManager.WinterSeverity.MILD:
		outlook_text += " (MILD)"
		
	outlook_label.text = outlook_text
	outlook_label.modulate = COLOR_OK if is_food_safe else COLOR_FAIL
	fade_tween.tween_property(outlook_label, "modulate:a", 1.0, 0.5)
	
	get_tree().create_timer(0.5).timeout.connect(func(): can_interact = true)

func _on_sign_pressed() -> void:
	if not is_animation_finished:
		_skip_animation()
	elif can_interact:
		_commit_and_close()

func _skip_animation() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	var food_held = int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held = int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	
	_update_resource_label(food_held, food_stock_label, current_report.winter_demand)
	_update_resource_label(wood_held, wood_stock_label, 0)
	
	_reveal_verdict()

func _commit_and_close() -> void:
	Loggie.msg("Autumn Ledger Signed.").domain(LogDomains.ECONOMY).info()
	EventBus.autumn_resolved.emit()
	EventBus.advance_season_requested.emit()
	visible = false

# --- Debugging Helper ---
func _build_live_context() -> Dictionary:
	var ctx = {}
	if SettlementManager.current_settlement:
		ctx["treasury"] = SettlementManager.current_settlement.treasury.duplicate()
	else:
		ctx["treasury"] = {}
	ctx["forecast"] = EconomyManager.get_winter_forecast()
	ctx["payout"] = {GameResources.FOOD: 0}
	return ctx
