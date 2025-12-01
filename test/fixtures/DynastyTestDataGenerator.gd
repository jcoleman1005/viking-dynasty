# res://test/DynastyTestDataGenerator.gd
class_name DynastyTestDataGenerator
extends RefCounted

static func generate_test_dynasty() -> JarlData:
	var jarl = JarlData.new()
	jarl.display_name = "Jarl Testor the Builder"
	jarl.age = 45
	jarl.renown = 1250
	jarl.current_authority = 3
	jarl.max_authority = 5
	
	# --- 1. Populate Ancestors ---
	var ancestors_data: Array[Dictionary] = [
		{
			"name": "Harald Tanglehair",
			"death_reason": "Died in battle against Saxons",
			"final_renown": 800
		},
		{
			"name": "Halfdan the Black",
			"death_reason": "Drowned in a frozen lake",
			"final_renown": 1500
		},
		{
			"name": "Sigurd Snake-in-the-Eye",
			"death_reason": "Old age",
			"final_renown": 2200
		}
	]
	jarl.ancestors = ancestors_data
	
	# --- 2. Create Heirs with different states ---
	
	# Heir 1: The Golden Child (Designated)
	var heir1 = JarlHeirData.new()
	heir1.display_name = "Magnus"
	heir1.age = 22
	heir1.prowess = 15
	heir1.stewardship = 12
	heir1.is_designated_heir = true
	heir1.status = JarlHeirData.HeirStatus.Available
	# Dummy Trait
	heir1.genetic_trait = JarlTraitData.new()
	heir1.genetic_trait.display_name = "Strong"
	jarl.heirs.append(heir1)
	
	# Heir 2: The Adventurer (On Expedition)
	var heir2 = JarlHeirData.new()
	heir2.display_name = "Leif"
	heir2.age = 20
	heir2.prowess = 10
	heir2.stewardship = 8
	heir2.status = JarlHeirData.HeirStatus.OnExpedition
	heir2.expedition_years_remaining = 2
	jarl.heirs.append(heir2)
	
	# Heir 3: The Unfortunate (Maimed)
	var heir3 = JarlHeirData.new()
	heir3.display_name = "Ivar"
	heir3.age = 19
	heir3.prowess = 4
	heir3.stewardship = 14
	heir3.status = JarlHeirData.HeirStatus.Maimed
	heir3.genetic_trait = JarlTraitData.new()
	heir3.genetic_trait.display_name = "Genius"
	jarl.heirs.append(heir3)
	
	# Heir 4: The Diplomat (Married Off)
	var heir4 = JarlHeirData.new()
	heir4.display_name = "Gyda"
	heir4.age = 18
	heir4.gender = "Female"
	heir4.prowess = 5
	heir4.stewardship = 15
	heir4.status = JarlHeirData.HeirStatus.MarriedOff
	jarl.heirs.append(heir4)
	
	print("DynastyTestDataGenerator: Generated Jarl '%s' with %d heirs." % [jarl.display_name, jarl.heirs.size()])
	return jarl
