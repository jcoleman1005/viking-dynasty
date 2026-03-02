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
	"mod_birth_chance": 0.0,
	"mod_harvest_yield": 0.0
}
var current_year: int = 880
# --- SEASON STATE ---
enum Season { SPRING, SUMMER, AUTUMN, WINTER }
var current_season: Season = Season.SPRING
const SUMMER_DAYS: int = 12
var current_day: int = 0

# --- FEAST SATURATION ---
# Initialised high so the first feast is never penalised.
var days_since_last_feast: int = 999

# --- BURIAL RITE ---
# Set to true when the player pays for the rite. Consumed and reset in
# SettlementManager.trigger_succession() after the loyalty calculation.
var burial_rite_performed: bool = false

# --- FOUNDING & THREATS ---
var rival_jarl_threat: bool = false

# --- DEBT SYSTEM ---
var active_debt: DebtOfferData = null
var debt_history: Array[Dictionary] = []
var rival_threat_active: bool = false

# --- SPRING OATH TRACKING ---
var active_spring_oath: String = ""
var spring_oath_threshold: int = 0
var spring_oath_metric: String = ""
var oath_broken_this_year: bool = false

# --- RENOWN DECAY ---
var consecutive_safe_oaths: int = 0
var renown_decay_active: bool = false

# --- YEAR EVENT LOG (populated by EventManager._log_skald_event) ---
var year_event_log: Array[Dictionary] = []

# --- YEAR METRICS (updated by relevant systems throughout the year) ---
# These are checked by _resolve_spring_oath() at Autumn transition.
var year_metrics: Dictionary = {
	"food_harvested": 0,
	"gold_raided": 0,
	"buildings_completed": 0,
	"loyalty_conflicts_resolved": 0,
	"personally_led_raid": false,
	"feast_held": false,
}

# --- CONSTANTS ---
const USER_DYNASTY_PATH = "user://savegame_dynasty.tres"
const DEFAULT_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_game_data()
	EventBus.succession_choices_made.connect(_on_succession_choices_made)
	EventBus.advance_season_requested.connect(advance_season)

# --- SEASON LOGIC ---

func advance_day() -> void:
	current_day += 1
	days_since_last_feast += 1
	
	# Process labor (Construction) daily during Summer
	if SettlementManager.has_method("process_construction_labor"):
		SettlementManager.process_construction_labor()
		
	EventBus.summer_day_changed.emit(current_day, SUMMER_DAYS)

	# --- SCOUT OATH STUB ---
	# TODO: fog-of-war not yet implemented.
	# Intended: for each SCOUT household, reveal 3 * labor_efficiency map tiles per day.
	# NavigationManager has no reveal API; wire this up when the fog system is built.
	# Emit placeholder signal so UI can display scouting activity without crashing.
	var scout_count := 0
	var settlement := SettlementManager.current_settlement
	if settlement:
		for household in settlement.households:
			if household.current_oath == HouseholdData.SeasonalOath.SCOUT:
				scout_count += 1
	if scout_count > 0:
		EventBus.scout_progress_updated.emit(0)  # 0 tiles until fog system exists

	EventManager.check_daily_events(current_day)
	if current_day > SUMMER_DAYS:
		advance_season()

func advance_season() -> void:
	Loggie.msg("DynastyManager: advance_season() called. Current: %d" % current_season).domain(LogDomains.DYNASTY).info()
	match current_season:
		Season.SPRING:
			_transition_to_season(Season.SUMMER)
			current_day = 1
			EventBus.summer_day_changed.emit(current_day, SUMMER_DAYS)
			EventManager.check_daily_events(current_day)
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

	# Advance feast-saturation timer when leaving Summer (each non-Summer season
	# adds ~30 days as a rough approximation until a full calendar system exists).
	if s_name != "Summer":
		days_since_last_feast += 30
	
	Loggie.msg("Season Advancing to: %s..." % s_name).domain(LogDomains.DYNASTY).info()
	
	# --- ORCHESTRATION: The Game Loop ---
	
	# 1. Labor (Construction)
	# For turn-based seasons (Summer), labor is processed daily in advance_day().
	# For others, it's processed once on transition.
	if s_name != "Summer" and SettlementManager.has_method("process_construction_labor"):
		SettlementManager.process_construction_labor()
	
	# --- Task 1.4 FIX: Roll Severity Early ---
	# We must roll the severity for the *upcoming* Winter when we enter Autumn.
	# This ensures the Autumn Ledger UI can display the correct forecast.
	var autumn_oath_result: Dictionary = {}
	if s_name == "Autumn":
		WinterManager.roll_upcoming_severity()
		autumn_oath_result = _resolve_spring_oath()
		_check_debt_trigger()
	
	# 2. Economy & Payout (THE SOURCE OF TRUTH)
	var payout_report = EconomyManager.calculate_seasonal_payout(s_name)
	
	# 3. Winter Specifics (Hunger Check)
	if s_name == "Winter":
		# TODO: Implement a turn-based day system for Winter (e.g., WINTER_DAYS = 6)
		# to allow for daily events and incremental survival pressure.
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

	if s_name == "Autumn":
		context_data["oath_result"]     = autumn_oath_result
		context_data["year_events"]     = year_event_log.duplicate()
		context_data["jarl_name"]       = current_jarl.display_name if current_jarl else "The Jarl"
		context_data["current_year"]    = current_year
		var sev_keys: Variant = WinterManager.WinterSeverity.keys()
		var sev_idx: int = WinterManager.upcoming_severity
		context_data["winter_severity"] = sev_keys[sev_idx].to_lower() if sev_idx < sev_keys.size() else "normal"

	# 6. EMIT SIGNAL
	EventBus.season_changed.emit(s_name, context_data)
	
	# 7. Legacy Feedback
	_display_seasonal_feedback(s_name, payout_report)
	
	# 8. Check for seasonal events (Day -1)
	EventManager.check_daily_events(-1)

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

## Resets all seasonal modifiers. Called at the end of the Winter Cycle (start of Spring).
func reset_year_stats() -> void:
	active_year_modifiers.clear()
	active_year_modifiers["mod_unit_damage"] = 0.0
	active_year_modifiers["mod_raid_xp"] = 0.0
	active_year_modifiers["mod_pop_growth"] = 0.0
	active_year_modifiers["mod_birth_chance"] = 0.0
	active_year_modifiers["mod_harvest_yield"] = 0.0

	# Clear spring oath state for the new year
	active_spring_oath = ""
	spring_oath_threshold = 0
	spring_oath_metric = ""
	oath_broken_this_year = false

	# Clear year event log (Skald report for new year starts fresh)
	year_event_log.clear()

	# Reset year metrics
	year_metrics = {
		"food_harvested": 0,
		"gold_raided": 0,
		"buildings_completed": 0,
		"loyalty_conflicts_resolved": 0,
		"personally_led_raid": false,
		"feast_held": false,
	}

	Loggie.msg("DynastyManager: Year stats reset for new cycle.").domain(LogDomains.DYNASTY).info()

# --- SPRING OATH RESOLUTION ---

func _resolve_spring_oath() -> Dictionary:
	var result := {
		"oath_id":      active_spring_oath,
		"outcome":      "none",
		"renown_delta": 0,
		"notes":        "",
	}

	if active_spring_oath.is_empty():
		return result

	var bd = EventManager.balance_data
	var metric_val: Variant = _get_metric_value()
	var is_boolean := spring_oath_metric in ["personally_led_raid", "feast_held"]

	# --- Determine outcome ---
	var outcome: String
	var notes: String
	if is_boolean:
		if metric_val:
			outcome = "kept"
			notes   = "Condition fulfilled."
		else:
			outcome = "broken"
			notes   = "Condition not fulfilled."
	else:
		var pct: float = float(metric_val) / float(spring_oath_threshold) \
			if spring_oath_threshold > 0 else 0.0
		if pct >= 1.0:
			outcome = "kept"
			notes   = "%d / %d — threshold reached." % [metric_val, spring_oath_threshold]
		elif pct >= 0.5:
			outcome = "partial"
			notes   = "%d / %d — threshold not fully reached." % [metric_val, spring_oath_threshold]
		else:
			outcome = "broken"
			notes   = "%d / %d — far short of threshold." % [metric_val, spring_oath_threshold]

	# --- Bold detection ---
	var is_bold := false
	if bd and current_jarl and not spring_oath_metric.is_empty():
		var stat_key := _get_stat_for_metric(spring_oath_metric)
		if stat_key != "":
			var stat_val: int = current_jarl.get(stat_key) if current_jarl.get(stat_key) != null else 10
			is_bold = spring_oath_threshold > int(stat_val * bd.bold_oath_threshold_multiplier)

	# --- Renown delta (hardcoded; tune via EventBalanceData if needed) ---
	var renown_delta: int
	match outcome:
		"kept":    renown_delta = 25 if is_bold else 10
		"partial": renown_delta = 3
		_:         renown_delta = -5

	result["outcome"]      = outcome
	result["renown_delta"] = renown_delta
	result["notes"]        = notes

	# --- Apply effects ---
	if current_jarl:
		current_jarl.renown = max(0, current_jarl.renown + renown_delta)

	var settlement := SettlementManager.current_settlement
	if settlement:
		for household in settlement.households:
			match outcome:
				"kept":    household.loyalty = min(100, household.loyalty + 5)
				"broken":  household.loyalty = max(0,   household.loyalty - 10)

	# --- Update state flags ---
	match outcome:
		"kept":
			oath_broken_this_year = false
			if is_bold:
				consecutive_safe_oaths = 0
				renown_decay_active = false
			else:
				consecutive_safe_oaths += 1
				if bd and consecutive_safe_oaths > bd.renown_decay_grace_period:
					renown_decay_active = true
		"partial":
			oath_broken_this_year = false
			# Partial: no decay credit, but doesn't trigger decay
		"broken":
			oath_broken_this_year = true
			consecutive_safe_oaths = 0
			renown_decay_active = true

	# --- Year event log ---
	year_event_log.append({
		"event_id":   "oath_%s" % outcome,
		"variables":  {"jarl_name": current_jarl.display_name if current_jarl else "The Jarl"},
		"significance": 2,
	})

	match outcome:
		"kept":    Loggie.msg("Spring oath kept: %s (bold=%s)" % [active_spring_oath, str(is_bold)]).domain(LogDomains.DYNASTY).info()
		"partial": Loggie.msg("Spring oath partial: %s" % active_spring_oath).domain(LogDomains.DYNASTY).info()
		_:         Loggie.msg("Spring oath broken: %s" % active_spring_oath).domain(LogDomains.DYNASTY).warn()

	active_spring_oath = ""
	return result


## Returns the raw current value for the active oath metric.
func _get_metric_value() -> Variant:
	match spring_oath_metric:
		"food_harvested":           return year_metrics.get("food_harvested", 0)
		"gold_raided":              return year_metrics.get("gold_raided", 0)
		"buildings_completed":      return year_metrics.get("buildings_completed", 0)
		"loyalty_conflicts_resolved": return year_metrics.get("loyalty_conflicts_resolved", 0)
		"personally_led_raid":      return year_metrics.get("personally_led_raid", false)
		"feast_held":               return year_metrics.get("feast_held", false)
	return 0


func _get_stat_for_metric(metric: String) -> String:
	match metric:
		"food_harvested":       return "stewardship"
		"gold_raided":          return "command"
		"buildings_completed":  return "learning"
		"loyalty_conflicts_resolved": return "diplomacy"
		"personally_led_raid":  return "prowess"
		"feast_held":           return "charisma"
	return ""


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
	Loggie.msg("DynastyManager: Starting NEW CAMPAIGN...").domain(LogDomains.DYNASTY).info()

	current_jarl = DynastyGenerator.generate_random_dynasty()
	current_jarl.resource_path = USER_DYNASTY_PATH

	RaidManager.reset_raid_state()
	active_year_modifiers.clear()
	_load_legacy_upgrades_from_disk()
	_save_jarl_data()

	current_season = Season.SPRING
	jarl_stats_updated.emit(current_jarl)


## Called by FoundingSequenceManager after the founding sequence completes.
## The jarl has already been configured — this method saves state and loads the game.
func start_new_campaign_with_jarl(jarl: JarlData) -> void:
	Loggie.msg("DynastyManager: Starting campaign from founding sequence.").domain(LogDomains.DYNASTY).info()
	current_jarl = jarl
	current_jarl.resource_path = USER_DYNASTY_PATH
	RaidManager.reset_raid_state()
	active_year_modifiers.clear()
	_load_legacy_upgrades_from_disk()
	_save_jarl_data()
	current_year = 880
	current_season = Season.SPRING
	jarl_stats_updated.emit(current_jarl)
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

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
	_apply_renown_decay()
	_check_debt_repayment_deadline()
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
	
	# Reset per-year oath/log data before starting the new year.
	reset_year_stats()

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
	base_chance += active_year_modifiers.get("mod_birth_chance", 0.0)
	
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
	_inherit_debt()
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


# --- RENOWN DECAY ---

## Applies renown decay when the Jarl has played too safely for too long.
## Called once per year in end_winter_cycle_complete(), after current_year increments.
func _apply_renown_decay() -> void:
	if not current_jarl: return
	var bd = EventManager.balance_data
	if not bd: return
	if consecutive_safe_oaths <= bd.renown_decay_grace_period: return
	var decay := int(current_jarl.renown * bd.renown_decay_rate)
	if decay <= 0: return
	current_jarl.renown = max(0, current_jarl.renown - decay)
	year_event_log.append({
		"event_id": "renown_decay",
		"variables": {"jarl_name": current_jarl.display_name, "amount": decay},
		"significance": 1,
	})
	Loggie.msg("Renown Decay: %s lost %d renown (consecutive safe oaths: %d)." % [
		current_jarl.display_name, decay, consecutive_safe_oaths,
	]).domain(LogDomains.DYNASTY).info()


# --- DEBT SYSTEM ---

## Checks whether the food deficit is severe enough to trigger a debt offer.
## Called from the Autumn branch of _transition_to_season().
func _check_debt_trigger() -> void:
	if active_debt != null: return
	if not current_jarl: return
	var bd : EventBalanceData = EventManager.balance_data
	if not bd: return
	var settlement := SettlementManager.current_settlement
	if not settlement: return
	var current_food: int = settlement.treasury.get("food", 0)
	var trigger_floor := int(EconomyManager.projected_winter_consumption * bd.debt_trigger_threshold)
	if current_food < trigger_floor:
		_generate_debt_offer(trigger_floor - current_food)


## Builds a DebtOfferData and stores it on active_debt.
## No-ops if a debt is already active — one creditor at a time.
func _generate_debt_offer(deficit: int) -> void:
	if active_debt != null: return
	if not current_jarl: return
	var bd :EventBalanceData = EventManager.balance_data
	var offer := DebtOfferData.new()

	# Choose creditor based on connections and history
	var has_prior_debt := not debt_history.is_empty()
	if current_jarl.diplomacy >= 12:
		offer.creditor_name = "Merchant-Jarl Sigurd the Fat"
	elif has_prior_debt:
		offer.creditor_name = "The Moneylender of Hedeby"
	else:
		offer.creditor_name = "Trader Orm Blackhands"

	offer.grain_amount = deficit + randi_range(10, 30)
	var interest_rate := 1.5 if has_prior_debt else 1.25
	offer.repayment_amount = int(offer.grain_amount * interest_rate)
	offer.repayment_deadline_years = 2
	offer.repayment_due_year = current_year + offer.repayment_deadline_years

	# Assemble human-readable explanation
	var reasons: Array[String] = []
	if current_jarl.renown > 50:
		reasons.append("your renown precedes you")
	if current_jarl.charisma >= 10:
		reasons.append("your silver tongue has not gone unnoticed")
	if has_prior_debt:
		reasons.append("you have honoured debts before")
	var reason_text: String = ", ".join(reasons) if not reasons.is_empty() else "necessity speaks plainly"
	offer.offer_explanation = (
		"%s offers %d grain because %s. "
		+ "You must repay %d grain within %d years."
	) % [
		offer.creditor_name, offer.grain_amount, reason_text,
		offer.repayment_amount, offer.repayment_deadline_years,
	]

	active_debt = offer
	Loggie.msg("Debt offer generated from %s: %d grain." % [
		offer.creditor_name, offer.grain_amount,
	]).domain(LogDomains.DYNASTY).info()


## Multiplies the debt repayment by debt_inheritance_rate when a Jarl dies mid-debt.
## Called from _trigger_succession() before current_jarl is replaced.
func _inherit_debt() -> void:
	if not active_debt: return
	var bd :EventBalanceData = EventManager.balance_data
	var rate: float = bd.debt_inheritance_rate if bd else 1.3
	active_debt.repayment_amount = int(active_debt.repayment_amount * rate)
	active_debt.inherited = true
	Loggie.msg("Debt inherited. New repayment: %d grain." % active_debt.repayment_amount).domain(LogDomains.DYNASTY).info()


## Called each year-end to auto-default any overdue debt.
## Fires after current_year has already been incremented.
func _check_debt_repayment_deadline() -> void:
	if not active_debt: return
	if current_year < active_debt.repayment_due_year: return
	Loggie.msg("Debt deadline passed (year %d). Triggering default." % current_year).domain(LogDomains.DYNASTY).info()
	_process_debt_default()


## Called when the player refuses a debt or cannot repay.
## Records the default and activates the rival threat flag.
func _process_debt_default() -> void:
	if not active_debt: return
	var entry := {
		"creditor": active_debt.creditor_name,
		"amount":   active_debt.repayment_amount,
		"defaulted": true,
		"year":     current_year,
	}
	debt_history.append(entry)
	year_event_log.append({
		"event_id": "debt_default",
		"variables": {"amount": entry.amount, "creditor": entry.creditor},
		"significance": 3,
	})
	active_debt = null
	rival_threat_active = true
	Loggie.msg("Debt defaulted! Rival threat is now active.").domain(LogDomains.DYNASTY).info()
