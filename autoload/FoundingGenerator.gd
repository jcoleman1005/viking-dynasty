# res://autoload/FoundingGenerator.gd
# Generates JarlData and initial settlement state from FoundingData.
extends Node

func generate_from_founding(data: FoundingData) -> JarlData:
	var jarl = JarlData.new()
	jarl.display_name = data.jarl_name if data.jarl_name != "" else _generate_jarl_name()
	
	# Stat generation
	jarl.command     = _roll_stat(data, "command")
	jarl.prowess     = _roll_stat(data, "prowess")
	jarl.stewardship = _roll_stat(data, "stewardship")
	jarl.learning    = _roll_stat(data, "learning")
	jarl.diplomacy   = _roll_stat(data, "diplomacy")
	jarl.charisma    = _roll_stat(data, "charisma")
	
	# Store founding context for Spring card weighting
	jarl.founding_archetype = data.father_archetype
	jarl.exile_reason = data.exile_reason
	jarl.first_act = data.first_act
	jarl.founding_epithet = data.founding_epithet
	
	# Apply exile mechanical effects
	_apply_exile_effects(data, jarl)
	
	return jarl

func _roll_stat(data: FoundingData, stat: String) -> int:
	if stat == data.strength_stat:
		return randi_range(10, 15)   # boosted
	elif stat == data.flaw_stat:
		return randi_range(5, 8)     # penalised
	else:
		return randi_range(5, 15)    # normal

func assemble_epithet(data: FoundingData) -> String:
	# Picks father name from archetype pool
	var names := _get_father_names(data.father_archetype)
	data.father_name = names.pick_random()
	
	# Extract seed from strength clause if not already stored
	# (In a real implementation, strength_clause would be a resource or ID)
	var seed_text := _get_epithet_seed(data.strength_stat)
	
	return "%s, %s" % [data.father_name, seed_text]

func _apply_exile_effects(data: FoundingData, jarl: JarlData) -> void:
	# This will be called when the settlement is initialized or Jarl is assigned
	match data.exile_reason:
		"frankish":
			jarl.add_trait(load("res://data/traits/Trait_Dispossessed.tres"))
		"rival":
			jarl.diplomacy = max(1, jarl.diplomacy - 2) # Authority cost
	
	# First act effects are usually applied to households in SettlementManager
	# but we can store them as flags or initial loyalty values.

func _get_father_names(archetype: String) -> Array[String]:
	match archetype:
		"warrior": return ["Bjorn", "Ragnar", "Ivar", "Sigurd", "Erik", "Gunnar", "Harald", "Leif", "Olaf", "Rollo"]
		"builder": return ["Halvar", "Sten", "Knut", "Arne", "Birger", "Einar", "Gorm", "Hakon", "Magnus", "Sven"]
		"diplomat": return ["Alaric", "Cnut", "Godfrid", "Harald", "Sweyn", "Tostig", "Ulf", "Valdemar", "Vidar", "Asger"]
	return ["Norseman"]

func _get_epithet_seed(stat: String) -> String:
	match stat:
		"command": return "the Unyielding"
		"prowess": return "the Bold"
		"stewardship": return "the Provider"
		"learning": return "the Far-Sighted"
		"diplomacy": return "the Peacemaker"
		"charisma": return "the Beloved"
	return "the Elder"

func _generate_jarl_name() -> String:
	var names = ["Bjorn", "Ragnar", "Ivar", "Sigurd", "Erik", "Gunnar", "Harald", "Leif", "Olaf", "Rollo"]
	return names.pick_random()
