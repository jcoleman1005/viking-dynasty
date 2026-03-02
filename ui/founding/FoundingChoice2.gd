# res://ui/founding/FoundingChoice2.gd
extends Control

const EXILE_OPTIONS := [
	{
		"id": "frankish",
		"title": "FRANKISH PERSECUTION",
		"description": "Your father built something worth taking. When the missionaries came with soldiers behind them, he had days to choose — convert or flee. He chose the old gods and the open sea.",
		"consequence": "Fewer starting resources. One household scarred."
	},
	{
		"id": "rival",
		"title": "RIVAL JARL DRIVE YOU OUT",
		"description": "There was another jarl — stronger then, or better connected. Your father challenged him and the thing was settled badly. The men who stayed loyal came with you.",
		"consequence": "You have a warband but fewer households."
	},
	{
		"id": "opportunity",
		"title": "SEEKING OPPORTUNITY",
		"description": "No catastrophe. No defeat. Your father heard something — rumour of good land, a coastline worth holding, a name worth building. The households who came chose to come.",
		"consequence": "Loyal households. But the winters are harder than rumour suggested."
	}
]

@onready var cards_container := %SituationCards
@onready var commit_btn := %CommitBtn

var selected_id := ""

func _ready() -> void:
	for option in EXILE_OPTIONS:
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
	FoundingSequenceManager.current_founding_data.exile_reason = selected_id
	FoundingSequenceManager.advance_sequence()
