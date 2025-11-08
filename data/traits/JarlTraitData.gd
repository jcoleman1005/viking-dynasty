# res://data/traits/JarlTraitData.gd
#
# This resource defines the statistical and diplomatic impact of a single trait.
# Renamed to JarlTraitData to avoid keyword conflict with Godot's internal 'Trait'.
class_name JarlTraitData
extends Resource

## General Information
@export var display_name: String = ""
@export var description: String = ""
@export var is_visible: bool = true # Should the player/AI know about this trait?

## Character Skill Modifiers (Permanent)
# Used to adjust the Jarl's base skills (Command, Stewardship, Intrigue)
@export_group("Skill Modifiers")
@export var command_modifier: int = 0
@export var stewardship_modifier: int = 0
@export var intrigue_modifier: int = 0

## Macro Layer Modifiers (Diplomacy/Renown)
@export_group("Macro Modifiers")
@export var renown_per_year_modifier: float = 0.0 # Used for passive Renown gain/loss
@export var vassal_opinion_modifier: int = 0  # Global change to vassal opinion of Jarl
@export var alliance_cost_modifier: float = 1.0 # Multiplier for alliance Authority cost

## Behavioral Flags (For AI and Event Triggers)
@export_group("Behavior Flags")
@export var is_wounded_trait: bool = false # e.g., Maimed, Crippled
@export var is_dishonorable_trait: bool = false # e.g., Betrayer, Cowardly
