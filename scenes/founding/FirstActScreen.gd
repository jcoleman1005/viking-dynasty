# res://scenes/founding/FirstActScreen.gd
# Screen 3 of 4: Choose your first act as Jarl.
# Three cards — framed as burdens and problems, not rewards.
extends CanvasLayer

const FIRST_ACT_OPTIONS: Array[Dictionary] = [
	{
		"id":    "oath_of_protection",
		"label": "Oath of Protection",
		"desc":  "You called the households together and swore to protect them. They looked to you with hope. Now the weight of that hope sits in your chest every morning you wake.",
	},
	{
		"id":    "challenged_advisor",
		"label": "Challenged the Advisor",
		"desc":  "Your father's oldest advisor thought he would run things until you found your footing. You challenged him in front of the hall and sent him home. The households are watching to see if you were right.",
	},
	{
		"id":    "generous_gift",
		"label": "Generous Gift",
		"desc":  "You gave away half the winter stores to the poorest household as a gesture of generosity. They love you for it. The grain is still gone.",
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
		title_label.text = "Your First Act"

	var card_container: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/CardContainer")
	if not card_container:
		return

	for i in FIRST_ACT_OPTIONS.size():
		var option := FIRST_ACT_OPTIONS[i]

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
	_selected_id = FIRST_ACT_OPTIONS[index]["id"]
	FoundingSequenceManager.current_founding_data.first_act = _selected_id

	for i in _card_buttons.size():
		_card_buttons[i].disabled = (i == index)

	if _confirm_button:
		_confirm_button.disabled = false


func _on_confirm_pressed() -> void:
	if _selected_id.is_empty():
		return
	FoundingSequenceManager.advance_sequence()
