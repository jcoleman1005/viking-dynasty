extends PanelContainer
class_name HeirCard

signal card_clicked(heir_data: JarlHeirData, global_pos: Vector2)

@onready var portrait_rect: TextureRect = $VBox/PortraitContainer/Portrait
@onready var heir_crown_icon: ColorRect = $VBox/PortraitContainer/HeirCrown
@onready var name_label: Label = $VBox/NameLabel
@onready var age_label: Label = $VBox/AgeLabel
@onready var status_badge: Label = $VBox/StatusBadge
@onready var training_label: Label = $VBox/TrainingLabel

var heir_data: JarlHeirData

func setup(data: JarlHeirData) -> void:
	heir_data = data
	
	name_label.text = data.display_name
	age_label.text = "Age: %d" % data.age
	
	if data.portrait:
		portrait_rect.texture = data.portrait
	else:
		portrait_rect.modulate = Color.GRAY
	
	heir_crown_icon.visible = data.is_designated_heir
	
	_update_status_visuals()
	
	if data.training_history and data.training_history.size() > 0:
		training_label.text = data.training_history.back()
	else:
		training_label.text = "No formal training."

func _update_status_visuals() -> void:
	modulate = Color.WHITE
	status_badge.visible = true
	
	match heir_data.status:
		JarlHeirData.HeirStatus.Available:
			status_badge.text = "Available"
			status_badge.modulate = Color(0.6, 0.8, 0.6)
		JarlHeirData.HeirStatus.OnExpedition:
			status_badge.text = "On Expedition"
			modulate = Color(0.7, 0.7, 0.7)
			status_badge.modulate = Color(0.8, 0.8, 0.6)
		JarlHeirData.HeirStatus.MarriedOff:
			status_badge.text = "Married Off"
			modulate = Color(0.5, 0.5, 0.5)
			status_badge.modulate = Color(0.8, 0.6, 0.8)
		JarlHeirData.HeirStatus.Maimed:
			status_badge.text = "Maimed"
			status_badge.modulate = Color(0.8, 0.4, 0.4)
		_:
			status_badge.text = "Unavailable"
			modulate = Color(0.5, 0.5, 0.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(heir_data, get_global_mouse_position())
