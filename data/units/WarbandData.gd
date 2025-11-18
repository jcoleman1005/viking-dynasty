# res://data/units/WarbandData.gd
class_name WarbandData
extends Resource

@export var custom_name: String = "New Warband"
@export var unit_type: UnitData
@export var experience: int = 0

# --- LOYALTY SYSTEM ---
@export var loyalty: int = 100 # 0-100
@export var turns_idle: int = 0 # Still track this for decay calculations

func get_loyalty_description(jarl_name: String) -> String:
	if loyalty >= 90:
		return "[color=gold]Fanatically loyal to %s[/color]" % jarl_name
	elif loyalty >= 70:
		return "[color=green]Loyal to %s[/color]" % jarl_name
	elif loyalty >= 40:
		return "[color=white]Content[/color]"
	elif loyalty >= 20:
		return "[color=yellow]Restless[/color]"
	else:
		return "[color=red]Mutinous[/color]"

func modify_loyalty(amount: int) -> void:
	loyalty = clampi(loyalty + amount, 0, 100)
# ----------------------

# --- Manpower Tracking ---
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
