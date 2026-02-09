extends Node

## DIAGNOSTIC TOOL: Population Census Auditor
## Attach to MainGameUI to audit where the population numbers are coming from.

func _ready() -> void:
	# Listen to all events that might change population
	EventBus.population_changed.connect(_perform_audit.bind("Signal: Population Changed"))
	EventBus.treasury_updated.connect(func(_t): _perform_audit("Signal: Treasury Updated"))
	
	# Initial check
	await get_tree().process_frame
	_perform_audit("Initial Load")

func _perform_audit(trigger: String) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return

	Loggie.msg("--- POPULATION TRACE (%s) ---" % trigger).domain(LogDomains.ECONOMY).info()

	# 1. Raw Variables (The "Civilians")
	var raw_peasants = settlement.population_peasants
	var raw_thralls = settlement.population_thralls
	
	# 2. Warband Manpower (The "Soldiers")
	var soldier_count = 0
	for wb in settlement.warbands:
		if wb: soldier_count += wb.current_manpower

	# 3. The "Single Source of Truth" Calculation
	var total_biological_humans = raw_peasants + raw_thralls + soldier_count
	
	Loggie.msg("   > RAW Peasants (Labor): %d" % raw_peasants).domain(LogDomains.ECONOMY).info()
	Loggie.msg("   > RAW Thralls (Labor): %d" % raw_thralls).domain(LogDomains.ECONOMY).info()
	Loggie.msg("   > RAW Soldiers (Drafted): %d" % soldier_count).domain(LogDomains.ECONOMY).info()
	Loggie.msg("   =========================").domain(LogDomains.ECONOMY).info()
	Loggie.msg("   > TOTAL HUMANS: %d" % total_biological_humans).domain(LogDomains.ECONOMY).info()
	
	# 4. Hint for the User
	Loggie.msg("   [CHECK TOPBAR]: If TopBar shows '%d', it is showing Labor." % raw_peasants).domain(LogDomains.ECONOMY).warn()
	Loggie.msg("   [CHECK TOPBAR]: If TopBar shows '%d', it is showing Total Population." % total_biological_humans).domain(LogDomains.ECONOMY).warn()
