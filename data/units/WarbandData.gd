# res://data/units/WarbandData.gd
class_name WarbandData
extends Resource

@export var custom_name: String = "New Warband"
@export var unit_type: UnitData

# --- PROGRESSION: DRILL (XP) ---
@export var experience: int = 0
const XP_PER_LEVEL: int = 100
const MAX_LEVEL: int = 5

# --- PROGRESSION: GEAR (GOLD) ---
@export var gear_tier: int = 0
const MAX_GEAR_TIER: int = 3

# --- LEADERSHIP ---
@export var assigned_heir_name: String = ""

# --- LOYALTY ---
@export var loyalty: int = 100
@export var turns_idle: int = 0

# --- MANPOWER ---
@export var current_manpower: int = 10
const MAX_MANPOWER: int = 10

# --- HEARTH GUARD (The Missing Link) ---
@export var is_hearth_guard: bool = false
# ---------------------------------------

@export var is_wounded: bool = false
@export var battles_survived: int = 0
@export var history_log: Array[String] = []

func _init(p_unit_type: UnitData = null) -> void:
	if p_unit_type:
		unit_type = p_unit_type
		custom_name = _generate_warband_name(p_unit_type.display_name)
		current_manpower = MAX_MANPOWER
		loyalty = 100

func add_history(entry: String) -> void:
	history_log.append(entry)

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
	var lvl = get_level()
	return 1.0 + ((lvl - 1) * 0.10)

func get_gear_cost() -> int:
	match gear_tier:
		0: return 100
		1: return 250
		2: return 500
		_: return 9999

func get_gear_name() -> String:
	match gear_tier:
		0: return "Peasant Garb"
		1: return "Leather Armor"
		2: return "Chainmail"
		3: return "Splint Armor"
		_: return "Godly Plate"

func get_gear_health_mult() -> float:
	return 1.0 + (gear_tier * 0.25)

func get_gear_damage_mult() -> float:
	return 1.0 + (gear_tier * 0.10)

func get_loyalty_description(jarl_name: String) -> String:
	if loyalty >= 90: return "[color=gold]Fanatically loyal to %s[/color]" % jarl_name
	elif loyalty >= 70: return "[color=green]Loyal to %s[/color]" % jarl_name
	elif loyalty >= 40: return "[color=white]Content[/color]"
	elif loyalty >= 20: return "[color=yellow]Restless[/color]"
	else: return "[color=red]Mutinous[/color]"

func modify_loyalty(amount: int) -> void:
	loyalty = clampi(loyalty + amount, 0, 100)

func _generate_warband_name(_base_name: String) -> String:
	var prefixes = ["Iron", "Blood", "Storm", "Night", "Wolf", "Bear", "Raven"]
	var suffixes = ["Guard", "Raiders", "Blades", "Shields", "Hunters", "Fists"]
	return "%s %s" % [prefixes.pick_random(), suffixes.pick_random()]
