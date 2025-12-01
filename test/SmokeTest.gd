# res://test/SquadSystemTest.gd
extends Node2D

# Dependencies
const UNIT_SPAWNER_SCRIPT = preload("res://scripts/utility/UnitSpawner.gd")
const PLAYER_UNIT_DATA_PATH = "res://data/units/Unit_PlayerRaider.tres"

var spawner: UnitSpawner
var unit_container: Node2D
var rts_controller: RTSController

func _ready() -> void:
	print("\n🛡️ --- STARTING SQUAD SYSTEM SMOKE TEST --- 🛡️")
	
	# 1. SETUP ENVIRONMENT
	_setup_scene_tree()
	
	# 2. CREATE MOCK DATA
	var warbands = _create_mock_warbands()
	
	# 3. EXECUTE SPAWN
	print("🔹 Requesting Spawn of %d Warbands..." % warbands.size())
	spawner.spawn_garrison(warbands, Vector2(500, 300))
	
	# 4. VERIFY
	# Wait a few frames for deferred calls (add_child, _ready, etc)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	_verify_spawn_results()
	
	print("\n✅ TEST COMPLETE.")

func _setup_scene_tree() -> void:
	# Create Container
	unit_container = Node2D.new()
	unit_container.name = "UnitContainer"
	add_child(unit_container)
	
	# Create RTS Controller (Stub)
	rts_controller = RTSController.new()
	rts_controller.name = "RTSController"
	add_child(rts_controller)
	
	# Create Spawner
	spawner = UnitSpawner.new()
	spawner.name = "UnitSpawner"
	spawner.unit_container = unit_container
	spawner.rts_controller = rts_controller
	add_child(spawner)

func _create_mock_warbands() -> Array[WarbandData]:
	var list: Array[WarbandData] = []
	
	if not ResourceLoader.exists(PLAYER_UNIT_DATA_PATH):
		printerr("❌ CRITICAL: Could not find Unit Data at ", PLAYER_UNIT_DATA_PATH)
		return []
		
	var u_data = load(PLAYER_UNIT_DATA_PATH)
	
	# Create 1 Warband with 5 Men
	var wb = WarbandData.new()
	wb.unit_type = u_data
	wb.custom_name = "Test Squad Alpha"
	wb.current_manpower = 5
	list.append(wb)
	
	return list

func _verify_spawn_results() -> void:
	print("\n📊 --- VERIFICATION ---")
	
	# 1. Check for Squad Leaders
	var leaders = []
	for child in unit_container.get_children():
		if child is SquadLeader:
			leaders.append(child)
			
	if leaders.size() == 1:
		print("✅ PASS: 1 Squad Leader found.")
	else:
		printerr("❌ FAIL: Found %d Leaders (Expected 1)." % leaders.size())
		return

	# 2. Check for Minions
	var leader = leaders[0]
	# Minions are siblings of the leader in the container
	var minions = []
	for child in unit_container.get_children():
		# Check if script is SquadSoldier (using resource path check is safe)
		if child.get_script().resource_path.contains("SquadSoldier"):
			minions.append(child)
			
	# Expected: 4 Minions (5 Manpower - 1 Leader)
	if minions.size() == 4:
		print("✅ PASS: 4 Minions found (Manpower 5 - Leader).")
	else:
		printerr("❌ FAIL: Found %d Minions (Expected 4)." % minions.size())
		
	# 3. Check Formation Link
	if leader.squad_soldiers.size() == minions.size():
		print("✅ PASS: Leader knows about all %d minions." % leader.squad_soldiers.size())
	else:
		printerr("❌ FAIL: Leader only tracks %d/%d minions." % [leader.squad_soldiers.size(), minions.size()])
