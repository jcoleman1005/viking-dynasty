class_name HouseholdData
extends Resource

enum SeasonalOath { IDLE, HARVEST, TIMBER, BUILD, RAID }

@export var household_name: String = "The Red-Shields"
@export var member_count: int = 10
@export var current_oath: SeasonalOath = SeasonalOath.IDLE

# Phase 3 systems
@export var loyalty: int = 100

# Future-proofing (added now to avoid refactor later)
@export var labor_efficiency: float = 1.0
@export var oath_locked_until_season: int = 0

@export var icon: Texture2D
