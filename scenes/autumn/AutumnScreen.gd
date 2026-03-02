# res://scenes/autumn/AutumnScreen.gd
# Autumn resolution screen — three-beat flow:
#   1. Animated ledger (Food · Wood · Gold · Renown · Verdict)
#   2. Oath resolution panel (populated immediately, visible alongside ledger)
#   3. Skald report fades in after ledger completes
#   4. "Enter Winter" unlocks after skald is shown
#
# Self-managed: subscribes to EventBus.season_changed, shows on "Autumn".
# Handles DebtOfferScreen gate before emitting advance_season_requested.
extends Control

const DEBT_OFFER_SCENE := "res://scenes/autumn/DebtOfferScreen.tscn"

# Ledger row colours
const COLOR_POS  := Color("7ab648")   # PROSPERITY
const COLOR_NEG  := Color("c84040")   # DANGER
const COLOR_ZERO := Color("9a9080")   # TEXT_SECONDARY
const COLOR_GOLD := Color("d4a843")   # RENOWN

# Outcome badge colours
const COLOR_KEPT    := Color("7ab648")
const COLOR_PARTIAL := Color("e8a840")
const COLOR_BROKEN  := Color("c84040")
const COLOR_NONE    := Color("5a5548")

@onready var ledger_vbox:       VBoxContainer = $MainLayout/TopContent/LeftPanel/LeftInner/LedgerVBox
@onready var skip_btn:          Button        = $MainLayout/TopContent/LeftPanel/LeftInner/SkipBtn
@onready var oath_name_label:   Label         = $MainLayout/TopContent/RightPanel/RightInner/RightVBox/OathNameLabel
@onready var outcome_badge:     Label         = $MainLayout/TopContent/RightPanel/RightInner/RightVBox/OutcomeBadge
@onready var oath_notes_label:  Label         = $MainLayout/TopContent/RightPanel/RightInner/RightVBox/OathNotesLabel
@onready var renown_delta_label: Label        = $MainLayout/TopContent/RightPanel/RightInner/RightVBox/RenownDeltaLabel
@onready var household_list:    VBoxContainer = $MainLayout/TopContent/RightPanel/RightInner/RightVBox/HouseholdList
@onready var skald_section:     PanelContainer = $MainLayout/SkaldSection
@onready var skald_text:        RichTextLabel = $MainLayout/SkaldSection/SkaldMargin/SkaldVBox/SkaldText
@onready var enter_winter_btn:  Button        = $MainLayout/Footer/EnterWinterBtn

var _context: Dictionary = {}
var _anim_tween: Tween = null
var _ledger_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.season_changed.connect(_on_season_changed)
	skip_btn.pressed.connect(_on_skip_pressed)
	enter_winter_btn.pressed.connect(_on_enter_winter_pressed)
	enter_winter_btn.disabled = true


func _on_season_changed(season_name: String, context: Dictionary) -> void:
	if season_name == "Autumn":
		_context = context
		await get_tree().process_frame
		_open()


func _open() -> void:
	_ledger_done = false
	enter_winter_btn.disabled = true
	skald_section.visible = false
	skald_section.modulate.a = 0.0

	_populate_oath_panel()
	_animate_ledger()

	visible = true
	move_to_front()
	Loggie.msg("AutumnScreen: Opened for Year %d." % DynastyManager.current_year).domain(LogDomains.UI).info()


# ---------------------------------------------------------------------------
# Oath panel (right column)
# ---------------------------------------------------------------------------

func _populate_oath_panel() -> void:
	var oath_result: Dictionary = _context.get("oath_result", {})
	var outcome: String = oath_result.get("outcome", "none")
	var oath_id: String = oath_result.get("oath_id", "")

	oath_name_label.text = oath_id.replace("_", " ").capitalize() if oath_id != "" else "No oath sworn"

	match outcome:
		"kept":
			outcome_badge.text = "KEPT"
			outcome_badge.add_theme_color_override("font_color", COLOR_KEPT)
		"partial":
			outcome_badge.text = "PARTIAL"
			outcome_badge.add_theme_color_override("font_color", COLOR_PARTIAL)
		"broken":
			outcome_badge.text = "BROKEN"
			outcome_badge.add_theme_color_override("font_color", COLOR_BROKEN)
		_:
			outcome_badge.text = "NONE"
			outcome_badge.add_theme_color_override("font_color", COLOR_NONE)

	oath_notes_label.text = oath_result.get("notes", "—")

	var delta: int = oath_result.get("renown_delta", 0)
	if delta > 0:
		renown_delta_label.text = "Renown  +%d" % delta
		renown_delta_label.add_theme_color_override("font_color", COLOR_KEPT)
	elif delta < 0:
		renown_delta_label.text = "Renown  %d" % delta
		renown_delta_label.add_theme_color_override("font_color", COLOR_BROKEN)
	else:
		renown_delta_label.text = "Renown  ±0"
		renown_delta_label.add_theme_color_override("font_color", COLOR_ZERO)

	# Household loyalty summary
	for child in household_list.get_children():
		child.queue_free()

	var settlement := SettlementManager.current_settlement
	if settlement:
		for h in settlement.households:
			var row := Label.new()
			row.text = "%s — Loyalty %d" % [h.household_name if h.household_name else "Household", h.loyalty]
			row.add_theme_font_size_override("font_size", 12)
			household_list.add_child(row)


# ---------------------------------------------------------------------------
# Animated ledger (left column)
# ---------------------------------------------------------------------------

func _animate_ledger() -> void:
	for child in ledger_vbox.get_children():
		child.queue_free()

	var rows := _build_ledger_data()

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var delay := 0.0
	for row_data in rows:
		var row := _make_row(row_data)
		row.modulate.a = 0.0
		ledger_vbox.add_child(row)
		_anim_tween.tween_callback(func(): _fade_in_node(row)).set_delay(delay)
		delay += 0.4

	_anim_tween.tween_callback(_on_ledger_complete).set_delay(delay)


func _build_ledger_data() -> Array:
	var payout: Dictionary   = _context.get("payout", {})
	var treasury: Dictionary = _context.get("treasury", {})
	var forecast: Dictionary = _context.get("forecast", {})

	var food_income  := int(payout.get("food", 0))
	var food_expense := int(forecast.get("food", 0))
	var food_net     := int(treasury.get("food", 0)) - food_expense

	var wood_income  := int(payout.get("wood", 0))
	var wood_expense := EconomyManager.get_winter_wood_demand() if EconomyManager.has_method("get_winter_wood_demand") else 0
	var wood_net     := int(treasury.get("wood", 0)) - wood_expense

	var gold_income  := int(payout.get("gold", 0))
	var gold_net     := int(treasury.get("gold", 0))

	var oath_result: Dictionary = _context.get("oath_result", {})
	var renown_delta := int(oath_result.get("renown_delta", 0))

	return [
		{ "label": "Food",   "income": food_income,  "expense": food_expense, "net": food_net   },
		{ "label": "Wood",   "income": wood_income,  "expense": wood_expense, "net": wood_net   },
		{ "label": "Gold",   "income": gold_income,  "expense": 0,            "net": gold_net   },
		{ "label": "Renown", "income": renown_delta, "expense": 0,            "net": renown_delta },
	]


func _make_row(data: Dictionary) -> Control:
	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = data["label"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var income_lbl := Label.new()
	var inc: int = data["income"]
	income_lbl.text = "+%d" % inc if inc >= 0 else "%d" % inc
	income_lbl.custom_minimum_size = Vector2(70, 0)
	income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	income_lbl.add_theme_color_override("font_color", COLOR_POS if inc > 0 else COLOR_ZERO)
	income_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(income_lbl)

	var expense_lbl := Label.new()
	var exp: int = data["expense"]
	expense_lbl.text = "-%d" % exp if exp > 0 else "—"
	expense_lbl.custom_minimum_size = Vector2(70, 0)
	expense_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	expense_lbl.add_theme_color_override("font_color", COLOR_NEG if exp > 0 else COLOR_ZERO)
	expense_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(expense_lbl)

	var net_lbl := Label.new()
	var net: int = data["net"]
	net_lbl.text = "+%d" % net if net > 0 else "%d" % net
	net_lbl.custom_minimum_size = Vector2(70, 0)
	net_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	net_lbl.add_theme_color_override("font_color", COLOR_POS if net > 0 else (COLOR_NEG if net < 0 else COLOR_ZERO))
	net_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(net_lbl)

	return row


func _fade_in_node(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, 0.35)


func _on_skip_pressed() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	for child in ledger_vbox.get_children():
		child.modulate.a = 1.0
	_on_ledger_complete()


func _on_ledger_complete() -> void:
	if _ledger_done:
		return
	_ledger_done = true
	skip_btn.visible = false
	_reveal_skald()


# ---------------------------------------------------------------------------
# Skald report
# ---------------------------------------------------------------------------

func _reveal_skald() -> void:
	skald_section.visible = true
	var report := SkaldReportGenerator.generate_report(_context)
	if report.is_empty():
		report = "[i]The year passed without great deed or great loss. The hall endures.[/i]"
	skald_text.bbcode_enabled = true
	skald_text.text = report

	var t := create_tween().set_ease(Tween.EASE_OUT)
	t.tween_property(skald_section, "modulate:a", 1.0, 0.6)
	t.tween_callback(func(): enter_winter_btn.disabled = false)


# ---------------------------------------------------------------------------
# Footer — Enter Winter
# ---------------------------------------------------------------------------

func _on_enter_winter_pressed() -> void:
	if DynastyManager.active_debt != null:
		var packed = load(DEBT_OFFER_SCENE) as PackedScene
		if packed:
			var screen: Node = packed.instantiate()
			add_child(screen)
			if screen.has_signal("debt_resolved"):
				screen.debt_resolved.connect(_on_debt_resolved)
			return
	_close()


func _on_debt_resolved() -> void:
	_close()


func _close() -> void:
	var t := create_tween().set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(func():
		modulate.a = 1.0
		visible = false
		EventBus.advance_season_requested.emit()
	)
	Loggie.msg("AutumnScreen: Closing.").domain(LogDomains.UI).info()
