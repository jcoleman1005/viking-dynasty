# res://autoload/DynastyManager.gd
extends Node

signal jarl_stats_updated(jarl_data: JarlData)
signal year_ended

var current_jarl: JarlData
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []

var active_year_modifiers: Dictionary = {}
var winter_upkeep_report: Dictionary = {} 
var pending_dispute_card: DisputeEventData = null
var winter_consumption_report: Dictionary = {}
var winter_crisis_active: bool = false

# --- SEASONAL MUSTER ---
# Stores UnitData resources that have promised to join in spring
var pending_seasonal_recruits: Array[UnitData] = []

# --- CONSTANTS ---
const USER_DYNASTY_PATH = "user://savegame_dynasty.tres"
const DEFAULT_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_game_data()
	EventBus.succession_choices_made.connect(_on_succession_choices_made)

func _load_game_data() -> void:
	# 1. Legacy Upgrades (Always static data)
	_load_legacy_upgrades_from_disk()
	
	# 2. Jarl Data (Dynamic)
	if ResourceLoader.exists(USER_DYNASTY_PATH):
		current_jarl = load(USER_DYNASTY_PATH)
		Loggie.msg("DynastyManager: Loaded Jarl from User Save.").domain(LogDomains.DYNASTY).info()
	elif ResourceLoader.exists(DEFAULT_JARL_PATH):
		# This is technically a "New Game" state using the default template
		current_jarl = load(DEFAULT_JARL_PATH).duplicate(true)
		Loggie.msg("DynastyManager: Loaded Default Template Jarl.").domain(LogDomains.DYNASTY).info()
	else:
		Loggie.msg("DynastyManager: No Jarl data found. Generating fallback.").domain(LogDomains.DYNASTY).warn()
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"
		
	jarl_stats_updated.emit(current_jarl)

func start_new_campaign() -> void:
	"""
	Generates a completely fresh dynasty and saves it to user://.
	Wipes previous campaign data.
	"""
	Loggie.msg("DynastyManager: Starting NEW CAMPAIGN...").domain(LogDomains.DYNASTY).warn()
	
	# 1. Generate Fresh Data
	current_jarl = DynastyGenerator.generate_random_dynasty()
	current_jarl.resource_path = USER_DYNASTY_PATH 
	
	# 2. Reset Runtime State
	# REFACTOR: Raid state now handled by RaidManager
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

# --- END OF YEAR LOOP ---

func end_year() -> void:
	if not current_jarl: return
	current_jarl.age_jarl(1)
	var jarl_died = _check_for_jarl_death()
	if jarl_died: return
	current_jarl.reset_authority()
	_process_heir_simulation()
	
	# REFACTOR: Reset raid state via the new manager
	RaidManager.reset_raid_state()
	
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
		base_chance += 0.50 # Huge boost
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
		current_jarl.resource_path = USER_DYNASTY_PATH # Force user path if empty
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

# --- WINTER & RECRUITMENT LOGIC (Pending Move in Phases 2 & 3) ---

func start_winter_phase() -> void:
	if current_jarl: current_jarl.calculate_hall_actions()
	
	var decay = 0.2
	if WinterManager.current_severity == WinterManager.WinterSeverity.HARSH: decay = 0.4
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.fleet_readiness = max(0.0, SettlementManager.current_settlement.fleet_readiness - decay)
	
	_calculate_winter_needs()
	EventBus.scene_change_requested.emit("winter_court")

func _calculate_winter_needs() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	var demand_report = WinterManager.calculate_winter_demand(settlement)
	var food_cost = demand_report["food_demand"]
	var wood_cost = demand_report["wood_demand"]
	var food_stock = settlement.treasury.get("food", 0)
	var wood_stock = settlement.treasury.get("wood", 0)
	var food_deficit = max(0, food_cost - food_stock)
	var wood_deficit = max(0, wood_cost - wood_stock)
	
	winter_consumption_report = {
		"severity": demand_report["severity_name"],
		"multiplier": demand_report["multiplier"],
		"food_cost": food_cost,
		"wood_cost": wood_cost,
		"food_deficit": food_deficit,
		"wood_deficit": wood_deficit
	}
	
	if food_deficit > 0 or wood_deficit > 0:
		winter_crisis_active = true
	else:
		winter_crisis_active = false
		_apply_winter_consumption()

func _apply_winter_consumption() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	settlement.treasury["food"] = max(0, settlement.treasury.get("food", 0) - winter_consumption_report["food_cost"])
	settlement.treasury["wood"] = max(0, settlement.treasury.get("wood", 0) - winter_consumption_report["wood_cost"])
	EventBus.treasury_updated.emit(settlement.treasury)

func resolve_crisis_with_gold() -> bool:
	var total_gold_cost = (winter_consumption_report["food_deficit"] * 5) + (winter_consumption_report["wood_deficit"] * 5)
	if SettlementManager.attempt_purchase({"gold": total_gold_cost}):
		winter_crisis_active = false
		_apply_winter_consumption()
		return true
	return false

func resolve_crisis_with_sacrifice(sacrifice_type: String) -> bool:
	if not perform_hall_action(1): return false
	var settlement = SettlementManager.current_settlement
	match sacrifice_type:
		"starve_peasants":
			var deaths = max(1, int(winter_consumption_report["food_deficit"] / 5))
			settlement.population_peasants = max(0, settlement.population_peasants - deaths)
		"disband_warband":
			if not settlement.warbands.is_empty(): settlement.warbands.pop_back()
		"burn_ships":
			settlement.fleet_readiness = 0.0
	winter_crisis_active = false
	_apply_winter_consumption()
	return true

func perform_hall_action(cost: int = 1) -> bool:
	if not current_jarl or current_jarl.current_hall_actions < cost: return false
	current_jarl.current_hall_actions -= cost
	jarl_stats_updated.emit(current_jarl)
	return true

func end_winter_phase() -> void:
	if not current_jarl: return
	
	# 1. Process Aging
	current_jarl.age_jarl(1)
	if _check_for_jarl_death(): return 
	
	# 2. Reset Actions
	current_jarl.reset_authority()
	active_year_modifiers.clear()
	
	# 3. Calculate Economy
	var payout = EconomyManager.calculate_payout() 
	SettlementManager.deposit_resources(payout)
	
	# --- NEW: Spawn the mustered troops ---
	commit_seasonal_recruits_to_settlement()
	# --------------------------------------
	
	# 4. Save & Transition
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	EventBus.scene_change_requested.emit("settlement")

func apply_year_modifier(key: String) -> void:
	if key.is_empty(): return
	active_year_modifiers[key] = true

func draw_dispute_card() -> DisputeEventData:
	var card = DisputeEventData.new()
	card.title = "Stolen Cattle"
	card.description = "A Bondi accuses a Huscarl of theft."
	card.gold_cost = 50
	card.renown_cost = 10
	card.penalty_modifier_key = "angry_bondi"
	card.penalty_description = "Recruitment halted."
	return card

func queue_seasonal_recruit(unit_data: UnitData, count: int) -> void:
	for i in range(count):
		pending_seasonal_recruits.append(unit_data)

func commit_seasonal_recruits_to_settlement() -> void:
	"""
	Called when Winter Ends. 
	Converts pending individual recruits into consolidated Warbands.
	"""
	if pending_seasonal_recruits.is_empty(): return
	if not SettlementManager.current_settlement: return
	
	var new_warbands: Array[WarbandData] = []
	var current_batch_wb: WarbandData = null
	
	# Iterate through every individual soldier promised
	for u_data in pending_seasonal_recruits:
		
		# 1. Do we need a new Warband?
		# (If we don't have one, or the current one is full, or the unit type doesn't match)
		if current_batch_wb == null or \
		   current_batch_wb.current_manpower >= WarbandData.MAX_MANPOWER or \
		   current_batch_wb.unit_type != u_data:
			
			# Create new Squad Container
			current_batch_wb = WarbandData.new(u_data)
			current_batch_wb.is_seasonal = true
			current_batch_wb.current_manpower = 0 # Start empty, add 1 below
			current_batch_wb.custom_name = "Drengir (%s)" % _generate_oath_name()
			current_batch_wb.add_history("Swore the oath at Yule")
			
			SettlementManager.current_settlement.warbands.append(current_batch_wb)
			new_warbands.append(current_batch_wb)
		
		# 2. Add the man to the current squad
		current_batch_wb.current_manpower += 1
		
	Loggie.msg("Spring Arrival: %d men organized into %d Warbands." % [pending_seasonal_recruits.size(), new_warbands.size()]).domain(LogDomains.DYNASTY).info()
	pending_seasonal_recruits.clear()

func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
	return "The %s" % names.pick_random()
