# res://scripts/data/GameResources.gd
class_name GameResources
extends RefCounted

# -- Core Currencies --
const GOLD := "gold"
const WOOD := "wood"
const FOOD := "food"
const STONE := "stone"

# -- Population --
const POP_PEASANT := "peasant"
const POP_THRALL := "thrall"

# -- Helpers for UI Iteration --
const ALL_CURRENCIES = [GOLD, WOOD, FOOD, STONE]
const ALL_POPULATION = [POP_PEASANT, POP_THRALL]

# Optional: Centralized display names
static func get_display_name(key: String) -> String:
	match key:
		GOLD: return "Gold"
		WOOD: return "Wood"
		FOOD: return "Food"
		STONE: return "Stone"
		POP_PEASANT: return "Villager"
		POP_THRALL: return "Thrall"
		_: return "Unknown"
