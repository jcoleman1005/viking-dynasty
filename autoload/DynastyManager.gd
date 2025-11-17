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

const PLAYER_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_player_jarl()
	_load_legacy_upgrades_from_disk()
	EventBus.succession_choices_made.connect(_on_succession_choices_made)

func _load_legacy_upgrades_from_disk() -> void:
	loaded_legacy_upgrades.clear()
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
	
	Loggie.msg("Loaded %d legacy upgrades." % loaded_legacy_upgrades.size()).domain("DYNASTY").info()

func _load_player_jarl() -> void:
	if ResourceLoader.exists(PLAYER_JARL_PATH):
		current_jarl = load(PLAYER_JARL_PATH)
		Loggie.msg("PlayerJarl.tres loaded successfully.").domain("DYNASTY").info()
	else:
		Loggie.msg("Failed to load Jarl data from %s. File not found!" % PLAYER_JARL_PATH).domain("DYNASTY").error()
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"
		current_jarl.current_authority = 3
		current_jarl.max_authority = 3
		
	jarl_stats_updated.emit(current_jarl)

func reset_dynasty(total_wipe: bool = true) -> void:
	"""Resets the dynasty state for a new campaign.
	If total_wipe is true, clears renown, upgrades, conquered regions, etc.
	"""
	# Reload base Jarl template from disk
	if ResourceLoader.exists(PLAYER_JARL_PATH):
		current_jarl = load(PLAYER_JARL_PATH) as JarlData
	else:
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"

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

	# Reset runtime-only state
	current_raid_target = null
	is_defensive_raid = false
	current_raid_difficulty = 1
	pending_raid_result.clear()

	# Persist the wiped Jarl
	_save_jarl_data()
	
	# Reload legacy upgrades from clean Jarl state
	_load_legacy_upgrades_from_disk()
	
	jarl_stats_updated.emit(current_jarl)
	Loggie.msg("DynastyManager: FULL CAMPAIGN WIPE applied. Dynasty reset to defaults.").domain("DYNASTY").warn()

func get_current_jarl() -> JarlData:
	if not current_jarl:
		_load_player_jarl()
	return current_jarl

# --- AUTHORITY & RENOWN ---

func can_spend_authority(cost: int) -> bool:
	if not current_jarl: return false
	return current_jarl.can_take_action(cost)

func spend_authority(cost: int) -> bool:
	if not current_jarl: return false
		
	if current_jarl.spend_authority(cost):
		_save_jarl_data()
		jarl_stats_updated.emit(current_jarl)
		return true
	
	Loggie.msg("Failed to spend %d authority. %d remaining." % [cost, current_jarl.current_authority]).domain("DYNASTY").warn()
	return false

func can_spend_renown(cost: int) -> bool:
	if not current_jarl: return false
	return current_jarl.renown >= cost

func spend_renown(cost: int) -> bool:
	if not can_spend_renown(cost):
		Loggie.msg("Failed to spend %d renown. %d available." % [cost, current_jarl.renown]).domain("DYNASTY").warn()
		return false
	
	current_jarl.renown -= cost
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func award_renown(amount: int) -> void:
	if not current_jarl: return
	
	current_jarl.award_renown(amount)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	Loggie.msg("Awarded %d renown. Total: %d" % [amount, current_jarl.renown]).domain("DYNASTY").info()

# --- LEGACY & UNIFIER ---

func purchase_legacy_upgrade(upgrade_key: String) -> void:
	if not current_jarl: return
	if not upgrade_key in current_jarl.purchased_legacy_upgrades:
		current_jarl.purchased_legacy_upgrades.append(upgrade_key)
		_save_jarl_data()
		Loggie.msg("Legacy upgrade '%s' purchased." % upgrade_key).domain("DYNASTY").info()

func has_purchased_upgrade(upgrade_key: String) -> bool:
	if not current_jarl: return false
	return upgrade_key in current_jarl.purchased_legacy_upgrades

func add_conquered_region(region_path: String) -> void:
	if not current_jarl: return
	if not region_path in current_jarl.conquered_regions:
		current_jarl.conquered_regions.append(region_path)
		_save_jarl_data()
		Loggie.msg("Region '%s' conquered." % region_path).domain("DYNASTY").info()

func has_conquered_region(region_path: String) -> bool:
	if not current_jarl: return false
	return region_path in current_jarl.conquered_regions

# --- PROGENITOR PILLAR (HEIRS) ---

func get_available_heir_count() -> int:
	if not current_jarl: return 0
	return current_jarl.get_available_heir_count()

func designate_heir(target_heir: JarlHeirData) -> void:
	if not current_jarl or not target_heir: return
	
	var cost = 1
	if not can_spend_authority(cost):
		Loggie.msg("Not enough Authority to designate heir.").domain("DYNASTY").warn()
		return
		
	spend_authority(cost)
	for heir in current_jarl.heirs:
		heir.is_designated_heir = false
	target_heir.is_designated_heir = true
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	Loggie.msg("%s is now the designated heir." % target_heir.display_name).domain("DYNASTY").info()

func start_heir_expedition(heir: JarlHeirData, expedition_duration: int = 3) -> void:
	if not current_jarl or not heir in current_jarl.heirs:
		Loggie.msg("Tried to send an invalid heir on expedition.").domain("DYNASTY").error()
		return
	
	heir.status = JarlHeirData.HeirStatus.OnExpedition
	heir.expedition_years_remaining = expedition_duration
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	Loggie.msg("Heir %s sent on expedition for %d years." % [heir.display_name, expedition_duration]).domain("DYNASTY").info()

func marry_heir_for_alliance(region_path: String) -> bool:
	if not current_jarl: return false
		
	var heir_to_marry = current_jarl.get_first_available_heir()
	if not heir_to_marry:
		Loggie.msg("Marriage failed. No available heir.").domain("DYNASTY").warn()
		return false
	
	heir_to_marry.status = JarlHeirData.HeirStatus.MarriedOff
	if not region_path in current_jarl.allied_regions:
		current_jarl.allied_regions.append(region_path)
	
	current_jarl.legitimacy = min(100, current_jarl.legitimacy + 10)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	Loggie.msg("Heir %s married off to form alliance with %s" % [heir_to_marry.display_name, region_path]).domain("DYNASTY").info()
	return true

func is_allied_region(region_path: String) -> bool:
	if not current_jarl: return false
	return region_path in current_jarl.allied_regions

func add_trait_to_heir(heir: JarlHeirData, trait_data: JarlTraitData) -> void:
	if not heir: return
	heir.traits.append(trait_data)
	Loggie.msg("Added trait '%s' to heir '%s'." % [trait_data.display_name, heir.display_name]).domain("DYNASTY").info()

# --- END OF YEAR LOGIC LOOP ---

func end_year() -> void:
	if not current_jarl:
		Loggie.msg("Cannot end year, current Jarl is null.").domain("DYNASTY").error()
		return
	
	current_jarl.age_jarl(1)
	
	var jarl_died = _check_for_jarl_death()
	if jarl_died:
		return
	
	current_jarl.reset_authority()
	_process_heir_simulation()
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	
	Loggie.msg("Year ended. Jarl is now %d." % current_jarl.age).domain("DYNASTY").info()
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
		Loggie.msg("Heir %s returned safely with %d Renown!" % [heir.display_name, renown_gain]).domain("DYNASTY").info()
	else:
		heir.status = JarlHeirData.HeirStatus.LostAtSea
		Loggie.msg("Tragic news! Heir %s was lost at sea." % heir.display_name).domain("DYNASTY").info()

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
	
	if baby.gender == "Male":
		baby.display_name = male_names.pick_random()
	else:
		baby.display_name = female_names.pick_random()
		
	if randf() < 0.2:
		var trait_data = JarlTraitData.new()
		trait_data.display_name = ["Strong", "Genius", "Giant", "Frail"].pick_random()
		baby.genetic_trait = trait_data
	
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
		
	var error = ResourceSaver.save(current_jarl, current_jarl.resource_path)
	if error != OK:
		Loggie.msg("Failed to save Jarl data to %s. Error: %s" % [current_jarl.resource_path, error]).domain("DYNASTY").error()

func debug_kill_jarl() -> void:
	Loggie.msg("debug_kill_jarl() called. Forcing succession...").domain("DYNASTY").debug()
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
	
# --- NEW: Defensive Loss Orchestration ---
func process_defensive_loss() -> Dictionary:
	"""
	Orchestrates the consequences of losing a defensive mission.
	Handles Character death, Renown loss, and calls SettlementManager for resources.
	Returns a summary Dictionary.
	"""
	if not current_jarl: return {}
	
	var aftermath_report = {
		"summary_text": "",
		"jarl_died": false,
		"heir_died": null # Name of heir if died
	}
	
	# 1. Renown Loss (Humiliation)
	var renown_loss = randi_range(50, 150)
	current_jarl.renown = max(0, current_jarl.renown - renown_loss)
	
	# 2. Call Settlement Manager for Material Loss
	var material_losses = SettlementManager.apply_raid_damages()
	
	# 3. Risk of Heir Death (15% chance if heirs exist)
	if current_jarl.heirs.size() > 0 and randf() < 0.15:
		var victim_index = randi() % current_jarl.heirs.size()
		var victim = current_jarl.heirs[victim_index]
		victim.status = JarlHeirData.HeirStatus.Deceased
		aftermath_report["heir_died"] = victim.display_name
		current_jarl.remove_heir(victim)
		Loggie.msg("Heir %s was killed during the sacking!" % victim.display_name).domain("DYNASTY").warn()
		
	# 4. Risk of Jarl Death (10% chance, higher if old)
	var death_chance = 0.10
	if current_jarl.age > 60: death_chance += 0.10
	
	if randf() < death_chance:
		aftermath_report["jarl_died"] = true
		Loggie.msg("The Jarl fell defending the settlement!").domain("DYNASTY").warn()
		# We trigger succession logic immediately
		_trigger_succession()
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	
	# 5. Build Summary Text
	var text = "Defeat! The settlement has been sacked.\n\n"
	text += "[color=salmon]Resources Lost:[/color]\n"
	text += "- %d Gold\n" % material_losses.get("gold_lost", 0)
	text += "- %d Wood\n" % material_losses.get("wood_lost", 0)
	text += "- %d Renown\n" % renown_loss
	
	if material_losses.get("buildings_damaged", 0) > 0:
		text += "- %d Construction sites damaged\n" % material_losses["buildings_damaged"]
	if material_losses.get("buildings_destroyed", 0) > 0:
		text += "- %d Blueprints destroyed completely\n" % material_losses["buildings_destroyed"]
		
	text += "\n[color=red]Casualties:[/color]\n"
	if aftermath_report["jarl_died"]:
		text += "- THE JARL HAS FALLEN!\n"
	if aftermath_report["heir_died"]:
		text += "- Heir %s was killed.\n" % aftermath_report["heir_died"]
	if not aftermath_report["jarl_died"] and not aftermath_report["heir_died"]:
		text += "The Dynasty survived physically, if not in reputation."
		
	aftermath_report["summary_text"] = text
	return aftermath_report
