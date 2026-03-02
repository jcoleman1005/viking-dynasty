# res://ui/founding/FoundingChoice3.gd
extends Control

const FIRST_ACT_OPTIONS := [
	{
		"id": "sworn",
		"title": "SWORN TO PROTECT",
		"description": "The households were afraid. You stood in the hall and swore you would keep them fed and safe through the first Winter. Some wept. All of them believed you.",
		"consequence": "One household expects much. If you fail them, they remember."
	},
	{
		"id": "challenged",
		"title": "CHALLENGED THE ADVISOR",
		"description": "Your father's oldest advisor thought he would manage the transition. You disagreed publicly. You won the argument but you read his face as he sat back down.",
		"consequence": "One household's loyalty starts low. Consistent oath-keeping will win them."
	},
	{
		"id": "generous",
		"title": "GAVE AWAY THE STORES",
		"description": "It was your first act as Jarl. Perhaps it was wisdom — loyalty bought cheaply. Perhaps it was foolishness you cannot afford. You fed the poorest from your own reserves.",
		"consequence": "All households begin loyal. The first year will be lean."
	}
]

@onready var cards_container := %SituationCards
@onready var commit_btn := %CommitBtn

var selected_id := ""

func _ready() -> void:
	for option in FIRST_ACT_OPTIONS:
		var card = _create_card(option)
		cards_container.add_child(card)
	
	commit_btn.pressed.connect(_on_commit_pressed)

func _create_card(option: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.theme_type_variation = &"PanelContainerCard"
	panel.custom_minimum_size = Vector2(280, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants.separation = 15
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = option["title"]
	title.theme_type_variation = &"HouseholdNameLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = option["description"]
	desc.theme_type_variation = &"SeasonLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
	var cons = Label.new()
	cons.text = option["consequence"]
	cons.theme_type_variation = &"SectionHeader"
	cons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cons)
	
	var btn = Button.new()
	btn.text = "Select"
	btn.pressed.connect(_on_card_selected.bind(option["id"], panel))
	vbox.add_child(btn)
	
	return panel

func _on_card_selected(id: String, selected_panel: PanelContainer) -> void:
	selected_id = id
	commit_btn.show()
	
	for child in cards_container.get_children():
		child.modulate = Color(1, 1, 1, 0.5)
	selected_panel.modulate = Color(1, 1, 1, 1.0)

func _on_commit_pressed() -> void:
	FoundingSequenceManager.current_founding_data.first_act = selected_id
	FoundingSequenceManager.advance_sequence()
