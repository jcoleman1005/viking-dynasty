#res://data/characters/JarlData.gd
# res://data/characters/JarlData.gd
class_name JarlData
extends Resource

## The Jarl's name displayed in the UI
@export var display_name: String = "New Jarl"

## The Jarl's portrait/icon for the UI
@export var portrait: Texture2D

## The Jarl's age in years
@export var age: int = 25

## The Jarl's gender
@export var gender: String = "Male" # "Male", "Female"

@export_group("Dynasty & Authority")
## Total Renown accumulated by this Jarl
@export var renown: int = 0

## Current Renown Tier (0-3)
@export var renown_tier: int = 0

## Authority remaining for this year
@export var current_authority: int = 3

## Maximum Authority this Jarl can generate per year
@export var max_authority: int = 3

## Years since last offensive action
@export var years_since_action: int = 0

## Legitimacy score (0-100)
@export var legitimacy: int = 20

## Years remaining in succession debuff
@export var succession_debuff_years_remaining: int = 0

# --- NEW: Lineage History ---
@export_group("Lineage History")
## Stores dictionaries of past rulers: { "name": String, "portrait": Texture2D, "final_renown": int, "death_reason": String }
@export var ancestors: Array[Dictionary] = []
# ----------------------------

# --- Builder Pillar ---
@export var heir_starting_renown_bonus: int = 0
@export var purchased_legacy_upgrades: Array[String] = []

# --- Unifier Pillar ---
@export var conquered_regions: Array[String] = []

# --- Progenitor Pillar ---
@export var allied_regions: Array[String] = []

@export_group("Naval Logistics")
@export var safe_naval_range: float = 600.0
@export var attrition_per_100px: float = 0.10

@export_group("Base Skills")
@export var command: int = 10
@export var diplomacy: int = 10
@export var stewardship: int = 10
@export var learning: int = 10
@export var prowess: int = 10
@export var charisma: int = 10

@export_group("Traits")
@export var traits: Array[JarlTraitData] = []
@export var legacy_trait_names: Array[String] = []
@export var is_wounded: bool = false
@export var wound_recovery_turns: int = 0

@export_group("Family & Succession")
@export var spouse_name: String = ""
## Array of JarlHeirData resources
@export var heirs: Array[JarlHeirData] = []

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
## Tracks progress towards Warlord trait
@export var offensive_wins: int = 0 

@export_group("Winter Court")
var current_hall_actions: int = 0
var max_hall_actions: int = 0
# --- HELPER FUNCTIONS ---

func calculate_hall_actions() -> void:
	# Formula: (Stewardship + Diplomacy) / 5, clamped 2 to 5.
	# Note: Using 'charisma' as proxy for Diplomacy if Diplomacy isn't explicitly defined yet.
	var score = stewardship + charisma 
	max_hall_actions = clampi(score / 5, 2, 5)
	current_hall_actions = max_hall_actions

func get_safe_range() -> float:
	return safe_naval_range

func get_available_heir_count() -> int:
	var count = 0
	for heir in heirs:
		if heir and heir.status == JarlHeirData.HeirStatus.Available:
			count += 1
	return count

func get_first_available_heir() -> JarlHeirData:
	for heir in heirs:
		if heir and heir.status == JarlHeirData.HeirStatus.Available:
			return heir
	return null

func remove_heir(heir_to_remove: JarlHeirData) -> bool:
	if heir_to_remove in heirs:
		heirs.erase(heir_to_remove)
		return true
	
	# LOGGIE: Warning if trying to remove non-existent heir
	if Engine.is_editor_hint() == false: # Prevent tool script spam
		Loggie.msg("JarlData: Attempted to remove heir '%s', but they were not in the list." % heir_to_remove.display_name).domain(LogDomains.DYNASTY).warn()
	return false

func check_has_valid_heir() -> bool:
	return get_first_available_heir() != null

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

func add_trait(trait_data: JarlTraitData) -> void:
	if trait_data == null: return
	for existing_trait in traits:
		if existing_trait != null and existing_trait.display_name == trait_data.display_name:
			return
	traits.append(trait_data)

func has_trait(trait_name: String) -> bool:
	for jarl_trait in traits:
		if jarl_trait != null and jarl_trait.display_name == trait_name:
			return true
	return false

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
	
	# LOGGIE: Logic error catching
	if Engine.is_editor_hint() == false:
		Loggie.msg("JarlData: Insufficient Authority. Needed %d, had %d." % [cost, current_authority]).domain(LogDomains.DYNASTY).debug()
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
