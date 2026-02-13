class_name PatronymicGenerator
extends RefCounted

## Utility for generating names and patronymic lineages for households.

static func generate_given_name() -> String:
	# Use the existing name pools from DynastyGenerator
	var names = DynastyGenerator.MALE_NAMES + DynastyGenerator.FEMALE_NAMES
	return names.pick_random()

static func generate_patronymic(predecessor_name: String, generation: int) -> String:
	if generation == 1:
		return "Founder"
	
	# Default to 'son' suffix for Phase 2.5
	return predecessor_name + "son"

static func create_founder_head() -> HouseholdHead:
	var head = HouseholdHead.new()
	head.given_name = generate_given_name()
	head.patronymic = "Founder"
	head.generation = 1
	head.age = randi_range(25, 55)
	head.alive = true
	
	# Add chance for head trait (20%)
	if randf() < 0.20:
		head.head_trait = _roll_random_head_trait()
		
	# FIX: Proper initialization of typed array
	head.ancestors.clear()
	head.ancestors.append(head.given_name)
	return head

static func create_successor_head(predecessor: HouseholdHead) -> HouseholdHead:
	var head = HouseholdHead.new()
	head.given_name = generate_given_name()
	head.patronymic = generate_patronymic(predecessor.given_name, predecessor.generation + 1)
	head.generation = predecessor.generation + 1
	head.age = randi_range(18, 40)
	head.alive = true
	
	# Add chance for head trait (Inherited or new)
	if randf() < 0.20:
		head.head_trait = _roll_random_head_trait()
	
	# FIX: Use assign() to copy contents into the typed array correctly
	head.ancestors.assign(predecessor.ancestors)
	head.ancestors.append(head.given_name)
	return head

static func _roll_random_head_trait() -> JarlTraitData:
	var trait_data = JarlTraitData.new()
	var types = [
		{"name": "Mason Blood", "desc": "Ancestral builders. +15% Build speed."},
		{"name": "Sea-Reaver", "desc": "Fearless raiders. +10% Raid power."},
		{"name": "Farmer's Hand", "desc": "Born to the soil. +10% Harvest yield."}
	]
	var choice = types.pick_random()
	trait_data.display_name = choice.name
	trait_data.description = choice.desc
	return trait_data
