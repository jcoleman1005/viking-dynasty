# res://ui/components/HeirCard.gd
extends PanelContainer
class_name HeirCard

signal card_clicked(heir_data: JarlHeirData, global_pos: Vector2)

# Ensure these paths match your Scene Tree names exactly
@onready var portrait_container: Control = $VBox/PortraitContainer
@onready var portrait_rect: TextureRect = $VBox/PortraitContainer/Portrait
@onready var status_icon: TextureRect = $VBox/PortraitContainer/StatusIcon
@onready var heir_crown_icon: TextureRect = $VBox/PortraitContainer/HeirCrown
@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsLabel

const PORTRAIT_GEN_SCENE = preload("res://scenes/ui/PortraitGenerator.tscn")
var heir_data: JarlHeirData

func setup(data: JarlHeirData) -> void:
	heir_data = data
	
	# 1. Basic Info
	name_label.text = "%s (%d)" % [data.display_name, data.age]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 2. Portrait Logic (Dynamic vs Static)
	_setup_portrait(data)
	
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

func _setup_portrait(data: JarlHeirData) -> void:
	# Clear existing generators if recycling list items
	for child in portrait_container.get_children():
		if child is PortraitGenerator:
			child.queue_free()
	
	# A. Dynamic Portrait (Preferred)
	if not data.portrait_config.is_empty():
		portrait_rect.texture = null # Clear static image
		
		var generator = PORTRAIT_GEN_SCENE.instantiate()
		portrait_container.add_child(generator)
		# Push behind overlays (Crown/Status) but in front of BG
		generator.z_index = 0 
		
		# Configure
		if generator.has_method("build_portrait"):
			generator.build_portrait(data.portrait_config)
			
	# B. Static Fallback
	elif data.portrait:
		portrait_rect.texture = data.portrait
	else:
		portrait_rect.modulate = Color.GRAY 

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
