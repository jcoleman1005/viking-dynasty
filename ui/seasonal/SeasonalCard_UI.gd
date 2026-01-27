class_name SeasonalCard_UI
extends Control

## Visual representation of a SeasonalCardResource.
## Handles clicks and hover states.

# --- Signals ---
signal card_clicked(card_data: SeasonalCardResource)

# --- Nodes ---
# Ensure these exist in your scene tree with Unique Names (%)
# Suggested Tree: PanelContainer -> VBox -> (Icon, Title, Desc, CostContainer, SelectButton)
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var cost_container: HBoxContainer = %CostContainer
@onready var ap_cost_label: Label = %APCostLabel # Inside CostContainer
@onready var gold_cost_label: Label = %GoldCostLabel
@onready var select_button: Button = %SelectButton

# --- Data ---
var _card_data: SeasonalCardResource

func _ready() -> void:
	select_button.pressed.connect(_on_button_pressed)

## Configures the card visual based on the resource.
func setup(card: SeasonalCardResource, can_afford: bool = true) -> void:
	_card_data = card
	
	title_label.text = card.title
	description_label.text = card.description
	icon_rect.texture = card.icon
	
	# Handle Winter Costs (Hide if 0)
	if card.cost_ap > 0 or card.cost_gold > 0:
		cost_container.show()
		ap_cost_label.text = "AP: %d" % card.cost_ap
		gold_cost_label.text = "Gold: %d"# Add gold label handling here if needed
	else:
		cost_container.hide()
	
	# Handle Affordability
	select_button.disabled = not can_afford
	if not can_afford:
		modulate = Color(0.7, 0.7, 0.7, 0.8) # Dim out

func _on_button_pressed() -> void:
	if _card_data:
		card_clicked.emit(_card_data)
