# res://scripts/systems/UnitSpawner.gd
class_name UnitSpawner
extends Node

# --- Configuration ---
@export var unit_container: Node2D
@export var rts_controller: RTSController
@export var civilian_data: UnitData

# --- Spawn Settings ---
@export var spawn_radius_min: float = 100.0
@export var spawn_radius_max: float = 250.0

func _ready() -> void:
	if not unit_container:
		Loggie.msg("UnitSpawner: Missing unit_container reference.").domain(LogDomains.SYSTEM).warn()

func clear_units() -> void:
	if not unit_container: return
	for child in unit_container.get_children():
		child.queue_free()

# --- MILITARY SPAWNING (Squads) ---

func spawn_garrison(warbands: Array[WarbandData], spawn_origin: Vector2) -> void:
	if not unit_container: return
	
	var current_squad_index = 0
	var units_per_row = 5
	var squad_spacing = 150.0 # Spacing between LEADERS
	
	for warband in warbands:
		# 1. Validate
		if warband.is_wounded: continue
		var unit_data = warband.unit_type
		if not unit_data: continue
		
		# 2. Load Scene
		var scene_ref = unit_data.load_scene()
		if not scene_ref: continue
		
		# 3. Instantiate Leader
		var leader = scene_ref.instantiate()
		
		# 4. Swap to SquadLeader Script logic (The Shepherd System)
		var leader_script = load("res://scripts/units/SquadLeader.gd")
		leader.set_script(leader_script)
		
		# 5. Configure
		leader.warband_ref = warband
		leader.data = unit_data
		leader.collision_layer = 2 # Player Unit
		
		# 6. Position (Grid formation for squads)
		var row = current_squad_index / units_per_row
		var col = current_squad_index % units_per_row
		
		# Offset from the Great Hall/Spawn Origin
		var formation_offset = Vector2(
			(col - (units_per_row / 2.0)) * squad_spacing,
			row * squad_spacing + 200.0 # Start 200px "south" of the hall
		)
		
		leader.global_position = spawn_origin + formation_offset
		
		# 7. Register
		unit_container.add_child(leader)
		
		if rts_controller:
			# RTS Controller only tracks Leaders now
			rts_controller.add_unit_to_group(leader)
			
		current_squad_index += 1
		
	Loggie.msg("UnitSpawner: Deployed %d squads." % current_squad_index).domain(LogDomains.RTS).info()

# --- CIVILIAN SPAWNING ---

func sync_civilians(idle_count: int, spawn_origin: Vector2) -> void:
	if not unit_container or not civilian_data: return
	
	# 1. Count Existing (EXCLUDING BUSY WORKERS)
	# We only want to sync units that are actually "Idle"
	var active_idle_civilians = []
	for child in unit_container.get_children():
		# Check for group membership safely
		if child.is_in_group("civilians") and not child.is_in_group("busy"):
			active_idle_civilians.append(child)
	
	var current_count = active_idle_civilians.size()
	var diff = idle_count - current_count
	
	# 2. Spawn or Despawn based on the "True Idle" count
	if diff > 0:
		_spawn_civilians(diff, spawn_origin)
	elif diff < 0:
		# We pass the filtered list so we don't accidentally delete a busy worker
		_despawn_civilians(abs(diff), active_idle_civilians)

func _spawn_civilians(count: int, origin: Vector2) -> void:
	if civilian_data:
		print("UnitSpawner: Spawning %d civilians using data: %s" % [count, civilian_data.resource_path])
	else:
		printerr("UnitSpawner: ERROR - Civilian Data is NULL!")
		return
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	for i in range(count):
		var civ = scene_ref.instantiate()
		
		# Ensure Civilian Script is attached (if scene is generic)
		if not civ.get_script() or civ.get_script().resource_path != "res://scripts/units/CivilianUnit.gd":
			civ.set_script(load("res://scripts/units/CivilianUnit.gd"))
			
		civ.data = civilian_data
		
		# Random Circle Position
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		
		civ.position = origin + offset
		unit_container.add_child(civ)
		
		# Register
		if rts_controller:
			rts_controller.add_unit_to_group(civ)
			
		# Optional: Small wander
		if civ.has_method("command_move_to"):
			var wander = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			civ.command_move_to(civ.position + wander)

func _despawn_civilians(count: int, list: Array) -> void:
	for i in range(count):
		if i < list.size():
			var civ = list[i]
			if is_instance_valid(civ):
				# Graceful cleanup
				if rts_controller: rts_controller.remove_unit(civ)
				civ.queue_free()

func spawn_worker_at(location: Vector2) -> void:
	if not civilian_data: return
	
	# Reuse internal logic but for count 1 and specific origin
	# We use a small random offset so they don't clip exactly into the wall
	_spawn_civilians(1, location)
	
	Loggie.msg("UnitSpawner: Worker spawned at %s" % location).domain(LogDomains.UNIT).debug()
