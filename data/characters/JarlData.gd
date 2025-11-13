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

## Legitimacy score affecting succession and stability (0-100 scale)
@export var legitimacy: int = 20

## Years remaining in succession debuff (reduced Authority generation)
@export var succession_debuff_years_remaining: int = 0

# --- Builder Pillar Upgrade Properties ---
## Bonus starting renown for all future heirs (from "Erect Jelling Stone")
@export var heir_starting_renown_bonus: int = 0

## An array of unique effect_keys for one-time legacy upgrades
## (e.g., ["UPG_TRELLEBORG", "UPG_JELLING_STONE"])
@export var purchased_legacy_upgrades: Array[String] = []

# --- Unifier Pillar Property ---
## An array of resource paths to WorldRegionData files that have been subjugated.
@export var conquered_regions: Array[String] = []

# --- Progenitor Pillar Property ---
## An array of resource paths to WorldRegionData files that are allied.
@export var allied_regions: Array[String] = []


@export_group("Naval Logistics")
## The distance (in pixels) a fleet can travel with 0% attrition.
@export var safe_naval_range: float = 600.0

## Attrition penalty per 100 pixels beyond safe range (e.g., 0.10 = 10% risk).
@export var attrition_per_100px: float = 0.10


@export_group("Base Skills")
## Combat leadership and personal prowess
@export var command: int = 10
@export var diplomacy: int = 10
@export var stewardship: int = 10
@export var learning: int = 10
@export var prowess: int = 10
@export var charisma: int = 10


@export_group("Traits")
## Array of JarlTraitData resources that modify the Jarl's abilities and story
@export var traits: Array[JarlTraitData] = []
## Legacy trait names for backward compatibility (can be removed later)
@export var legacy_trait_names: Array[String] = []
## Whether this Jarl is currently wounded (affects stats temporarily)
@export var is_wounded: bool = false
## Number of turns remaining for wound recovery
@export var wound_recovery_turns: int = 0

# --- HELPER FUNCTIONS ---

func get_safe_range() -> float:
	# Placeholder for future trait modifiers (e.g. "Seafarer" trait)
	return safe_naval_range

## Get the number of *available* heirs (not on expedition, etc.)
func get_available_heir_count() -> int:
	var count = 0
	for heir in heirs:
		if heir and heir.status == JarlHeirData.HeirStatus.Available:
			count += 1
	return count

## Get the first available heir resource
func get_first_available_heir() -> JarlHeirData:
	for heir in heirs:
		if heir and heir.status == JarlHeirData.HeirStatus.Available:
			return heir
	return null

## Remove an heir from the dynasty (e.g., married off or lost)
## Returns false if the heir could not be found.
func remove_heir(heir_to_remove: JarlHeirData) -> bool:
	if heir_to_remove in heirs:
		heirs.erase(heir_to_remove)
		return true
	return false

## Check if the Jarl has at least one valid, available heir
func check_has_valid_heir() -> bool:
	return get_first_available_heir() != null


@export_group("Family & Succession")
## The Jarl's spouse (if any)
@export var spouse_name: String = ""
## Array of JarlHeirData resources in order of succession priority
@export var heirs: Array[JarlHeirData] = []

## DEPRECATED Properties (kept for compatibility if needed)
var has_valid_heir: bool:
	get: return check_has_valid_heir()
var children_count: int:
	get: return get_available_heir_count()


@export_group("Political Status")
@export var title: String = "Jarl"
@export var vassal_count: int = 0
@export var reputation: int = 0
@export var is_in_exile: bool = false


@export_group("Combat & Mission State")
@export var is_on_mission: bool = false
@export var battles_fought: int = 0
@export var battles_won: int = 0
@export var successful_raids: int = 0


## Get the effective skill value including trait modifiers
func get_effective_skill(skill_name: String) -> int:
	var base_value: int = 0
	match skill_name.to_lower():
		"command": base_value = command
		"diplomacy": base_value = diplomacy
		"stewardship": base_value = stewardship
		"learning": base_value = learning
		"prowess": base_value = prowess
		"charisma": base_value = charisma
		_: return 0
	
	var trait_modifier: int = 0
	for jarl_trait in traits:
		if jarl_trait == null: continue
		match skill_name.to_lower():
			"command": trait_modifier += jarl_trait.command_modifier
			"stewardship": trait_modifier += jarl_trait.stewardship_modifier
			"intrigue": trait_modifier += jarl_trait.intrigue_modifier
	
	return base_value + trait_modifier


## Add a trait to the Jarl (if not already present)
func add_trait(trait_data: JarlTraitData) -> void:
	if trait_data == null: return
	for existing_trait in traits:
		if existing_trait != null and existing_trait.display_name == trait_data.display_name:
			return
	traits.append(trait_data)

## Check if Jarl has a specific trait by display name
func has_trait(trait_name: String) -> bool:
	for jarl_trait in traits:
		if jarl_trait != null and jarl_trait.display_name == trait_name:
			return true
	return false

## Get the Jarl's Authority cap based on Renown Tier
func get_authority_cap() -> int:
	match renown_tier:
		0: return 3
		1: return 5
		2: return 7
		_: return 3 + renown_tier

func can_take_action(authority_cost: int = 1) -> bool:
	return current_authority >= authority_cost

func spend_authority(cost: int = 1) -> bool:
	if can_take_action(cost):
		current_authority -= cost
		return true
	return false

func award_renown(amount: int) -> void:
	renown += amount
	years_since_action = 0
	_update_renown_tier()

func _update_renown_tier() -> void:
	if renown >= 1000: renown_tier = 3
	elif renown >= 500: renown_tier = 2
	elif renown >= 200: renown_tier = 1
	else: renown_tier = 0

func reset_authority() -> void:
	max_authority = get_authority_cap()
	if succession_debuff_years_remaining > 0:
		var legit_multiplier = legitimacy / 100.0
		var authority_gained = int(round(max_authority * legit_multiplier))
		current_authority = max(1, authority_gained)
		succession_debuff_years_remaining -= 1
	else:
		current_authority = max_authority

func age_jarl(years: int = 1) -> void:
	age += years
	years_since_action += years
	if age > 60:
		prowess = max(1, prowess - 1)
		learning = min(20, learning + 1)

func remove_trait(trait_name: String) -> bool:
	for i in range(traits.size()):
		if traits[i] != null and traits[i].display_name == trait_name:
			traits.remove_at(i)
			return true
	return false
