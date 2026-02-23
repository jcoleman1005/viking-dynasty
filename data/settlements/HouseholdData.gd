class_name HouseholdData
extends Resource

enum SeasonalOath { IDLE, HARVEST, TIMBER, BUILD, RAID }

@export var household_name: String = "The Red-Shields"
@export var head_of_household: HouseholdHead = null # New: Lineage system
@export var member_count: int = 10
@export var current_oath: SeasonalOath = SeasonalOath.IDLE

# Phase 3 & 5 systems
@export var loyalty: int = 100:
	set(val):
		loyalty = clampi(val, 0, 100)

## Years spent consecutively on the same Oath (Tradition Bonus)
@export var consecutive_oath_years: int = 0
## Tracks the last type of oath to detect changes
@export var last_oath_type: SeasonalOath = SeasonalOath.IDLE

## Returns efficiency based on loyalty, tradition, and head traits (Max ~1.5, Min 0.5)
var labor_efficiency: float:
	get:
		var efficiency = 0.5 + (float(loyalty) / 100.0) * 0.5
		
		# 1. Tradition Bonus (+5% per year, max 25%)
		efficiency += min(0.25, consecutive_oath_years * 0.05)
		
		# 2. Head Trait Bonus
		if head_of_household and head_of_household.head_trait:
			var trait_name = head_of_household.head_trait.display_name
			match current_oath:
				SeasonalOath.BUILD:
					if trait_name == "Mason Blood": efficiency += 0.15
				SeasonalOath.RAID:
					if trait_name == "Sea-Reaver": efficiency += 0.10
				SeasonalOath.HARVEST:
					if trait_name == "Farmer's Hand": efficiency += 0.10
					
		return efficiency

@export var oath_locked_until_season: int = 0

@export var icon: Texture2D
