extends Node

# Signal emitted when a raid calculation completes or state changes
signal raid_state_updated

# --- DATA ---
var current_raid_target: SettlementData
var is_defensive_raid: bool = false
var current_raid_difficulty: int = 1
var pending_raid_result: RaidResultData = null

# --- STAGING & LOGISTICS ---
var outbound_raid_force: Array[WarbandData] = []
var raid_provisions_level: int = 1
var raid_health_modifier: float = 1.0

# "neutral", "victory", "defeat"
var last_raid_outcome: String = "neutral"

func reset_raid_state() -> void:
	outbound_raid_force.clear()
	raid_provisions_level = 1
	raid_health_modifier = 1.0
	current_raid_target = null
	pending_raid_result = null
	is_defensive_raid = false
	raid_state_updated.emit()

func prepare_raid_force(warbands: Array[WarbandData], provisions: int) -> void:
	if warbands.is_empty():
		Loggie.msg("RaidManager: Warning - Raid force prepared with 0 units.").domain("RAID").warn()
	
	outbound_raid_force = warbands.duplicate()
	raid_provisions_level = provisions
	
	Loggie.msg("Raid Force Prepared: %d Warbands, Provision Level %d" % [outbound_raid_force.size(), provisions]).domain("RAID").info()
	raid_state_updated.emit()

func set_current_raid_target(data: SettlementData) -> void:
	current_raid_target = data

func get_current_raid_target() -> SettlementData:
	var target = current_raid_target
	# We generally don't clear it immediately on get, keeping state stable until reset_raid_state()
	return target

# --- CORE LOGIC: MIGRATED FROM DYNASTYMANAGER ---

func calculate_journey_attrition(target_distance: float) -> Dictionary:
	# Runtime Dependency Check
	if not DynastyManager.current_jarl:
		Loggie.msg("RaidManager: Cannot calculate attrition, no Current Jarl.").domain("RAID").error()
		return {}
		
	if target_distance < 0: target_distance = 0.0
	
	var jarl = DynastyManager.current_jarl
	var safe_range = jarl.get_safe_range()
	
	var report = {
		"title": "Uneventful Journey",
		"description": "The seas were calm. The fleet arrived intact.",
		"modifier": 1.0
	}
	
	var base_risk = 0.02
	if target_distance > safe_range:
		# Calculate risk based on Jarl's attrition stats
		base_risk = ((target_distance - safe_range) / 100.0) * jarl.attrition_per_100px
	
	if raid_provisions_level == 2:
		base_risk -= 0.15 
		
	base_risk = clampf(base_risk, 0.05, 0.90) 
	
	var roll = randf()
	
	if roll < base_risk:
		report["title"] = "Rough Seas"
		var damage = 0.10 
		
		if roll < (base_risk * 0.5):
			damage = 0.25 
			report["description"] = "A terrible storm scattered the fleet! Supplies were lost and men are exhausted."
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
		else:
			raid_health_modifier = 1.0
			
	return report

func process_defensive_loss() -> Dictionary:
	# Runtime Dependency Check
	if not DynastyManager.current_jarl: 
		return {}
		
	var jarl = DynastyManager.current_jarl
	var aftermath_report = {
		"summary_text": "",
		"jarl_died": false,
		"heir_died": null 
	}
	
	# 1. Renown Loss
	var renown_loss = randi_range(50, 150)
	jarl.renown = max(0, jarl.renown - renown_loss)
	
	# 2. Material Loss (Delegated to EconomyManager)
	var material_losses = EconomyManager.apply_raid_damages()
	
	# 3. Heir Death Chance
	if jarl.heirs.size() > 0 and randf() < 0.15:
		var victim = jarl.heirs.pick_random()
		victim.status = JarlHeirData.HeirStatus.Deceased
		aftermath_report["heir_died"] = victim.display_name
		
		# We modify the Resource directly
		jarl.remove_heir(victim)
		
	# 4. Jarl Death Chance
	var death_chance = 0.10
	if jarl.age > 60: death_chance += 0.10
	
	if randf() < death_chance:
		aftermath_report["jarl_died"] = true
		# We use the debug method to trigger standard death flow
		# In Phase 4 we might make this a more formal API call
		DynastyManager.debug_kill_jarl()
	
	# 5. Commit Changes
	DynastyManager._save_jarl_data()
	DynastyManager.jarl_stats_updated.emit(jarl)
	
	var text = "Defeat! The settlement has been sacked.\n\n[color=salmon]Resources Lost:[/color]\n- %d Gold\n- %d Wood\n- %d Renown\n" % [material_losses.get("gold_lost", 0), material_losses.get("wood_lost", 0), renown_loss]
	aftermath_report["summary_text"] = text
	
	last_raid_outcome = "defeat"
	return aftermath_report
