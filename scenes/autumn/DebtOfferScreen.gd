# res://scenes/autumn/DebtOfferScreen.gd
# Modal overlay shown in Autumn when food < debt trigger threshold.
# Displays the creditor's offer and lets the player Accept or Refuse.
# Emits debt_resolved when the player makes a choice.
extends CanvasLayer

signal debt_resolved

@onready var creditor_label:    Label        = $Panel/MarginContainer/VBoxContainer/CreditorLabel
@onready var terms_label:       Label        = $Panel/MarginContainer/VBoxContainer/TermsLabel
@onready var explanation_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ExplanationLabel
@onready var accept_btn:        Button       = $Panel/MarginContainer/VBoxContainer/ButtonRow/AcceptButton
@onready var refuse_btn:        Button       = $Panel/MarginContainer/VBoxContainer/ButtonRow/RefuseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var offer := DynastyManager.active_debt
	if not offer:
		queue_free()
		return

	creditor_label.text = offer.creditor_name
	terms_label.text = "%d grain now — repay %d grain within %d years" % [
		offer.grain_amount, offer.repayment_amount, offer.repayment_deadline_years,
	]
	explanation_label.text = offer.offer_explanation

	if offer.inherited:
		var inh_label := Label.new()
		inh_label.text = "(Debt inherited from your predecessor.)"
		inh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		explanation_label.get_parent().add_child_at_index(inh_label, explanation_label.get_index() + 1)

	accept_btn.pressed.connect(_on_accept_pressed)
	refuse_btn.pressed.connect(_on_refuse_pressed)


func _on_accept_pressed() -> void:
	var offer := DynastyManager.active_debt
	if offer:
		EconomyManager.add_resource("food", offer.grain_amount)
		var treasury := SettlementManager.current_settlement.treasury if SettlementManager.current_settlement else {}
		EventBus.treasury_updated.emit(treasury)
		EventManager._log_skald_event("debt_accepted", {
			"creditor": offer.creditor_name,
			"amount":   offer.grain_amount,
		}, 2)
		Loggie.msg("Debt accepted: %d grain from %s." % [
			offer.grain_amount, offer.creditor_name,
		]).domain(LogDomains.DYNASTY).info()
	debt_resolved.emit()
	queue_free()


func _on_refuse_pressed() -> void:
	DynastyManager._process_debt_default()
	debt_resolved.emit()
	queue_free()
