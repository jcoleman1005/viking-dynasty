class_name SeasonalCardResource
extends Resource

enum SeasonType { SPRING, WINTER }

@export_group("Classification")
## Ensures this card only appears in the correct UI.
@export var season: SeasonType = SeasonType.SPRING

@export_group("Display")
@export var title: String = "Card Title"
@export_multiline var description: String = "Effect description..."
@export var icon: Texture2D

@export_group("Costs (Winter)")
@export var cost_ap: int = 0
@export var cost_gold: int = 0
@export var cost_food: int = 0

@export_group("Effects (Spring/Strategic)")
## The string tag stored in DynastyManager.active_year_modifiers.
## Example: "raid_provisions_bonus" or "farm_yield_boost"
@export var modifier_key: String = ""
@export var grant_gold: int = 0
@export var grant_renown: int = 0
