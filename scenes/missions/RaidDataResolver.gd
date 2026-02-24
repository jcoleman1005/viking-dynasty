# res://scenes/missions/RaidDataResolver.gd
class_name RaidDataResolver

## Resolves the SettlementData for a raid mission based on priority waterfall.
static func resolve(force_settlement: SettlementData, default_path: String) -> SettlementData:
	var enemy_base_data: SettlementData = null
	
	# 0. PRIORITY 0: INJECTED DATA (Encapsulation)
	if force_settlement:
		enemy_base_data = force_settlement
		Loggie.msg("Using Injected SettlementData. Seed: %d" % enemy_base_data.map_seed).domain(LogDomains.RAID).info()

	# 1. PRIORITY 1: CAMPAIGN FLOW
	# We check if RaidManager has a target.
	elif RaidManager.current_raid_target:
		# RaidManager.current_raid_target is usually 'RaidTargetData' (The Wrapper).
		# We need the 'SettlementData' inside it.
		var target_wrapper = RaidManager.current_raid_target
		if "settlement_data" in target_wrapper and target_wrapper.settlement_data:
			enemy_base_data = target_wrapper.settlement_data
			Loggie.msg("Loaded SettlementData from RaidManager. Seed: %d" % enemy_base_data.map_seed).domain(LogDomains.RAID).info()
		elif target_wrapper is SettlementData:
			# Handle case where Manager passed raw data
			enemy_base_data = target_wrapper
	
	# 2. PRIORITY 2: DEBUG FLOW (Fresh Generation)
	# If F6 (Scene Run), generate a new procedural base.
	elif enemy_base_data == null and OS.is_debug_build():
		Loggie.msg("Debug Mode: Generating fresh procedural base...").domain(LogDomains.RAID).info()
		enemy_base_data = MapDataGenerator._generate_procedural_settlement("Monastery", 1.0)
		# Ensure the generator gave us a seed!
		if enemy_base_data.map_seed == 0:
			enemy_base_data.map_seed = randi()
	
	# 3. SAFETY FALLBACK (Static File)
	# If all else fails, load the .tres file
	if not enemy_base_data:
		if default_path != "":
			Loggie.msg("Loading Default File: %s" % default_path).domain(LogDomains.RAID).warn()
			enemy_base_data = load(default_path) as SettlementData
			
	return enemy_base_data
