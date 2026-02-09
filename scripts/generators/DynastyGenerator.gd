#res://scripts/generators/DynastyGenerator.gd
# res://scripts/generators/DynastyGenerator.gd
class_name DynastyGenerator
extends RefCounted

const MALE_NAMES = ["Ragnar", "Bjorn", "Ivar", "Sigurd", "Ubbe", "Halfdan", "Harald", "Erik", "Leif", "Sven", "Olaf", "Knut", "Torstein", "Floki", "Rollo", "Arvid"]
const FEMALE_NAMES = ["Lagertha", "Aslaug", "Gunnhild", "Torvi", "Helga", "Siggy", "Astrid", "Freydis", "Ylva", "Thyra", "Ingrid", "Ragnhild", "Sif", "Hilda"]
const SURNAMES = ["Lothbrok", "Ironside", "the Boneless", "Snake-in-the-Eye", "Fairhair", "Red", "the Lucky", "Forkbeard"]

# --- PORTRAIT CONFIGURATION ---
# Add your file paths here. You can add as many as you like.
const PORTRAIT_PATHS = {
	"Male": {
		"Young": [
			"res://assets/portraits/young male.png",
			"res://assets/portraits/young man 2.png"
		],
		"Adult": [
			"res://assets/portraits/adult male.png",
			"res://assets/portraits/adult male 2.png"
		],
		"Elder": [
			"res://assets/portraits/elder male.png",
			"res://assets/portraits/male/elder_2.png"
		]
	},
	"Female": {
		"Young": [
			"res://assets/portraits/young woman 2.png",
			"res://assets/portraits/young woman.png"
		],
		"Adult": [
			"res://assets/portraits/shield maiden.png",
			"res://assets/portraits/adult woman.png"
		],
		"Elder": [
			"res://assets/portraits/elderly woman 2.png",
			
		]
	}
}

static func generate_random_dynasty() -> JarlData:
	var jarl = JarlData.new()
	
	# 1. Basic Identity
	jarl.gender = "Male" if randf() > 0.3 else "Female"
	jarl.display_name = _generate_name(jarl.gender)
	jarl.age = randi_range(25, 45)
	
	# --- NEW: Assign Portrait ---
	jarl.portrait = _get_random_portrait(jarl.gender, jarl.age)
	
	# 2. Base Stats
	jarl.command = randi_range(8, 15)
	jarl.stewardship = randi_range(8, 15)
	jarl.diplomacy = randi_range(8, 15)
	jarl.prowess = randi_range(8, 15)
	jarl.learning = randi_range(5, 12)
	
	# 3. Derived Stats
	jarl.renown = 0
	jarl.current_authority = 3
	jarl.max_authority = 3
	jarl.legitimacy = 50 
	
	# 4. Generate Heirs
	var heir_count = randi_range(1, 2)
	for i in range(heir_count):
		var heir = _generate_heir(jarl.age)
		if i == 0:
			heir.is_designated_heir = true
		jarl.heirs.append(heir)
	
	Loggie.msg("DynastyGenerator: Created %s (Age %d) with %d heirs." % [jarl.display_name, jarl.age, heir_count]).domain(LogDomains.DYNASTY).info()
	return jarl

static func _generate_heir(parent_age: int) -> JarlHeirData:
	var heir = JarlHeirData.new()
	heir.gender = "Male" if randf() > 0.5 else "Female"
	heir.display_name = _generate_name(heir.gender, false) 
	
	# Age logic
	var max_age = max(0, parent_age - 16)
	heir.age = randi_range(max(0, max_age - 10), max_age)
	heir.age = max(0, heir.age)
	
	# --- NEW: Assign Portrait ---
	heir.portrait = _get_random_portrait(heir.gender, heir.age)
	
	# Random Stats
	heir.command = randi_range(5, 12)
	heir.stewardship = randi_range(5, 12)
	heir.prowess = randi_range(5, 12)
	heir.learning = randi_range(5, 12)
	
	heir.status = JarlHeirData.HeirStatus.Available
	
	return heir

static func _generate_name(gender: String, include_surname: bool = true) -> String:
	var name_list = MALE_NAMES if gender == "Male" else FEMALE_NAMES
	var first = name_list.pick_random()
	
	if include_surname and randf() > 0.4:
		var last = SURNAMES.pick_random()
		return "%s %s" % [first, last]
	
	return first

# --- HELPER: Selects the correct image based on stats ---
static func _get_random_portrait(gender: String, age: int) -> Texture2D:
	var age_category = "Adult"
	
	if age < 20:
		age_category = "Young"
	elif age > 50:
		age_category = "Elder"
		
	if PORTRAIT_PATHS.has(gender) and PORTRAIT_PATHS[gender].has(age_category):
		var paths = PORTRAIT_PATHS[gender][age_category]
		if not paths.is_empty():
			var path = paths.pick_random()
			if ResourceLoader.exists(path):
				return load(path)
			else:
				# Fallback if you haven't added the files yet
				return null
				
	return null

static func generate_newborn() -> JarlHeirData:
	var baby = JarlHeirData.new()
	baby.age = 0
	baby.gender = "Male" if randf() > 0.5 else "Female"
	baby.display_name = _generate_name(baby.gender, false) # No surname for kids
	
	# 1. Assign Portrait (Will pick from "Young" category)
	baby.portrait = _get_random_portrait(baby.gender, 0)
	
	# 2. Genetic Traits (Moved here from DynastyManager)
	if randf() < 0.2:
		var trait_data = JarlTraitData.new()
		trait_data.display_name = ["Strong", "Genius", "Giant", "Frail"].pick_random()
		baby.genetic_trait = trait_data
		
	# 3. Base Stats (Babies start with potential, but low raw ability)
	# We can simulate "potential" by giving them average stats now that grow, 
	# or just randomizing them like the adults. Let's randomize for now.
	baby.command = randi_range(2, 8)
	baby.stewardship = randi_range(2, 8)
	baby.prowess = randi_range(2, 8)
	baby.learning = randi_range(2, 8)
	
	baby.status = JarlHeirData.HeirStatus.Available
	return baby

static func get_random_viking_name() -> String:
	var gender = "Male" if randf() > 0.2 else "Female" # Mostly male raiders historically
	var list = MALE_NAMES if gender == "Male" else FEMALE_NAMES
	return list.pick_random()
