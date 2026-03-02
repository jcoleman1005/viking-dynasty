# res://scenes/founding/FoundingLocationScreen.gd
# Screen 4 of 4 (final): Choose your founding location.
# Four cards — each shows its primary bonus. Situational negative is NOT shown.
extends CanvasLayer

const LOCATION_OPTIONS: Array[Dictionary] = [
	{
		"id":    "forest",
		"label": "The Deep Forest",
		"bonus": "+10% lumber yield. Construction is faster here.",
		"desc":  "Thick timber as far as the eye can see. Your axemen will be busy.",
	},
	{
		"id":    "sea",
		"label": "The Coastal Inlet",
		"bonus": "Shorter warband travel times. Fisheries provide passive food.",
		"desc":  "Salt air and clear sight-lines to the horizon. Your longships will be home here.",
	},
	{
		"id":    "arable",
		"label": "The Fertile Plain",
		"bonus": "+25% farming output.",
		"desc":  "Deep soil, wide skies. Your people will not go hungry. Raiders will know it.",
	},
	{
		"id":    "crags",
		"label": "The High Crags",
		"bonus": "Renown every two years from the difficulty of your chosen ground.",
		"desc":  "No one settles here without reason. That reason will follow you.",
	},
]

var _selected_id: String = ""
var _card_buttons: Array[Button] = []
var _confirm_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_ui()


func _populate_ui() -> void:
	var title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
	if title_label:
		title_label.text = "Where Did You Settle?"

	var card_container: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/CardContainer")
	if not card_container:
		return

	for i in LOCATION_OPTIONS.size():
		var option := LOCATION_OPTIONS[i]

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		var label := Label.new()
		label.text = option["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)

		var bonus_label := Label.new()
		bonus_label.text = option["bonus"]
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(bonus_label)

		var desc := RichTextLabel.new()
		desc.bbcode_enabled = true
		desc.fit_content = true
		desc.text = option["desc"]
		vbox.add_child(desc)

		var btn := Button.new()
		btn.text = "Choose"
		var idx := i
		btn.pressed.connect(func(): _on_card_selected(idx))
		_card_buttons.append(btn)
		vbox.add_child(btn)

		card_container.add_child(panel)

	_confirm_button = get_node_or_null("MarginContainer/VBoxContainer/ConfirmButton")
	if _confirm_button:
		_confirm_button.disabled = true
		_confirm_button.pressed.connect(_on_confirm_pressed)


func _on_card_selected(index: int) -> void:
	_selected_id = LOCATION_OPTIONS[index]["id"]
	FoundingSequenceManager.current_founding_data.founding_location = _selected_id

	for i in _card_buttons.size():
		_card_buttons[i].disabled = (i == index)

	if _confirm_button:
		_confirm_button.disabled = false


func _on_confirm_pressed() -> void:
	if _selected_id.is_empty():
		return
	FoundingSequenceManager.advance_sequence()
