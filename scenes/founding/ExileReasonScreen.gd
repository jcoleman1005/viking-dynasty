# res://scenes/founding/ExileReasonScreen.gd
# Screen 2 of 4: Choose your exile reason.
# Three cards — narrative only, no stat numbers shown.
extends CanvasLayer

const EXILE_OPTIONS: Array[Dictionary] = [
	{
		"id":    "frankish_persecution",
		"label": "Frankish Persecution",
		"desc":  "Your family burned at the hands of Frankish soldiers. You fled east with what few mouths you could carry. You have nothing. You remember everything.",
	},
	{
		"id":    "rival_jarl",
		"label": "A Rival Jarl Drove You Out",
		"desc":  "You were beaten. Not in open battle — he used silver and whispers. Your hall is his hall now. You left with your warband and your rage intact.",
	},
	{
		"id":    "seeking_opportunity",
		"label": "Seeking Opportunity",
		"desc":  "No enemy drove you here. You chose this. The old lands were crowded, the feuds older than your grandfather. Out here, a man can build something that lasts.",
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
		title_label.text = "Why Did You Come Here?"

	var card_container: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/CardContainer")
	if not card_container:
		return

	for i in EXILE_OPTIONS.size():
		var option := EXILE_OPTIONS[i]

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		var label := Label.new()
		label.text = option["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)

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
	_selected_id = EXILE_OPTIONS[index]["id"]
	FoundingSequenceManager.current_founding_data.exile_reason = _selected_id

	for i in _card_buttons.size():
		_card_buttons[i].disabled = (i == index)

	if _confirm_button:
		_confirm_button.disabled = false


func _on_confirm_pressed() -> void:
	if _selected_id.is_empty():
		return
	FoundingSequenceManager.advance_sequence()
