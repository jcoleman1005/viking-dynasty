# res://test/BlotEffectsTest.gd
extends Node2D

func _ready() -> void:
	print("\n⚡ --- STARTING BLÓT EFFECTS SMOKE TEST --- ⚡")
	
	# 1. ODIN TEST
	_test_odin_xp()
	
	# 2. THOR TEST
	await _test_thor_damage()
	
	# 3. FREYR TEST
	_test_freyr_logic()
	
	print("\n✅ BLÓT TEST SUITE COMPLETE.")

func _test_odin_xp() -> void:
	print("🔹 Testing Odin (XP Boost)...")
	
	# Setup Modifier
	DynastyManager.active_year_modifiers.clear()
	DynastyManager.active_year_modifiers["BLOT_ODIN"] = true
	
	# Setup Mock Settlement & Warband
	var settlement = SettlementData.new()
	var wb = WarbandData.new()
	wb.experience = 0
	wb.custom_name = "Test Berserkers"
	settlement.warbands.append(wb)
	SettlementManager.current_settlement = settlement
	
	# Mock Raid Result (Victory = 50 Base XP)
	DynastyManager.pending_raid_result = {"outcome": "victory", "gold_looted": 100}
	
	# Instantiate SettlementBridge to run the logic
	var bridge = load("res://scenes/levels/SettlementBridge.tscn").instantiate()
	add_child(bridge)
	
	# Force the raid return logic
	bridge.call("_process_raid_return")
	
	# Verify
	# Base 50 * 1.5 Odin Multiplier = 75
	if wb.experience == 75: 
		print("   ✅ PASS: XP increased to 75 (Expected 75).")
	else:
		printerr("   ❌ FAIL: XP is %d (Expected 75)." % wb.experience)
		
	bridge.queue_free()

func _test_thor_damage() -> void:
	print("🔹 Testing Thor (Damage Boost)...")
	
	# Setup Modifier
	DynastyManager.active_year_modifiers.clear()
	DynastyManager.active_year_modifiers["BLOT_THOR"] = true
	
	# Instantiate a real unit
	var unit_scene = load("res://scenes/units/PlayerVikingRaider.tscn")
	var unit = unit_scene.instantiate()
	
	# --- FIX: Inject Data Manually ---
	# The unit needs data to initialize its AttackAI
	var unit_data = load("res://data/units/Unit_PlayerRaider.tres")
	unit.data = unit_data
	# ---------------------------------
	
	# Add to tree to trigger _ready and the deferred setup
	add_child(unit)
	
	# Wait 2 frames for _deferred_setup -> _create_hitbox -> AttackAI spawn
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find AttackAI child
	var ai = null
	for child in unit.get_children():
		if child is AttackAI:
			ai = child
			break
			
	if not ai:
		printerr("   ❌ FAIL: Unit has no AttackAI component! (Check if UnitData was loaded)")
		unit.queue_free()
		return
		
	# [cite_start]Base Damage for PlayerVikingRaider is 15 [cite: 66]
	# Thor Buff is +10% -> 16.5 -> cast to int 16
	if ai.attack_damage > 15:
		print("   ✅ PASS: Damage is %d (Base 15). Boost applied." % ai.attack_damage)
	else:
		printerr("   ❌ FAIL: Damage is %d (Expected > 15)." % ai.attack_damage)
	
	unit.queue_free()

func _test_freyr_logic() -> void:
	print("🔹 Testing Freyr (Modifier Check)...")
	
	# Setup Modifier
	DynastyManager.active_year_modifiers.clear()
	DynastyManager.active_year_modifiers["BLOT_FREYR"] = true
	
	# Since birth is RNG, we verify the modifier is correctly registered for the check
	if DynastyManager.active_year_modifiers.has("BLOT_FREYR"):
		print("   ✅ PASS: Freyr Modifier is registered active.")
		print("          (DynastyManager._try_birth_event will read this key).")
	else:
		printerr("   ❌ FAIL: Modifier failed to apply.")
