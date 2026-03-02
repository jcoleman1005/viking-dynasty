## Handles the Autumn phase UI.
## Phase 1: Skald Report (narrative summary, generated from year_event_log).
## Phase 2: Winter Readiness Assessment (existing ledger animation).
## Player sees narrative first, then clicks Continue to reveal numbers.
class_name AutumnLedgerUI
extends Control

const DEBT_OFFER_SCENE := "res://scenes/autumn/DebtOfferScreen.tscn"

# --- Existing ledger nodes ---
@onready var settlement_name_label: Label = %SettlementName
@onready var outlook_label: Label = %WinterOutlookLabel
@onready var sign_button: Button = %SignButton

@onready var food_starting_label: Label = %FoodStartingStockLabel
@onready var food_harvest_label: Label = %FoodHarvestLabel
@onready var food_demand_label: Label = %FoodDemandLabel
@onready var food_final_label: Label = %FoodFinalResultLabel

@onready var wood_starting_label: Label = %WoodStartingStockLabel2
@onready var wood_harvest_label: Label = %WoodHarvestLabel2
@onready var wood_demand_label: Label = %WoodDemandLabel2
@onready var wood_final_label: Label = %WoodFinalResultLabel2

# --- Dynamically-created Skald Report overlay ---
var _skald_overlay: Control = null
var _skald_label: RichTextLabel = null
var _continue_btn: Button = null

# --- State ---
var current_report: AutumnReport
var active_tween: Tween
var is_animation_finished: bool = false

# --- Configuration ---
const COLOR_OK           = Color("55ff55")
const COLOR_FAIL         = Color("ff5555")
const COLOR_WARN         = Color("ffaa00")
const COLOR_TEXT_DEFAULT = Color("f0e6d2")

func _ready() -> void:
	_build_skald_overlay()
	_setup_connections()
	visible = false


func _build_skald_overlay() -> void:
	# Full-screen overlay that sits on top of the ledger content.
	_skald_overlay = Control.new()
	_skald_overlay.layout_mode = 1
	_skald_overlay.anchors_preset = 15
	_skald_overlay.anchor_right = 1.0
	_skald_overlay.anchor_bottom = 1.0
	_skald_overlay.name = "SkaldReportOverlay"

	var bg := ColorRect.new()
	bg.layout_mode = 1
	bg.anchors_preset = 15
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.08, 0.06, 0.04, 0.95)
	_skald_overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.layout_mode = 1
	margin.anchors_preset = 15
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	_skald_overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "The Skald Remembers"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_skald_label = RichTextLabel.new()
	_skald_label.bbcode_enabled = true
	_skald_label.fit_content = true
	_skald_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_skald_label)

	vbox.add_child(HSeparator.new())

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.pressed.connect(_on_skald_continue_pressed)
	vbox.add_child(_continue_btn)

	add_child(_skald_overlay)
	_skald_overlay.hide()


func _setup_connections() -> void:
	if sign_button and not sign_button.pressed.is_connected(_on_sign_pressed):
		sign_button.pressed.connect(_on_sign_pressed)

	if EventBus.has_signal("season_changed"):
		EventBus.season_changed.connect(_on_season_changed)

	if EventBus.has_signal("advance_season_requested"):
		EventBus.advance_season_requested.connect(_on_advance_requested)


func _on_season_changed(new_season_name: String, context_data: Dictionary) -> void:
	if new_season_name == "Autumn":
		await get_tree().process_frame
		_start_ritual(context_data)


func _on_advance_requested() -> void:
	if visible:
		_close_ledger()


# ---- Phase 1: Skald Report ----

func _start_ritual(context_data: Dictionary) -> void:
	current_report = AutumnReport.new()
	current_report.init_from_context(context_data)

	var fresh_forecast := EconomyManager.get_winter_forecast()
	var fresh_food_demand :Variant= fresh_forecast.get(GameResources.FOOD, 0)
	if fresh_food_demand != current_report.winter_demand:
		Loggie.msg("AutumnLedger: Correcting Stale Forecast (%d -> %d)" % [current_report.winter_demand, fresh_food_demand]).domain(LogDomains.UI).info()
		current_report.winter_demand = fresh_food_demand

	modulate.a = 1.0
	visible = true
	move_to_front()
	is_animation_finished = false

	# Generate and display Skald Report
	var report_text := SkaldReportGenerator.generate_report(DynastyManager.year_event_log)
	if report_text.is_empty():
		report_text = "The year passed without great deed or great loss. The hall endures."
	_skald_label.text = report_text
	_skald_overlay.show()
	_skald_overlay.move_to_front()


func _on_skald_continue_pressed() -> void:
	_skald_overlay.hide()
	_show_ledger()


# ---- Phase 2: Winter Readiness Ledger ----

func _show_ledger() -> void:
	if sign_button:
		sign_button.text = "Skip Animation"
		sign_button.modulate.a = 1.0
		sign_button.show()
		sign_button.disabled = false

	_populate_header()
	_animate_sequence()


func _populate_header() -> void:
	var settlement := SettlementManager.current_settlement
	var display_name := "Settlement"
	if settlement:
		var raw_name := settlement.resource_path.get_file().get_basename()
		if not raw_name.is_empty():
			display_name = raw_name.replace("_", " ").capitalize()

	var year :int = DynastyManager.get_current_year()
	settlement_name_label.text = "%s — Year %d" % [display_name, year]


func _animate_sequence() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	var labels_to_clear := [
		food_starting_label, food_harvest_label, food_demand_label, food_final_label,
		wood_starting_label, wood_harvest_label, wood_demand_label, wood_final_label,
		outlook_label
	]
	for lbl in labels_to_clear:
		if lbl:
			lbl.text = ""
			lbl.modulate.a = 0

	active_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var food_held := int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held := int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	var harvest   := current_report.harvest_yield
	var food_demand := current_report.winter_demand
	var wood_demand := EconomyManager.get_winter_wood_demand()
	var final_food  := food_held + harvest - food_demand
	var final_wood  := wood_held - wood_demand

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
	if not label:
		return
	label.text = text
	label.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.4)


func _reveal_verdict() -> void:
	is_animation_finished = true
	_hide_sign_button()

	var current_stockpile := SettlementManager.current_settlement.treasury.duplicate()
	current_stockpile[GameResources.FOOD] = current_stockpile.get(GameResources.FOOD, 0) + current_report.harvest_yield
	var survival_verdict := EconomyManager.get_survival_verdict(current_stockpile)

	var outlook_text := "WINTER OUTLOOK: "
	var outlook_color := COLOR_OK

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

	var fade_tween := create_tween()
	fade_tween.tween_property(outlook_label, "modulate:a", 1.0, 0.5)

	# Show Proceed to Winter button
	if sign_button:
		sign_button.text = "Proceed to Winter"
		sign_button.modulate.a = 1.0
		sign_button.show()
		sign_button.disabled = false
		if not sign_button.pressed.is_connected(_on_proceed_to_winter):
			sign_button.pressed.disconnect(_on_sign_pressed)
			sign_button.pressed.connect(_on_proceed_to_winter)

	EventBus.autumn_resolved.emit()
	Loggie.msg("Autumn: Verdict revealed.").domain(LogDomains.UI).info()


func _on_sign_pressed() -> void:
	if not is_animation_finished:
		_skip_animation()


func _on_proceed_to_winter() -> void:
	# If a debt offer was generated this Autumn, show it before advancing.
	if DynastyManager.active_debt != null:
		var packed = load(DEBT_OFFER_SCENE)
		if packed:
			var screen :Node= packed.instantiate()
			add_child(screen)
			screen.debt_resolved.connect(_on_debt_resolved)
			return
	_close_ledger()
	EventBus.advance_season_requested.emit()


func _on_debt_resolved() -> void:
	_close_ledger()
	EventBus.advance_season_requested.emit()


func _skip_animation() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	var food_held := int(current_report.treasury_snapshot.get(GameResources.FOOD, 0))
	var wood_held := int(current_report.treasury_snapshot.get(GameResources.WOOD, 0))
	var harvest   := current_report.harvest_yield
	var food_demand := current_report.winter_demand
	var wood_demand := EconomyManager.get_winter_wood_demand()
	var final_food  := food_held + harvest - food_demand
	var final_wood  := wood_held - wood_demand

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
	if not sign_button:
		return
	var btween := create_tween()
	btween.tween_property(sign_button, "modulate:a", 0.0, 0.4)
	btween.tween_callback(sign_button.hide)


func _close_ledger() -> void:
	_skald_overlay.hide()
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_out.tween_callback(func(): visible = false)
	Loggie.msg("Autumn: Closing UI.").domain(LogDomains.UI).debug()
