# res://ui/DynastyUI.gd
class_name DynastyUI
extends PanelContainer

# References
@onready var ancestors_container: HBoxContainer = $Margin/MainLayout/AncestorsScroll/AncestorsHBox
@onready var current_jarl_name: Label = $Margin/MainLayout/CurrentJarlPanel/Stats/NameLabel
@onready var current_jarl_stats: Label = $Margin/MainLayout/CurrentJarlPanel/Stats/StatsLabel
@onready var heirs_container: HBoxContainer = $Margin/MainLayout/HeirsScroll/HeirsHBox
@onready var close_button: Button = $Margin/MainLayout/CloseButton
@onready var context_menu: PopupMenu = $ContextMenu

# Resources
const HEIR_CARD_SCENE = preload("res://ui/components/HeirCard.tscn")
const PLACEHOLDER_ICON = preload("res://textures/placeholders/unit_placeholder.png")

var selected_heir: JarlHeirData

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	DynastyManager.jarl_stats_updated.connect(_on_jarl_stats_updated)
	
	# --- FIX: Use Signal instead of overriding show() ---
	visibility_changed.connect(_on_visibility_changed)
	# ---------------------------------------------------
	
	# Setup Context Menu
	context_menu.add_item("Designate Heir (Cost: 1 Authority)", 0)
	context_menu.add_item("Fund Expedition (Cost: 500 Gold)", 1)
	context_menu.add_item("Arrange Marriage (Cost: 1 Heir)", 2)
	context_menu.add_item("Assign as Captain", 3)
	context_menu.id_pressed.connect(_on_context_menu_item_pressed)
	
	if DynastyManager.current_jarl:
		_on_jarl_stats_updated(DynastyManager.get_current_jarl())
	
	hide()

# --- NEW: Handler for visibility changes ---
func _on_visibility_changed() -> void:
	if visible and DynastyManager.current_jarl:
		_on_jarl_stats_updated(DynastyManager.get_current_jarl())
		Loggie.msg("Dynasty UI: Auto-refreshed data on visible.").domain("UI").info()
# -------------------------------------------

func _on_jarl_stats_updated(jarl: JarlData) -> void:
	if not jarl: return
	
	# 1. Update Current Jarl
	current_jarl_name.text = jarl.display_name
	current_jarl_stats.text = "Age: %d | Authority: %d/%d | Renown: %d" % [jarl.age, jarl.current_authority, jarl.max_authority, jarl.renown]

	# 2. Update Ancestors
	_populate_ancestors(jarl.ancestors)

	# 3. Update Heirs
	_populate_heirs(jarl.heirs)

func _populate_ancestors(ancestors_data: Array) -> void:
	for child in ancestors_container.get_children():
		child.queue_free()
		
	for data in ancestors_data:
		var texture = TextureRect.new()
		texture.custom_minimum_size = Vector2(64, 64)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Enable Mouse Interaction for Tooltips
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

func _populate_heirs(heirs_data: Array[JarlHeirData]) -> void:
	for child in heirs_container.get_children():
		child.queue_free()
		
	for heir in heirs_data:
		var card = HEIR_CARD_SCENE.instantiate()
		heirs_container.add_child(card)
		card.setup(heir)
		card.card_clicked.connect(_on_heir_card_clicked)

func _on_heir_card_clicked(heir: JarlHeirData, mouse_pos: Vector2) -> void:
	selected_heir = heir
	
	# Disable context items based on state
	context_menu.set_item_disabled(0, false) # Designate
	context_menu.set_item_disabled(1, false) # Expedition
	context_menu.set_item_disabled(2, false) # Marriage
	
	if heir.status != JarlHeirData.HeirStatus.Available:
		context_menu.set_item_disabled(1, true) # Cannot send on expedition
		context_menu.set_item_disabled(2, true) # Cannot marry off
	
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
	hide()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()


func _open_warband_assignment_dialog() -> void:
	# Simple logic: Assign to the first available warband for now
	# (Ideally, this would open a submenu list of warbands)
	var settlement = SettlementManager.current_settlement
	if not settlement or settlement.warbands.is_empty():
		Loggie.msg("No Warbands available to lead.").domain("UI").warn()
		return
		
	for wb in settlement.warbands:
		if wb.assigned_heir_name == "":
			wb.assigned_heir_name = selected_heir.display_name
			Loggie.msg("Heir %s assigned to lead %s" % [selected_heir.display_name, wb.custom_name]).domain("UI").info()
			# Add history log
			wb.add_history("Year %d: Led by %s" % [DynastyManager.current_jarl.age, selected_heir.display_name])
			return
			
	Loggie.msg("All Warbands already have captains!").domain("UI").warn()
