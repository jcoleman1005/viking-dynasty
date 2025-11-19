# res://data/units/WarbandData.gd
class_name WarbandData
extends Resource

@export var custom_name: String = "New Warband"
@export var unit_type: UnitData

# --- PROGRESSION ---
@export var experience: int = 0
const XP_PER_LEVEL: int = 100
const MAX_LEVEL: int = 5

func get_level() -> int:
	return min(1 + (experience / XP_PER_LEVEL), MAX_LEVEL)

func get_level_title() -> String:
	var lvl = get_level()
	match lvl:
		1: return "Rookie"
		2: return "Trained"
		3: return "Hardened"
		4: return "Veteran"
		5: return "Elite"
		_: return "Warrior"

func get_stat_multiplier() -> float:
	# 10% bonus stats per level above 1
	var lvl = get_level()
	return 1.0 + ((lvl - 1) * 0.10)
# -------------------

# ... (Keep Loyalty, Manpower, and Init logic) ...
@export var loyalty: int = 100
@export var turns_idle: int = 0
@export var current_manpower: int = 10
const MAX_MANPOWER: int = 10
@export var is_wounded: bool = false
@export var battles_survived: int = 0
@export var history_log: Array[String] = []

func _init(p_unit_type: UnitData = null) -> void:
	if p_unit_type:
		unit_type = p_unit_type
		custom_name = _generate_warband_name(p_unit_type.display_name)
		current_manpower = MAX_MANPOWER
		loyalty = 100

func _generate_warband_name(base_name: String) -> String:
	var prefixes = ["Iron", "Blood", "Storm", "Night", "Wolf", "Bear", "Raven"]
	var suffixes = ["Guard", "Raiders", "Blades", "Shields", "Hunters", "Fists"]
	return "%s %s" % [prefixes.pick_random(), suffixes.pick_random()]
	
func get_loyalty_description(jarl_name: String) -> String:
	if loyalty >= 90: return "[color=gold]Fanatically loyal to %s[/color]" % jarl_name
	elif loyalty >= 70: return "[color=green]Loyal to %s[/color]" % jarl_name
	elif loyalty >= 40: return "[color=white]Content[/color]"
	elif loyalty >= 20: return "[color=yellow]Restless[/color]"
	else: return "[color=red]Mutinous[/color]"

func modify_loyalty(amount: int) -> void:
	loyalty = clampi(loyalty + amount, 0, 100)
