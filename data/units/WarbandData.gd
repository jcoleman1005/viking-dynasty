# res://data/units/WarbandData.gd
class_name WarbandData
extends Resource

@export var custom_name: String = "New Warband"
@export var unit_type: UnitData
@export var experience: int = 0
@export var loyalty: int = 100

# --- NEW: Manpower Tracking ---
## Current number of able-bodied soldiers in this squad.
@export var current_manpower: int = 10
## Maximum squad size (fixed by design).
const MAX_MANPOWER: int = 10
# ------------------------------

@export var is_wounded: bool = false
@export var battles_survived: int = 0
@export var history_log: Array[String] = []

func _init(p_unit_type: UnitData = null) -> void:
	if p_unit_type:
		unit_type = p_unit_type
		custom_name = _generate_warband_name(p_unit_type.display_name)
		# Ensure full strength on recruit
		current_manpower = MAX_MANPOWER

func _generate_warband_name(base_name: String) -> String:
	var prefixes = ["Iron", "Blood", "Storm", "Night", "Wolf", "Bear", "Raven"]
	var suffixes = ["Guard", "Raiders", "Blades", "Shields", "Hunters", "Fists"]
	return "%s %s" % [prefixes.pick_random(), suffixes.pick_random()]
