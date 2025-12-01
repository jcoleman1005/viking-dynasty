# res://autoload/WinterManager.gd
extends Node

# --- Severity Definitions ---
enum WinterSeverity { MILD, NORMAL, HARSH }

# --- Configuration (Tunable in Inspector) ---
@export_group("Probabilities")
## Chance of a Harsh Winter (0.0 to 1.0). Default 20%.
@export_range(0.0, 1.0) var harsh_chance: float = 0.20
## Chance of a Mild Winter (0.0 to 1.0). Default 5%.
@export_range(0.0, 1.0) var mild_chance: float = 0.05
# Normal winter is the remainder.

@export_group("Multipliers")
## Cost multiplier for Harsh winters. Default 1.5x.
@export var harsh_multiplier: float = 1.5
## Cost multiplier for Mild winters. Default 0.75x.
@export var mild_multiplier: float = 0.75

# --- Internal State ---
var current_severity: WinterSeverity = WinterSeverity.NORMAL

func calculate_winter_demand(settlement: SettlementData) -> Dictionary:
	"""
	Rolls the dice for severity and calculates the raw resource demand.
	Returns a Dictionary with the costs and the severity flavor.
	"""
	if not settlement:
		return _get_empty_report()

	# 1. Roll for Severity
	_roll_severity()
	
	# 2. Determine Multiplier
	var mult: float = 1.0
	match current_severity:
		WinterSeverity.HARSH: mult = harsh_multiplier
		WinterSeverity.MILD: mult = mild_multiplier
		_: mult = 1.0
		
	# 3. Calculate Base Demand
	# Logic: 1 Food per Peasant, 5 per Warband. 20 Wood Base.
	var base_food = (settlement.population_peasants * 1) + (settlement.warbands.size() * 5)
	var base_wood = 20
	
	# 4. Apply Multiplier
	var final_food = int(base_food * mult)
	var final_wood = int(base_wood * mult)
	
	# 5. Build Report
	return {
		"severity_enum": current_severity,
		"severity_name": WinterSeverity.keys()[current_severity],
		"multiplier": mult,
		"food_demand": final_food,
		"wood_demand": final_wood
	}

func _roll_severity() -> void:
	var roll = randf()
	
	# Logic: 
	# If roll < 0.20 -> Harsh
	# If roll > 0.95 (1.0 - 0.05) -> Mild
	# Else -> Normal
	
	if roll < harsh_chance:
		current_severity = WinterSeverity.HARSH
	elif roll > (1.0 - mild_chance):
		current_severity = WinterSeverity.MILD
	else:
		current_severity = WinterSeverity.NORMAL
		
	Loggie.msg("WinterManager: Rolled %s (Val: %.2f)" % [WinterSeverity.keys()[current_severity], roll]).domain(LogDomains.SYSTEM).info()

func _get_empty_report() -> Dictionary:
	return {
		"severity_name": "NORMAL",
		"multiplier": 1.0,
		"food_demand": 0,
		"wood_demand": 0
	}
