#res://ui/components/HeirCard.gd
extends PanelContainer
class_name HeirCard

signal card_clicked(heir_data: JarlHeirData, global_pos: Vector2)

# Ensure these paths match your Scene Tree names exactly
@onready var portrait_rect: TextureRect = $VBox/PortraitContainer/Portrait
@onready var status_icon: TextureRect = $VBox/PortraitContainer/StatusIcon
@onready var heir_crown_icon: TextureRect = $VBox/PortraitContainer/HeirCrown
@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsLabel

var heir_data: JarlHeirData

func setup(data: JarlHeirData) -> void:
	heir_data = data
	
	# 1. Basic Info
	name_label.text = "%s (%d)" % [data.display_name, data.age]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 2. Portrait
	if data.portrait:
		portrait_rect.texture = data.portrait
	else:
		portrait_rect.modulate = Color.GRAY 
	
	# 3. Crown Overlay (Active Heir)
	heir_crown_icon.visible = data.is_designated_heir
	
	# 4. Status Overlay
	_update_status_visuals()
	
	# 5. Stats
	var trait_text = "None"
	if data.genetic_trait:
		trait_text = data.genetic_trait.display_name
		
	stats_label.text = "Prowess: %d\nSteward: %d\nTrait: %s" % [data.prowess, data.stewardship, trait_text]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _update_status_visuals() -> void:
	# Reset visuals
	modulate = Color.WHITE
	status_icon.texture = null
	status_icon.visible = false
	
	match heir_data.status:
		JarlHeirData.HeirStatus.OnExpedition:
			modulate = Color(0.7, 0.7, 0.7) # Dim the card
			status_icon.visible = true
			
		JarlHeirData.HeirStatus.MarriedOff:
			modulate = Color(0.5, 0.5, 0.5) # Darker
			status_icon.visible = true
			
		JarlHeirData.HeirStatus.Maimed:
			status_icon.visible = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(heir_data, get_global_mouse_position())
