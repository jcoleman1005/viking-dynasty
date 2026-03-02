extends PanelContainer
class_name DynastyUI

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var tab_container: TabContainer = $Margin/VBox/TabContainer
@onready var context_menu: PopupMenu = $ContextMenu

# The Jarl Tab
@onready var portrait_rect: TextureRect = $"Margin/VBox/TabContainer/The Jarl/HeroBlock/Portrait"
@onready var name_label: Label = $"Margin/VBox/TabContainer/The Jarl/HeroBlock/HeroInfo/NameLabel"
@onready var epithet_label: Label = $"Margin/VBox/TabContainer/The Jarl/HeroBlock/HeroInfo/EpithetLabel"
@onready var age_reign_label: Label = $"Margin/VBox/TabContainer/The Jarl/HeroBlock/HeroInfo/AgeReignLabel"
@onready var renown_label: Label = $"Margin/VBox/TabContainer/The Jarl/HeroBlock/HeroInfo/RenownLabel"
@onready var might_pillar: RichTextLabel = $"Margin/VBox/TabContainer/The Jarl/PillarsBlock/MightPillar"
@onready var prosperity_pillar: RichTextLabel = $"Margin/VBox/TabContainer/The Jarl/PillarsBlock/ProsperityPillar"
@onready var authority_pillar: RichTextLabel = $"Margin/VBox/TabContainer/The Jarl/PillarsBlock/AuthorityPillar"
@onready var authority_pips: HBoxContainer = $"Margin/VBox/TabContainer/The Jarl/AuthorityBlock/PipsHBox"
@onready var heirs_container: HBoxContainer = $"Margin/VBox/TabContainer/The Jarl/HeirsScroll/HeirsHBox"

# Lineage Tab
@onready var ancestors_container: HBoxContainer = $"Margin/VBox/TabContainer/Lineage/AncestorsScroll/AncestorsHBox"
@onready var father_epithet_label: Label = $"Margin/VBox/TabContainer/Lineage/FoundingBlock/FatherEpithet"
@onready var founding_sentence_label: Label = $"Margin/VBox/TabContainer/Lineage/FoundingBlock/FoundingSentence"
@onready var founding_tags: HBoxContainer = $"Margin/VBox/TabContainer/Lineage/FoundingBlock/Tags"
@onready var echo_text: Label = $"Margin/VBox/TabContainer/Lineage/EchoCard/Margin/EchoText"

signal close_requested

const HEIR_CARD_SCENE = preload("res://ui/components/HeirCard.tscn")
const PLACEHOLDER_ICON = preload("res://textures/placeholders/unit_placeholder.png")

var selected_heir: JarlHeirData

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	DynastyManager.jarl_stats_updated.connect(_on_jarl_stats_updated)
	
	visibility_changed.connect(_on_visibility_changed)
	
	# Setup Context Menu
	context_menu.add_item("Designate Heir (Cost: 1 Authority)", 0)
	context_menu.add_item("Fund Expedition (Cost: 500 Gold)", 1)
	context_menu.add_item("Arrange Marriage (Cost: 1 Heir)", 2)
	context_menu.add_item("Assign as Captain", 3)
	context_menu.id_pressed.connect(_on_context_menu_item_pressed)
	
	if DynastyManager.current_jarl:
		_on_jarl_stats_updated(DynastyManager.get_current_jarl())
	
	hide()

func _on_visibility_changed() -> void:
	if visible and DynastyManager.current_jarl:
		_on_jarl_stats_updated(DynastyManager.get_current_jarl())
		Loggie.msg("Dynasty UI: Auto-refreshed data on visible.").domain("UI").info()
	
	# Lock/Unlock Camera Input
	EventBus.camera_input_lock_requested.emit(visible)

func _on_jarl_stats_updated(jarl: JarlData) -> void:
	if not jarl: return
	
	_update_jarl_hero(jarl)
	_update_pillars(jarl)
	_update_authority(jarl)
	_update_heirs(jarl)
	_update_lineage(jarl)

func _update_jarl_hero(jarl: JarlData) -> void:
	name_label.text = jarl.display_name
	
	if jarl.living_epithet != "":
		epithet_label.text = jarl.living_epithet
		epithet_label.show()
	else:
		epithet_label.hide()
		
	age_reign_label.text = "Age: %d" % jarl.age
	renown_label.text = "Renown: %d (Tier %d)" % [jarl.renown, jarl.renown_tier]
	
	if jarl.portrait:
		portrait_rect.texture = jarl.portrait
	else:
		portrait_rect.texture = PLACEHOLDER_ICON

func _update_pillars(jarl: JarlData) -> void:
	var prowess = jarl.get_effective_skill("prowess")
	var command = jarl.get_effective_skill("command")
	var stewardship = jarl.get_effective_skill("stewardship")
	var learning = jarl.get_effective_skill("learning")
	var diplomacy = jarl.get_effective_skill("diplomacy")
	var charisma = jarl.get_effective_skill("charisma")
	
	var war_base = prowess + command
	var war_penalty = int((diplomacy + charisma) * 0.5)
	might_pillar.text = "[color=#c47a50]⚔️ MIGHT: %d[/color]\nBase: %d | Shadow: -%d from Word\n(Prowess: %d | Command: %d)" % [jarl.might_score, war_base, war_penalty, prowess, command]
	
	var wealth_base = stewardship + learning
	var wealth_penalty = int((prowess + command) * 0.5)
	prosperity_pillar.text = "[color=#7ab648]💰 PROSPERITY: %d[/color]\nBase: %d | Shadow: -%d from War\n(Steward: %d | Learning: %d)" % [jarl.prosperity_score, wealth_base, wealth_penalty, stewardship, learning]
	
	var word_base = diplomacy + charisma
	var word_penalty = int((stewardship + learning) * 0.5)
	authority_pillar.text = "[color=#88aadf]👑 AUTHORITY: %d[/color]\nBase: %d | Shadow: -%d from Wealth\n(Diplomacy: %d | Charisma: %d)" % [jarl.authority_score, word_base, word_penalty, diplomacy, charisma]

func _update_authority(jarl: JarlData) -> void:
	for child in authority_pips.get_children():
		child.queue_free()
		
	for i in range(jarl.max_authority):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 16)
		if i < jarl.current_authority:
			pip.color = Color(0.831, 0.659, 0.263, 1) # Gold (filled)
		else:
			pip.color = Color(0.2, 0.2, 0.2, 1) # Dark gray (empty)
		authority_pips.add_child(pip)

func _update_heirs(jarl: JarlData) -> void:
	for child in heirs_container.get_children():
		child.queue_free()
		
	for heir in jarl.heirs:
		var card = HEIR_CARD_SCENE.instantiate()
		heirs_container.add_child(card)
		card.setup(heir)
		card.card_clicked.connect(_on_heir_card_clicked)

func _update_lineage(jarl: JarlData) -> void:
	for child in ancestors_container.get_children():
		child.queue_free()
		
	for data in jarl.ancestors:
		var texture = TextureRect.new()
		texture.custom_minimum_size = Vector2(64, 64)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.mouse_filter = Control.MOUSE_FILTER_STOP 
		
		if data.has("portrait") and data["portrait"] != null:
			texture.texture = data["portrait"]
		else:
			texture.texture = PLACEHOLDER_ICON
			
		texture.tooltip_text = "%s\nFinal Renown: %d\nDied: %s" % [
			data.get("name", "Ancestor"), 
			data.get("final_renown", 0),
			data.get("death_reason", "Unknown")
		]
		
		texture.modulate = Color(0.5, 0.5, 0.5, 0.8) 
		ancestors_container.add_child(texture)

	if jarl.founding_epithet != "":
		father_epithet_label.text = jarl.founding_epithet
		father_epithet_label.show()
	else:
		father_epithet_label.hide()
		
	founding_sentence_label.text = "Archetype: %s | First Act: %s" % [jarl.founding_archetype, jarl.first_act]
	
	if jarl.exile_reason != "":
		echo_text.text = "Exile Reason: %s\nThe legacy of this decision remains." % jarl.exile_reason
	else:
		echo_text.text = "No recorded exile."

func _on_heir_card_clicked(heir: JarlHeirData, mouse_pos: Vector2) -> void:
	selected_heir = heir
	
	context_menu.set_item_disabled(0, false) 
	context_menu.set_item_disabled(1, false) 
	context_menu.set_item_disabled(2, false) 
	
	if heir.status != JarlHeirData.HeirStatus.Available:
		context_menu.set_item_disabled(1, true) 
		context_menu.set_item_disabled(2, true) 
	
	if heir.is_designated_heir:
		context_menu.set_item_text(0, "Designated Heir (Active)")
		context_menu.set_item_disabled(0, true)
	else:
		context_menu.set_item_text(0, "Designate Heir (Cost: 1 Authority)")
	
	context_menu.position = Vector2i(mouse_pos)
	context_menu.popup()

func _on_context_menu_item_pressed(id: int) -> void:
	if not selected_heir: return
	
	match id:
		0: # Designate Heir
			DynastyManager.designate_heir(selected_heir)
		1: # Fund Expedition
			var cost = {"gold": 500}
			if SettlementManager.attempt_purchase(cost):
				DynastyManager.start_heir_expedition(selected_heir)
			else:
				Loggie.msg("Not enough gold for expedition.").domain("UI").info()
		2: # Arrange Marriage
			if DynastyManager.get_current_jarl():
				selected_heir.status = JarlHeirData.HeirStatus.MarriedOff
				DynastyManager.award_renown(150) 
				Loggie.msg("Heir married off for Renown.").domain("UI").info()
		3: # Assign Captain
			_open_warband_assignment_dialog()

func _on_close_button_pressed() -> void:
	if EventBus:
		EventBus.sidebar_close_requested.emit()
	else:
		hide()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()

func _open_warband_assignment_dialog() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement or settlement.warbands.is_empty():
		Loggie.msg("No Warbands available to lead.").domain("UI").warn()
		return
		
	for wb in settlement.warbands:
		if wb.assigned_heir_name == "":
			wb.assigned_heir_name = selected_heir.display_name
			Loggie.msg("Heir %s assigned to lead %s" % [selected_heir.display_name, wb.custom_name]).domain("UI").info()
			wb.add_history("Year %d: Led by %s" % [DynastyManager.current_jarl.age, selected_heir.display_name])
			return
			
	Loggie.msg("All Warbands already have captains!").domain("UI").warn()
