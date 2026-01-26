class_name SeasonalCardResource
extends Resource

## The Data Schema for Spring Advisor and Winter Court cards.
## Drives the SeasonalCard_UI.

@export_group("Display")
@export var title: String = "Card Title"
@export_multiline var description: String = "Effect description..."
@export var icon: Texture2D

@export_group("Costs (Winter)")
## Action Point cost (Winter Court only).
@export var cost_ap: int = 0
## Gold cost (optional for some actions).
@export var cost_gold: int = 0
## Food cost (feasts, etc).
@export var cost_food: int = 0

@export_group("Effects (Spring/Strategic)")
## The string key used by DynastyManager to apply year-long modifiers (e.g., "expansion_focus").
## If empty, no global modifier is applied.
@export var modifier_key: String = ""
## Immediate resource grant (optional).
@export var grant_gold: int = 0
@export var grant_renown: int = 0

## Returns true if the player can afford this card based on current resources.
## Checks JarlData for AP and SettlementManager for resources.
func can_afford(current_ap: int, current_treasury: Dictionary) -> bool:
	if current_ap < cost_ap:
		return false
	
	# Safety check: Typed dictionary access
	var gold_owned: int = current_treasury.get("gold", 0)
	var food_owned: int = current_treasury.get("food", 0)
	
	if gold_owned < cost_gold:
		return false
	if food_owned < cost_food:
		return false
		
	return true
