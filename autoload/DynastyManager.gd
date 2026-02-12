extends Node

signal jarl_stats_updated(jarl_data: JarlData)
signal year_ended

var current_jarl: JarlData
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []

var active_year_modifiers: Dictionary[String, float] = {
	"mod_unit_damage": 0.0,
	"mod_raid_xp": 0.0,
	"mod_pop_growth": 0.0,
	"mod_heir_birth_chance": 0.0,
	"mod_harvest_yield": 0.0
}
var current_year: int = 867 
# --- SEASON STATE ---
enum Season { SPRING, SUMMER, AUTUMN, WINTER }
var current_season: Season = Season.SPRING

# --- CONSTANTS ---
const USER_DYNASTY_PATH = "user://savegame_dynasty.tres"
const DEFAULT_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_game_data()
	EventBus.succession_choices_made.connect(_on_succession_choices_made)
	EventBus.advance_season_requested.connect(advance_season)

# --- SEASON LOGIC ---

func advance_season() -> void:
	match current_season:
		Season.SPRING:
			_transition_to_season(Season.SUMMER)
		Season.SUMMER:
			_transition_to_season(Season.AUTUMN)
		Season.AUTUMN:
			_transition_to_season(Season.WINTER)
		Season.WINTER:
			end_winter_cycle_complete()

## The Core Orchestrator for changing seasons.
## Now handles the "Data Handshake" for the UI by bundling context.
func _transition_to_season(new_season: Season) -> void:
	current_season = new_season
	var names = ["Spring", "Summer", "Autumn", "Winter"]
	var s_name = names[current_season]
	
	Loggie.msg("Season Advancing to: %s..." % s_name).domain(LogDomains.DYNASTY).info()
	
	# --- ORCHESTRATION: The Game Loop ---
	
	# 1. Labor (Construction)
	if SettlementManager.has_method("process_construction_labor"):
		SettlementManager.process_construction_labor()
	
	# --- Task 1.4 FIX: Roll Severity Early ---
	# We must roll the severity for the *upcoming* Winter when we enter Autumn.
	# This ensures the Autumn Ledger UI can display the correct forecast.
	if s_name == "Autumn":
		WinterManager.roll_upcoming_severity()
	
	# 2. Economy & Payout (THE SOURCE OF TRUTH)
	var payout_report = EconomyManager.calculate_seasonal_payout(s_name)
	
	# 3. Winter Specifics (Hunger Check)
	if s_name == "Winter":
		start_winter_cycle() # Recalculate Hall Actions BEFORE signal
		if SettlementManager.has_method("process_warband_hunger"):
			var warnings = SettlementManager.process_warband_hunger()
			if not warnings.is_empty():
				if not payout_report.has("_messages"): payout_report["_messages"] = []
				payout_report["_messages"].append_array(warnings)
	
	# 4. Save State
	if SettlementManager.has_method("save_settlement"):
		SettlementManager.save_settlement()
		
	# 5. ASSEMBLE CONTEXT PAYLOAD (The Fix)
	var context_data: Dictionary = {}
	context_data["payout"] = payout_report
	
	if SettlementManager.current_settlement and "treasury" in SettlementManager.current_settlement:
		context_data["treasury"] = SettlementManager.current_settlement.treasury.duplicate()
	else:
		context_data["treasury"] = {}
		
	if EconomyManager.has_method("get_winter_forecast"):
		context_data["forecast"] = EconomyManager.get_winter_forecast()
		# Inject the rolled severity into the context for UI convenience,
		# though the UI can also access WinterManager directly.
		context_data["upcoming_severity"] = WinterManager.upcoming_severity
	
	# 6. EMIT SIGNAL
	EventBus.season_changed.emit(s_name, context_data)
	
	# 7. Legacy Feedback
	_display_seasonal_feedback(s_name, payout_report)

func _display_seasonal_feedback(season_name: String, payout: Dictionary) -> void:
	var center_screen = Vector2(960, 500)
	var color = Color.WHITE
	
	if season_name == "Autumn": color = Color.ORANGE
	elif season_name == "Winter": color = Color.CYAN
	
	EventBus.floating_text_requested.emit("%s Arrives" % season_name, center_screen, color)
	
	var offset_y = 40
	for res in payout:
		# Skip non-resource keys
		if res == "_messages" or res == "population_growth": continue 
		
		var amount = payout[res]
		if typeof(amount) == TYPE_INT and amount > 0:
			var text = "+%d %s" % [amount, res.capitalize()]
			var pos = center_screen + Vector2(0, offset_y)
			
			var res_color = Color.WHITE
			if res == "gold": res_color = Color.GOLD
			elif res == "food": res_color = Color.GREEN_YELLOW
			elif res == "wood": res_color = Color.BURLYWOOD
			
			EventBus.floating_text_requested.emit(text, pos, res_color)
			offset_y += 30
			
	if payout.has("_messages"):
		for msg in payout["_messages"]:
			var clean_msg = msg.replace("[color=green]", "").replace("[/color]", "")
			var pos = center_screen + Vector2(0, offset_y)
			EventBus.floating_text_requested.emit(clean_msg, pos, Color.LIGHT_BLUE)
			offset_y += 30

func get_current_season_name() -> String:
	var names = ["Spring", "Summer", "Autumn", "Winter"]
	return names[current_season]

func aggregate_card_effects(card: SeasonalCardResource) -> void:
	if not card: return
	
	if "mod_unit_damage" in card:
		active_year_modifiers["mod_unit_damage"] = active_year_modifiers.get("mod_unit_damage", 0.0) + card.mod_unit_damage
	if "mod_raid_xp" in card:
		active_year_modifiers["mod_raid_xp"] = active_year_modifiers.get("mod_raid_xp", 0.0) + card.mod_raid_xp
	if "mod_pop_growth" in card:
		active_year_modifiers["mod_pop_growth"] = active_year_modifiers.get("mod_pop_growth", 0.0) + card.mod_pop_growth
	if "mod_heir_birth_chance" in card:
		active_year_modifiers["mod_heir_birth_chance"] = active_year_modifiers.get("mod_heir_birth_chance", 0.0) + card.mod_heir_birth_chance
	if "mod_harvest_yield" in card:
		active_year_modifiers["mod_harvest_yield"] = active_year_modifiers.get("mod_harvest_yield", 0.0) + card.mod_harvest_yield
		
	if "modifiers" in card and card.modifiers is Dictionary:
		for key in card.modifiers:
			var value = card.modifiers[key]
			if value is float or value is int:
				active_year_modifiers[key] = active_year_modifiers.get(key, 0.0) + value
	
	# FIX: Removed .data() call, using string formatting instead
	Loggie.msg("DynastyManager: Aggregated effects from '%s'." % card.display_name).domain(LogDomains.DYNASTY).debug()

## Resets all seasonal modifiers. Called at the end of the Winter Cycle (start of Spring).
func reset_year_stats() -> void:
	active_year_modifiers.clear()
	active_year_modifiers["mod_unit_damage"] = 0.0
	active_year_modifiers["mod_raid_xp"] = 0.0
	active_year_modifiers["mod_pop_growth"] = 0.0
	active_year_modifiers["mod_heir_birth_chance"] = 0.0
	active_year_modifiers["mod_harvest_yield"] = 0.0
	
	Loggie.msg("DynastyManager: Year stats reset for new cycle.").domain(LogDomains.DYNASTY).info()

# --- EXISTING LOGIC ---

func _load_game_data() -> void:
	_load_legacy_upgrades_from_disk()
	
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
	
	current_season = Season.SPRING
	# Initial emit on load. Context is empty as no payout occurred.
	EventBus.season_changed.emit("Spring", {})

func start_new_campaign() -> void:
	Loggie.msg("DynastyManager: Starting NEW CAMPAIGN...").domain(LogDomains.DYNASTY).warn()
	
	current_jarl = DynastyGenerator.generate_random_dynasty()
	current_jarl.resource_path = USER_DYNASTY_PATH 
	
	RaidManager.reset_raid_state()
	active_year_modifiers.clear()
	_load_legacy_upgrades_from_disk() 
	_save_jarl_data()
	
	current_season = Season.SPRING
	jarl_stats_updated.emit(current_jarl)

func _load_legacy_upgrades_from_disk() -> void:
	loaded_legacy_upgrades.clear()
	if not DirAccess.dir_exists_absolute("res://data/legacy/"): return

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
	if not current_jarl: _load_game_data()
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
	if not current_jarl: return
	
	current_jarl.calculate_hall_actions()
	Loggie.msg("Winter Cycle Started. Hall Actions: %d" % current_jarl.current_hall_actions).domain(LogDomains.DYNASTY).info()
	
	RaidManager.reset_raid_state()
	WinterManager.start_winter_phase()

func end_winter_cycle_complete() -> void:
	if not current_jarl: return
	
	Loggie.msg("Winter Ended. Advancing to Spring...").domain(LogDomains.DYNASTY).info()
	
	current_jarl.age_jarl(1)
	current_year += 1 
	_process_heir_simulation()
	
	if _check_for_jarl_death(): return 
	
	current_jarl.reset_authority()
	active_year_modifiers.clear()
	
	# Calculate Economy (Winter End Payout)
	var payout_report = EconomyManager.calculate_seasonal_payout("Winter")
	
	# Winter specific feedback
	_display_seasonal_feedback("Winter", payout_report)
	
	SettlementManager.commit_seasonal_recruits()
	if SettlementManager.has_method("save_settlement"):
		SettlementManager.save_settlement()
	
	_save_jarl_data()
	
	# Transition to SPRING. 
	# Note: This will trigger _transition_to_season("Spring"), calculating Spring payout (if any).
	_transition_to_season(Season.SPRING)
	
	jarl_stats_updated.emit(current_jarl)
	
	Loggie.msg("Year ended. Jarl is now %d." % current_jarl.age).domain("DYNASTY").info()
	year_ended.emit()
	EventBus.scene_change_requested.emit("settlement")

func get_current_year(): 
	return current_year

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
	
	# Apply card-based birth modifiers (Heirs Only)
	base_chance += active_year_modifiers.get("mod_heir_birth_chance", 0.0)
	
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
	if key == "":
		return
		
	active_year_modifiers[key] = true
	Loggie.msg("Year Modifier Applied: %s" % key).domain(LogDomains.GAMEPLAY).info()

func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
	return "The %s" % names.pick_random()
