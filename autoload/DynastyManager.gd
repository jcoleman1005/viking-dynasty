# res://autoload/DynastyManager.gd
extends Node

signal jarl_stats_updated(jarl_data: JarlData)
signal year_ended

var current_jarl: JarlData
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []

var active_year_modifiers: Dictionary = {}


# --- CONSTANTS ---
const USER_DYNASTY_PATH = "user://savegame_dynasty.tres"
const DEFAULT_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_game_data()
	EventBus.succession_choices_made.connect(_on_succession_choices_made)

func _load_game_data() -> void:
	# 1. Legacy Upgrades
	_load_legacy_upgrades_from_disk()
	
	# 2. Jarl Data
	if ResourceLoader.exists(USER_DYNASTY_PATH):
		current_jarl = load(USER_DYNASTY_PATH)
		Loggie.msg("DynastyManager: Loaded Jarl from User Save.").domain(LogDomains.DYNASTY).info()
	elif ResourceLoader.exists(DEFAULT_JARL_PATH):
		current_jarl = load(DEFAULT_JARL_PATH).duplicate(true)
		Loggie.msg("DynastyManager: Loaded Default Template Jarl.").domain(LogDomains.DYNASTY).info()
	else:
		Loggie.msg("DynastyManager: No Jarl data found. Generating fallback.").domain(LogDomains.DYNASTY).warn()
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"
		
	jarl_stats_updated.emit(current_jarl)

func start_new_campaign() -> void:
	Loggie.msg("DynastyManager: Starting NEW CAMPAIGN...").domain(LogDomains.DYNASTY).warn()
	
	# 1. Generate Fresh Data
	current_jarl = DynastyGenerator.generate_random_dynasty()
	current_jarl.resource_path = USER_DYNASTY_PATH 
	
	# 2. Reset Runtime State
	RaidManager.reset_raid_state()
	active_year_modifiers.clear()
	
	# 3. Reset Legacy Progress
	_load_legacy_upgrades_from_disk() 
	
	# 4. Save immediately
	_save_jarl_data()
	
	jarl_stats_updated.emit(current_jarl)

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

func get_current_jarl() -> JarlData:
	if not current_jarl:
		_load_game_data()
	return current_jarl

# --- AUTHORITY & LEGACY LOGIC ---

func can_spend_authority(cost: int) -> bool:
	if not current_jarl: return false
	return current_jarl.can_take_action(cost)

func spend_authority(cost: int) -> bool:
	if not current_jarl: return false
	if current_jarl.spend_authority(cost):
		_save_jarl_data()
		jarl_stats_updated.emit(current_jarl)
		return true
	return false

func can_spend_renown(cost: int) -> bool:
	if not current_jarl: return false
	return current_jarl.renown >= cost

func spend_renown(cost: int) -> bool:
	if not can_spend_renown(cost): return false
	current_jarl.renown -= cost
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func award_renown(amount: int) -> void:
	if not current_jarl: return
	current_jarl.award_renown(amount)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)

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
	if not can_spend_authority(1): return
		
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
		jarl_stats_updated.emit(current_jarl)
		_save_jarl_data()

# --- WINTER CYCLE ORCHESTRATION ---

func start_winter_cycle() -> void:
	"""
	The entry point for the End Year process.
	Calculates Hall Actions based on stats, then starts Winter.
	"""
	if not current_jarl: return
	
	# 1. Calculate Action Points for the Court
	current_jarl.calculate_hall_actions()
	Loggie.msg("Winter Cycle Started. Hall Actions: %d" % current_jarl.current_hall_actions).domain(LogDomains.DYNASTY).info()
	
	# 2. Reset Raid State
	RaidManager.reset_raid_state()
	
	# 3. Hand off to WinterManager
	WinterManager.start_winter_phase()

func end_winter_cycle_complete() -> void:
	"""
	Called by WinterManager when the winter UI phase is finished.
	Completes the year transition (Spring).
	"""
	if not current_jarl: return
	
	Loggie.msg("Winter Ended. Advancing to Spring...").domain(LogDomains.DYNASTY).info()
	
	# 1. Process Aging (Jarl + Heirs)
	current_jarl.age_jarl(1)
	_process_heir_simulation()
	
	# 2. Check Death
	if _check_for_jarl_death(): return 
	
	# 3. Reset Actions (For the new year)
	current_jarl.reset_authority()
	active_year_modifiers.clear()
	
	# 4. Calculate Economy
	var payout = EconomyManager.calculate_payout() 
	SettlementManager.deposit_resources(payout)
	
	# 5. Spawn Seasonal Recruits (Now via SettlementManager)
	SettlementManager.commit_seasonal_recruits()
	
	# 6. Save & Transition
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	
	Loggie.msg("Year ended. Jarl is now %d." % current_jarl.age).domain("DYNASTY").info()
	year_ended.emit()
	EventBus.scene_change_requested.emit("settlement")

# --- JARL SIMULATION & DEATH ---

func _process_heir_simulation() -> void:
	var heirs_to_remove: Array[JarlHeirData] = []
	for heir in current_jarl.heirs:
		heir.age += 1
		if heir.status == JarlHeirData.HeirStatus.OnExpedition:
			heir.expedition_years_remaining -= 1
			if heir.expedition_years_remaining <= 0:
				_resolve_expedition(heir)
		if heir.age > 50 and randf() < 0.05: 
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
	
	if active_year_modifiers.has("BLOT_FREYR"):
		base_chance += 0.50 
		Loggie.msg("Freyr's Blessing is active! Birth chance increased.").domain(LogDomains.DYNASTY).info()
	
	if current_jarl.age > 50: base_chance -= 0.20
	if current_jarl.age > 60: base_chance = 0.0
	
	if randf() < base_chance:
		_generate_new_baby()

func _generate_new_baby() -> void:
	var baby = DynastyGenerator.generate_newborn()
	current_jarl.heirs.append(baby)
	Loggie.msg("A new child, %s, was born to the Dynasty!" % baby.display_name).domain("DYNASTY").info()
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)

func _save_jarl_data() -> void:
	if not current_jarl: return
	if current_jarl.resource_path.is_empty():
		current_jarl.resource_path = USER_DYNASTY_PATH 
	var error = ResourceSaver.save(current_jarl, current_jarl.resource_path)
	if error != OK:
		Loggie.msg("Failed to save Jarl data. Error: %s" % error).domain("DYNASTY").error()

func debug_kill_jarl() -> void:
	_trigger_succession()

func _check_for_jarl_death() -> bool:
	var jarl = get_current_jarl()
	var death_chance = 0.0
	if jarl.age > 80: death_chance = 0.5
	elif jarl.age > 65: death_chance = 0.25
	elif jarl.age > 50: death_chance = 0.1
	
	if randf() < death_chance:
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
	if not heir: heir = current_jarl.get_first_available_heir()
	
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
	new_jarl.take_over_path(USER_DYNASTY_PATH)
	return new_jarl

func _on_succession_choices_made(renown_choice: String, gold_choice: String) -> void:
	if renown_choice == "refuse":
		for upgrade in loaded_legacy_upgrades:
			if not upgrade.is_purchased and upgrade.current_progress > 0:
				upgrade.current_progress = max(0, upgrade.current_progress - 2)
				break
	if gold_choice == "refuse":
		if SettlementManager.current_settlement:
			SettlementManager.current_settlement.has_stability_debuff = true
	EventBus.event_system_finished.emit()

func perform_hall_action(cost: int = 1) -> bool:
	if not current_jarl or current_jarl.current_hall_actions < cost: return false
	current_jarl.current_hall_actions -= cost
	jarl_stats_updated.emit(current_jarl)
	return true

func apply_year_modifier(key: String) -> void:
	if key.is_empty(): return
	active_year_modifiers[key] = true



func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
	return "The %s" % names.pick_random()
