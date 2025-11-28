# res://autoload/DynastyManager.gd
extends Node

signal jarl_stats_updated(jarl_data: JarlData)
signal year_ended

var current_jarl: JarlData
var current_raid_target: SettlementData
var is_defensive_raid: bool = false
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []
var current_raid_difficulty: int = 1 
var pending_raid_result: Dictionary = {} 

# --- RAID STAGING ---
var outbound_raid_force: Array[WarbandData] = []
var raid_provisions_level: int = 1 
var raid_health_modifier: float = 1.0

const PLAYER_JARL_PATH = "res://data/characters/PlayerJarl.tres"
const PORTRAIT_PARTS_DIR = "res://data/portraits/parts/"

# --- PORTRAIT DATABASE (Dynamic) ---
# Format: { "HEAD": ["head_01", "head_02"], "BODY": ["body_01"] }
var portrait_db: Dictionary = {}

# Colors are still hardcoded for now (Phase 4: Move these to a Palette Resource)
const SKIN_TONES = [
	Color("#f5deb3"), # Wheat
	Color("#e0ac69"), # Tan
	Color("#8d5524")  # Dark
]
const HAIR_COLORS = [
	Color("#e6ea3b"), # Blonde
	Color("#b55239"), # Red
	Color("#2a2a2a")  # Black
]

func _ready() -> void:
	Loggie.set_domain_enabled(LogDomains.DYNASTY, true)
	
	# 1. Build the Database
	_scan_portrait_database()
	
	# 2. Load Data
	_load_player_jarl()
	_load_legacy_upgrades_from_disk()
	
	EventBus.succession_choices_made.connect(_on_succession_choices_made)

# --- DYNAMIC DISCOVERY ---
func _scan_portrait_database() -> void:
	portrait_db.clear()
	
	if not DirAccess.dir_exists_absolute(PORTRAIT_PARTS_DIR):
		Loggie.msg("DynastyManager: Portrait parts directory missing!").domain(LogDomains.DYNASTY).error()
		return

	var dir = DirAccess.open(PORTRAIT_PARTS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# We only care about .tres files (and ignore remapped files in export)
			if file_name.ends_with(".tres"):
				_register_part(file_name)
			
			file_name = dir.get_next()
			
	Loggie.msg("DynastyManager: Portrait DB built. Categories: %s" % str(portrait_db.keys())).domain(LogDomains.DYNASTY).info()

func _register_part(file_name: String) -> void:
	var path = PORTRAIT_PARTS_DIR + file_name
	var resource = load(path) as PortraitPartData
	
	if not resource: return
	
	# Group by Part Type (HEAD, BODY, BEARD, etc.)
	var category = resource.part_type
	if not portrait_db.has(category):
		portrait_db[category] = []
		
	# Store the ID (filename without extension)
	var id = file_name.get_basename()
	portrait_db[category].append(id)

# --- PORTRAIT GENERATION LOGIC ---
func _generate_portrait_config(parent_jarl: JarlData = null) -> Dictionary:
	var config = {}
	
	# 1. Assign Parts from Database
	# We safely pick random parts. If a category is missing, we leave it blank.
	if portrait_db.has("HEAD") and not portrait_db["HEAD"].is_empty():
		config["head_id"] = portrait_db["HEAD"].pick_random()
	else:
		config["head_id"] = "" # Fallback logic in Generator handles empty strings gracefully
		
	if portrait_db.has("BODY") and not portrait_db["BODY"].is_empty():
		config["body_id"] = portrait_db["BODY"].pick_random()
	else:
		config["body_id"] = ""
	
	# 2. Genetics: Skin Tone
	# 70% chance to inherit from parent, 30% mutation
	if parent_jarl and not parent_jarl.portrait_config.is_empty() and randf() < 0.7:
		config["skin_color"] = parent_jarl.portrait_config.get("skin_color", SKIN_TONES.pick_random())
	else:
		config["skin_color"] = SKIN_TONES.pick_random()
		
	# 3. Genetics: Hair Color
	if parent_jarl and not parent_jarl.portrait_config.is_empty() and randf() < 0.6:
		config["hair_color"] = parent_jarl.portrait_config.get("hair_color", HAIR_COLORS.pick_random())
	else:
		config["hair_color"] = HAIR_COLORS.pick_random()
		
	# 4. Primary Clothing Color (Random for now)
	config["primary_color"] = Color(randf(), randf(), randf())
	
	return config

# --- CORE SYSTEMS ---

func _load_legacy_upgrades_from_disk() -> void:
	loaded_legacy_upgrades.clear()
	if not DirAccess.dir_exists_absolute("res://data/legacy/"):
		return

	var dir = DirAccess.open("res://data/legacy/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path = "res://data/legacy/" + file_name
				var upgrade_data = load(path) as LegacyUpgradeData
				if upgrade_data:
					var unique_upgrade = upgrade_data.duplicate()
					if has_purchased_upgrade(unique_upgrade.effect_key):
						unique_upgrade.current_progress = unique_upgrade.required_progress
					loaded_legacy_upgrades.append(unique_upgrade)
			file_name = dir.get_next()

func _load_player_jarl() -> void:
	if ResourceLoader.exists(PLAYER_JARL_PATH):
		current_jarl = load(PLAYER_JARL_PATH)
	else:
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"
		current_jarl.current_authority = 3
		current_jarl.max_authority = 3
		current_jarl.portrait_config = _generate_portrait_config()
		
	jarl_stats_updated.emit(current_jarl)

func reset_dynasty(total_wipe: bool = true) -> void:
	if ResourceLoader.exists(PLAYER_JARL_PATH):
		current_jarl = load(PLAYER_JARL_PATH) as JarlData
	else:
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"
		current_jarl.portrait_config = _generate_portrait_config()

	if total_wipe and current_jarl:
		current_jarl.renown = 0
		current_jarl.purchased_legacy_upgrades.clear()
		current_jarl.conquered_regions.clear()
		current_jarl.allied_regions.clear()
		current_jarl.ancestors.clear()
		current_jarl.heirs.clear()
		current_jarl.legitimacy = 0
		current_jarl.succession_debuff_years_remaining = 0
		current_jarl.current_authority = current_jarl.max_authority
		current_jarl.offensive_wins = 0

	current_raid_target = null
	is_defensive_raid = false
	current_raid_difficulty = 1
	pending_raid_result.clear()
	reset_raid_state()

	_save_jarl_data()
	_load_legacy_upgrades_from_disk()
	jarl_stats_updated.emit(current_jarl)

func get_current_jarl() -> JarlData:
	if not current_jarl:
		_load_player_jarl()
	return current_jarl

# --- RAID LOGISTICS ---

func reset_raid_state() -> void:
	outbound_raid_force.clear()
	raid_provisions_level = 1
	raid_health_modifier = 1.0

func prepare_raid_force(warbands: Array[WarbandData], provisions: int) -> void:
	outbound_raid_force = warbands.duplicate()
	raid_provisions_level = provisions

func calculate_journey_attrition(target_distance: float) -> Dictionary:
	if not current_jarl: return {}
	if target_distance < 0: target_distance = 0.0
	
	var safe_range = current_jarl.get_safe_range()
	var report = {
		"title": "Uneventful Journey",
		"description": "The seas were calm. The fleet arrived intact.",
		"modifier": 1.0
	}
	
	var base_risk = 0.02
	if target_distance > safe_range:
		base_risk = ((target_distance - safe_range) / 100.0) * current_jarl.attrition_per_100px
	
	if raid_provisions_level == 2: base_risk -= 0.15
	base_risk = clampf(base_risk, 0.05, 0.90)
	
	var roll = randf()
	if roll < base_risk:
		report["title"] = "Rough Seas"
		var damage = 0.10
		if roll < (base_risk * 0.5):
			damage = 0.25
			report["description"] = "A terrible storm scattered the fleet!\nSupplies were lost and men are exhausted."
		else:
			report["description"] = "High waves and poor winds delayed the crossing. The men are seasick and tired."
			
		if raid_provisions_level == 2:
			damage *= 0.5
			report["description"] += "\n(Well-Fed: Damage Reduced)"
			
		report["modifier"] = 1.0 - damage
		raid_health_modifier = report["modifier"]
	else:
		if raid_provisions_level == 2:
			report["title"] = "High Morale"
			report["description"] = "Excellent rations kept spirits high. The warriors are eager for battle!"
			report["modifier"] = 1.1
			raid_health_modifier = 1.1
			
	return report

# --- RENOWN & UPGRADES ---

func spend_renown(cost: int) -> bool:
	if not can_spend_renown(cost): return false
	current_jarl.renown -= cost
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func can_spend_renown(amount: int) -> bool:
	if not current_jarl: return false
	return current_jarl.renown >= amount

func award_renown(amount: int) -> void:
	if not current_jarl: return
	current_jarl.award_renown(amount)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)

func can_spend_authority(amount: int) -> bool:
	if not current_jarl: return false
	return current_jarl.current_authority >= amount

func spend_authority(amount: int) -> bool:
	if not can_spend_authority(amount): return false
	current_jarl.current_authority -= amount
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func purchase_legacy_upgrade(upgrade_key: String) -> void:
	if not current_jarl: return
	if not upgrade_key in current_jarl.purchased_legacy_upgrades:
		current_jarl.purchased_legacy_upgrades.append(upgrade_key)
		_save_jarl_data()

func has_purchased_upgrade(upgrade_key: String) -> bool:
	if not current_jarl: return false
	return upgrade_key in current_jarl.purchased_legacy_upgrades

func add_conquered_region(region_path: String) -> void:
	if not current_jarl: return
	if not region_path in current_jarl.conquered_regions:
		current_jarl.conquered_regions.append(region_path)
		_save_jarl_data()

func has_conquered_region(region_path: String) -> bool:
	if not current_jarl: return false
	return region_path in current_jarl.conquered_regions

# --- HEIR MANAGEMENT ---

func get_available_heir_count() -> int:
	if not current_jarl: return 0
	return current_jarl.get_available_heir_count()

func designate_heir(target_heir: JarlHeirData) -> void:
	if not current_jarl or not target_heir: return
	
	if not can_spend_authority(1):
		Loggie.msg("Not enough Authority to designate heir.").domain("DYNASTY").warn()
		return
		
	spend_authority(1)
	for heir in current_jarl.heirs:
		heir.is_designated_heir = false
	target_heir.is_designated_heir = true
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)

func start_heir_expedition(heir: JarlHeirData, expedition_duration: int = 3) -> void:
	if not current_jarl or not heir in current_jarl.heirs: return
	heir.status = JarlHeirData.HeirStatus.OnExpedition
	heir.expedition_years_remaining = expedition_duration
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)

func marry_heir_for_alliance(region_path: String) -> bool:
	if not current_jarl: return false
	var heir_to_marry = current_jarl.get_first_available_heir()
	if not heir_to_marry: return false
	
	heir_to_marry.status = JarlHeirData.HeirStatus.MarriedOff
	if not region_path in current_jarl.allied_regions:
		current_jarl.allied_regions.append(region_path)
	
	current_jarl.legitimacy = min(100, current_jarl.legitimacy + 10)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func is_allied_region(region_path: String) -> bool:
	if not current_jarl: return false
	return region_path in current_jarl.allied_regions

func add_trait_to_heir(heir: JarlHeirData, trait_data: JarlTraitData) -> void:
	if not heir: return
	heir.traits.append(trait_data)

# --- TIME & EVENTS ---

func end_year() -> void:
	if not current_jarl: return
	current_jarl.age_jarl(1)
	
	if _check_for_jarl_death():
		return
	
	current_jarl.reset_authority()
	_process_heir_simulation()
	reset_raid_state()
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	year_ended.emit()

func _process_heir_simulation() -> void:
	var heirs_to_remove: Array[JarlHeirData] = []
	for heir in current_jarl.heirs:
		heir.age += 1
		if heir.status == JarlHeirData.HeirStatus.OnExpedition:
			heir.expedition_years_remaining -= 1
			if heir.expedition_years_remaining <= 0:
				_resolve_expedition(heir)
		
		if heir.age > 50 and randf() < 0.05:
			Loggie.msg("Heir %s died of natural causes." % heir.display_name).domain("DYNASTY").info()
			heirs_to_remove.append(heir)
			
	for dead_heir in heirs_to_remove:
		current_jarl.remove_heir(dead_heir)
		
	_try_birth_event()

func _resolve_expedition(heir: JarlHeirData) -> void:
	var roll = randf()
	if roll > 0.3:
		heir.status = JarlHeirData.HeirStatus.Available
		var renown_gain = randi_range(100, 300)
		award_renown(renown_gain)
	else:
		heir.status = JarlHeirData.HeirStatus.LostAtSea

func _try_birth_event() -> void:
	if current_jarl.heirs.size() >= 6: return
	var base_chance = 0.30
	if current_jarl.age > 50: base_chance -= 0.20
	if current_jarl.age > 60: base_chance = 0.0
	
	if randf() < base_chance:
		_generate_new_baby()

func _generate_new_baby() -> void:
	var baby = JarlHeirData.new()
	baby.age = 0
	baby.gender = "Male" if randf() > 0.5 else "Female"
	
	var male_names = ["Erik", "Olaf", "Knut", "Sven", "Torstein", "Leif", "Ragnar", "Bjorn"]
	var female_names = ["Astrid", "Freya", "Ingrid", "Sigrid", "Helga", "Ylva", "Lagertha", "Gunnhild"]
	baby.display_name = male_names.pick_random() if baby.gender == "Male" else female_names.pick_random()
		
	if randf() < 0.2:
		var trait_data = JarlTraitData.new()
		trait_data.display_name = ["Strong", "Genius", "Giant", "Frail"].pick_random()
		baby.genetic_trait = trait_data
	
	baby.portrait_config = _generate_portrait_config(current_jarl)
	
	current_jarl.heirs.append(baby)
	Loggie.msg("A new child, %s, was born to the Dynasty!" % baby.display_name).domain("DYNASTY").info()

func set_current_raid_target(data: SettlementData) -> void:
	current_raid_target = data

func get_current_raid_target() -> SettlementData:
	var target = current_raid_target
	current_raid_target = null
	return target

func _save_jarl_data() -> void:
	if not current_jarl: return
	if current_jarl.resource_path.is_empty():
		current_jarl.resource_path = PLAYER_JARL_PATH
	ResourceSaver.save(current_jarl, current_jarl.resource_path)

func debug_kill_jarl() -> void:
	_trigger_succession()

func _check_for_jarl_death() -> bool:
	var jarl = get_current_jarl()
	var death_chance = 0.0
	if jarl.age > 80: death_chance = 0.5
	elif jarl.age > 65: death_chance = 0.25
	elif jarl.age > 50: death_chance = 0.1
	
	if randf() < death_chance:
		Loggie.msg("The Jarl has died at age %d!" % jarl.age).domain("DYNASTY").warn()
		_trigger_succession()
		return true
	return false

func _trigger_succession() -> void:
	var old_jarl = current_jarl
	var heir = null
	for h in current_jarl.heirs:
		if h.is_designated_heir and h.status == JarlHeirData.HeirStatus.Available:
			heir = h
			break
	if not heir:
		heir = current_jarl.get_first_available_heir()
	
	if not heir:
		Loggie.msg("GAME OVER: The Jarl died with no available heir!").domain("DYNASTY").error()
		return
	
	var new_jarl = _promote_heir_to_jarl(heir, old_jarl)
	var ancestor_entry = {
		"name": old_jarl.display_name,
		"portrait": old_jarl.portrait,
		"final_renown": old_jarl.renown,
		"death_reason": "Died of old age"
	}
	new_jarl.ancestors.append(ancestor_entry)
	new_jarl.heirs.erase(heir) 
	current_jarl = new_jarl
	
	var succession_event_data = EventData.new() 
	succession_event_data.event_id = "succession_crisis"
	EventManager._trigger_event(succession_event_data)

func _promote_heir_to_jarl(heir: JarlHeirData, predecessor: JarlData) -> JarlData:
	var new_jarl = JarlData.new()
	new_jarl.display_name = heir.display_name
	new_jarl.age = heir.age
	new_jarl.gender = heir.gender
	new_jarl.portrait = heir.portrait
	new_jarl.command = heir.command
	new_jarl.stewardship = heir.stewardship
	new_jarl.learning = heir.learning
	new_jarl.prowess = heir.prowess
	new_jarl.traits = heir.traits
	new_jarl.ancestors = predecessor.ancestors.duplicate()
	new_jarl.heirs = predecessor.heirs.duplicate()
	
	new_jarl.portrait_config = heir.portrait_config.duplicate()
	
	var new_legit = int(predecessor.legitimacy * 0.8)
	if heir.is_designated_heir: new_legit += 20
	new_legit = max(new_legit, minimum_inherited_legitimacy)
	
	new_jarl.legitimacy = new_legit
	new_jarl.succession_debuff_years_remaining = 3 
	return new_jarl

func _on_succession_choices_made(renown_choice: String, gold_choice: String) -> void:
	if renown_choice == "refuse":
		var setback_applied = false
		for upgrade in loaded_legacy_upgrades:
			if not upgrade.is_purchased and upgrade.current_progress > 0:
				upgrade.current_progress = max(0, upgrade.current_progress - 2)
				setback_applied = true
				break
		if setback_applied:
			Loggie.msg("A legacy project has lost progress due to refused renown tax.").domain("DYNASTY").info()
	
	if gold_choice == "refuse":
		if SettlementManager.current_settlement:
			SettlementManager.current_settlement.has_stability_debuff = true
			Loggie.msg("Settlement instability debuff applied due to refused gold tax.").domain("DYNASTY").info()
	
	EventBus.event_system_finished.emit()

func process_defensive_loss() -> Dictionary:
	if not current_jarl: return {}
	var aftermath_report = {
		"summary_text": "",
		"jarl_died": false,
		"heir_died": null
	}
	
	var renown_loss = randi_range(50, 150)
	current_jarl.renown = max(0, current_jarl.renown - renown_loss)
	
	var material_losses = EconomyManager.apply_raid_damages()
	
	if current_jarl.heirs.size() > 0 and randf() < 0.15:
		var victim_index = randi() % current_jarl.heirs.size()
		var victim = current_jarl.heirs[victim_index]
		victim.status = JarlHeirData.HeirStatus.Deceased
		aftermath_report["heir_died"] = victim.display_name
		current_jarl.remove_heir(victim)
		
	var death_chance = 0.10
	if current_jarl.age > 60: death_chance += 0.10
	
	if randf() < death_chance:
		aftermath_report["jarl_died"] = true
		_trigger_succession()
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	
	var text = "Defeat! The settlement has been sacked.\n\n"
	text += "[color=salmon]Resources Lost:[/color]\n"
	text += "- %d Gold\n" % material_losses.get("gold_lost", 0)
	text += "- %d Renown\n" % renown_loss
	
	aftermath_report["summary_text"] = text
	return aftermath_report

func find_heir_by_name(h_name: String) -> JarlHeirData:
	if not current_jarl: return null
	for heir in current_jarl.heirs:
		if heir.display_name == h_name: return heir
	return null

func kill_heir_by_name(h_name: String, reason: String) -> void:
	var heir = find_heir_by_name(h_name)
	if heir:
		heir.status = JarlHeirData.HeirStatus.Deceased
		current_jarl.remove_heir(heir)
		Loggie.msg("The Heir %s has fallen! Reason: %s" % [h_name, reason]).domain("DYNASTY").error()
		jarl_stats_updated.emit(current_jarl)
		_save_jarl_data()
