class_name SeasonalCardResource
extends Resource

enum SeasonType { SPRING, WINTER }

## The name displayed on the card
@export var display_name: String = "Card Name"

## The description text (supports BBCode)
@export_multiline var description: String = "Card Description"

## Icon for the card
@export var icon: Texture2D

@export var season: SeasonType

@export_group("Costs")
## Action Points required to play this card
@export var cost_ap: int = 1
## Gold cost (if any)
@export var cost_gold: int = 0
## Food cost (if any)
@export var cost_food: int = 0

@export_group("Immediate Rewards")
## Gold granted immediately
@export var grant_gold: int = 0
## Renown granted immediately
@export var grant_renown: int = 0
## Authority granted
@export var grant_authority: int = 0

@export_group("Seasonal Modifiers")
## Dictionary for arbitrary modifiers not covered by explicit variables.
## Format: { "custom_key": float_value }
@export var modifiers: Dictionary = {} 
## Percentage bonus to unit combat damage (e.g., 0.10 = +10%)
@export_range(-1.0, 5.0, 0.05) var mod_unit_damage: float = 0.0

## Percentage bonus to Raid XP gain (e.g., 0.20 = +20%)
@export_range(-1.0, 5.0, 0.05) var mod_raid_xp: float = 0.0

## Flat increase to birth probability (e.g., 0.05 = +5% chance)
@export_range(-1.0, 1.0, 0.01) var mod_birth_chance: float = 0.0

## Multiplier for harvest yield next season (e.g. 0.10 = +10%)
@export_range(-1.0, 5.0, 0.05) var mod_harvest_yield: float = 0.0
