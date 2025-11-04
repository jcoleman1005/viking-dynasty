# res://data/characters/JarlData.gd
#
# Defines the persistent data for a Jarl character in Viking Dynasty.
# This resource stores all the attributes that persist across the dynasty layer.
# GDD Ref: Section 2.A (Macro Layer), Appendix A.2 (Renown & Succession Loop)

class_name JarlData
extends Resource

## The Jarl's name displayed in the UI
@export var display_name: String = "New Jarl"

## The Jarl's portrait/icon for the UI
@export var portrait: Texture2D

## The Jarl's age in years
@export var age: int = 25

## The Jarl's gender (affects marriage and succession options)
@export var gender: String = "Male"  # "Male", "Female"


@export_group("Dynasty & Authority")
## Total Renown accumulated by this Jarl (persistent XP/Legacy score)
@export var renown: int = 0

## Current Renown Tier (determines Authority cap per year)
## Tiers: 0="Petty Jarl", 1="High Jarl", 2="Kingmaker", etc.
@export var renown_tier: int = 0

## Authority remaining for this year (action points for Macro layer)
@export var current_authority: int = 3

## Maximum Authority this Jarl can generate per year (based on Renown Tier)
@export var max_authority: int = 3

## Years since last offensive action (for Renown Decay calculations)
@export var years_since_action: int = 0


@export_group("Base Skills")
## Combat leadership and personal prowess
@export var command: int = 10

## Diplomatic skills and charm
@export var diplomacy: int = 10

## Strategic planning and administration
@export var stewardship: int = 10

## Religious knowledge and mysticism
@export var learning: int = 10

## Personal combat skill and courage
@export var prowess: int = 10

## Ability to inspire and lead
@export var charisma: int = 10


@export_group("Traits")
## Array of trait names that modify the Jarl's abilities and story
## Examples: "Brave", "Cruel", "Wounded", "Maimed", "Betrayer", "Wise"
@export var traits: Array[String] = []

## Whether this Jarl is currently wounded (affects stats temporarily)
@export var is_wounded: bool = false

## Number of turns remaining for wound recovery
@export var wound_recovery_turns: int = 0


@export_group("Family & Succession")
## The Jarl's spouse (if any)
@export var spouse_name: String = ""

## Array of heir names in order of succession priority
@export var heirs: Array[String] = []

## Whether this Jarl has a designated heir
@export var has_valid_heir: bool = false

## Number of living children
@export var children_count: int = 0


@export_group("Political Status")
## Current title/rank in the political hierarchy
@export var title: String = "Jarl"

## Number of vassals under this Jarl's rule
@export var vassal_count: int = 0

## Overall diplomatic reputation with other Jarls
@export var reputation: int = 0

## Whether this Jarl is currently in exile or displaced
@export var is_in_exile: bool = false


@export_group("Combat & Mission State")
## Whether the Jarl is currently leading a raid (affects vulnerability)
@export var is_on_mission: bool = false

## Number of battles this Jarl has fought
@export var battles_fought: int = 0

## Number of battles this Jarl has won
@export var battles_won: int = 0

## Total successful raids completed
@export var successful_raids: int = 0


## Get the effective skill value including trait modifiers
func get_effective_skill(skill_name: String) -> int:
	var base_value: int = 0
	
	match skill_name.to_lower():
		"command":
			base_value = command
		"diplomacy":
			base_value = diplomacy
		"stewardship":
			base_value = stewardship
		"learning":
			base_value = learning
		"prowess":
			base_value = prowess
		"charisma":
			base_value = charisma
		_:
			return 0
	
	return base_value


## Add a trait to the Jarl (if not already present)
func add_trait(trait_name: String) -> void:
	if trait_name not in traits:
		traits.append(trait_name)


## Remove a trait from the Jarl
func remove_trait(trait_name: String) -> void:
	var index = traits.find(trait_name)
	if index >= 0:
		traits.remove_at(index)


## Check if Jarl has a specific trait
func has_trait(trait_name: String) -> bool:
	return trait_name in traits


## Get the Jarl's Authority cap based on Renown Tier (GDD reference)
func get_authority_cap() -> int:
	match renown_tier:
		0: return 3  # Petty Jarl
		1: return 5  # High Jarl
		2: return 7  # Kingmaker
		_: return 3 + renown_tier  # Future tiers


## Check if the Jarl can take an action (has Authority remaining)
func can_take_action(authority_cost: int = 1) -> bool:
	return current_authority >= authority_cost


## Spend Authority for an action
func spend_authority(cost: int = 1) -> bool:
	if can_take_action(cost):
		current_authority -= cost
		return true
	return false


## Award Renown for completing a major action
func award_renown(amount: int) -> void:
	renown += amount
	years_since_action = 0
	_update_renown_tier()


## Update Renown Tier based on current Renown
func _update_renown_tier() -> void:
	if renown >= 1000:
		renown_tier = 3
	elif renown >= 500:
		renown_tier = 2
	elif renown >= 200:
		renown_tier = 1
	else:
		renown_tier = 0
