class_name UnitSpawner
extends Node

# --- Configuration ---
@export_group("References")
@export var unit_container: Node2D
@export var rts_controller: RTSController

@export_group("Defaults")
@export var civilian_data: UnitData
@export var spawn_radius_min: float = 100.0
@export var spawn_radius_max: float = 250.0

# --- Constants ---
const LAYER_PLAYER = 2
const LAYER_ENEMY = 4
const SQUAD_SPACING = 150.0
const UNITS_PER_ROW = 5

func _ready() -> void:
	# Fallback search if not assigned in Inspector
	if not unit_container:
		unit_container = get_parent().get_node_or_null("UnitContainer")
		
	if not unit_container:
		Loggie.msg("UnitSpawner: CRITICAL - No UnitContainer found!").domain(LogDomains.SYSTEM).error()

func clear_units() -> void:
	if not unit_container: return
	for child in unit_container.get_children():
		child.queue_free()

# --- PUBLIC SPAWN API ---

func spawn_garrison(warbands: Array[WarbandData], spawn_origin: Vector2) -> void:
	Loggie.msg("UnitSpawner: Requesting deployment for %d Player Warbands." % warbands.size()).domain(LogDomains.RTS).info()

	if not _validate_spawn_setup(): return
	
	var current_index = 0
	
	for warband in warbands:
		if warband.is_wounded: 
			Loggie.msg("Skipping %s (Wounded)" % warband.custom_name).domain(LogDomains.RTS).debug()
			continue
			
		var ideal_pos = _calculate_formation_pos(spawn_origin, current_index)
		
		var unit_instance = _spawn_unit_core(warband, ideal_pos, true)
		if unit_instance:
			# RTS Specifics
			if rts_controller:
				rts_controller.add_unit_to_group(unit_instance)
			
			current_index += 1
		
	Loggie.msg("UnitSpawner: Deployment Complete. %d Squads active." % current_index).domain(LogDomains.RTS).info()

func spawn_enemy_garrison(warbands: Array[WarbandData], buildings: Array) -> void:
	Loggie.msg("UnitSpawner: Spawning %d Enemy Warbands." % warbands.size()).domain(LogDomains.RAID).info()
	
	if not _validate_spawn_setup(): return

	for i in range(warbands.size()):
		var warband = warbands[i]
		
		# Pick a guard post from available buildings
		var guard_pos = Vector2.ZERO
		if not buildings.is_empty():
			var b = buildings[i % buildings.size()]
			if is_instance_valid(b):
				# Slight randomization around the building
				guard_pos = b.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		
		var unit_instance = _spawn_unit_core(warband, guard_pos, false)
		
		if unit_instance:
			# --- FIX: SIGNAL BINDING ---
			# Signal emits (unit), we bind (guard_pos). 
			# Resulting call: _on_enemy_unit_ready(unit, guard_pos)
			unit_instance.fsm_ready.connect(_on_enemy_unit_ready.bind(guard_pos))

# --- CORE LOGIC ---

## Unified logic for instantiating a unit, injecting data, and checking grid safety.
## Returns the instance if successful, null otherwise.
func _spawn_unit_core(warband: WarbandData, target_pos: Vector2, is_player: bool) -> BaseUnit:
	if not warband or not warband.unit_type: return null
	
	var unit_data = warband.unit_type
	var scene_ref = unit_data.load_scene()
	if not scene_ref:
		Loggie.msg("Failed to load scene for %s" % unit_data.display_name).domain(LogDomains.SYSTEM).error()
		return null
	
	# 1. Coordinate Safety Check
	var final_pos = target_pos
	if SettlementManager:
		final_pos = SettlementManager.request_valid_spawn_point(target_pos, 4)
		if final_pos == Vector2.INF:
			Loggie.msg("Spawn blocked at %s for %s" % [target_pos, unit_data.display_name]).domain(LogDomains.NAVIGATION).warn()
			return null # Could not find space
	
	# 2. Instantiate
	var unit = scene_ref.instantiate() as BaseUnit
	
	# 3. Inject Dependencies (Before Adding to Tree)
	unit.warband_ref = warband
	unit.data = unit_data
	
	if is_player:
		unit.collision_layer = LAYER_PLAYER
		unit.add_to_group("player_units")
		if not unit.get_script():
			var leader_script = load("res://scripts/units/SquadLeader.gd")
			unit.set_script(leader_script)
	else:
		unit.collision_layer = LAYER_ENEMY
		unit.add_to_group("enemy_units")
	
	# 4. Position & Parent
	unit.global_position = final_pos
	unit_container.add_child(unit)
	
	# 5. Global Event
	if is_player:
		EventBus.player_unit_spawned.emit(unit)
		
	return unit

# --- HELPER LOGIC ---

func _calculate_formation_pos(origin: Vector2, index: int) -> Vector2:
	var row = index / UNITS_PER_ROW
	var col = index % UNITS_PER_ROW
	
	var offset = Vector2(
		(col - (UNITS_PER_ROW / 2.0)) * SQUAD_SPACING,
		row * SQUAD_SPACING + 200.0
	)
	return origin + offset

func _validate_spawn_setup() -> bool:
	if not unit_container:
		Loggie.msg("Cannot spawn: UnitContainer missing.").domain(LogDomains.SYSTEM).error()
		return false
	return true

# --- FIX: CALLBACK SIGNATURE ---
# The signal argument (unit) comes FIRST. The bound argument (guard_pos) comes SECOND.
func _on_enemy_unit_ready(unit: BaseUnit, guard_pos: Vector2) -> void:
	if not is_instance_valid(unit): return
	
	if unit.fsm:
		unit.fsm.change_state(0) # IDLE
		
	if unit.attack_ai:
		unit.attack_ai.set_process(true)
		unit.attack_ai.set_physics_process(true)
		
		# Set Vision Mask (See Player + Environment)
		if unit.attack_ai.has_method("set_target_mask"):
			unit.attack_ai.set_target_mask(LAYER_PLAYER + 1) 
			
		# Set Guard Post
		if unit.attack_ai is DefenderAI:
			(unit.attack_ai as DefenderAI).configure_guard_post(guard_pos)

# --- CIVILIAN LOGIC ---

func sync_civilians(target_count: int, spawn_origin: Vector2, is_enemy: bool = false) -> void:
	var current_civs = []
	if unit_container:
		for child in unit_container.get_children():
			if child is CivilianUnit:
				current_civs.append(child)
	
	var diff = target_count - current_civs.size()
	
	if diff > 0:
		_spawn_civilians(diff, spawn_origin, is_enemy)
	elif diff < 0:
		_despawn_civilians(abs(diff), current_civs)

func _spawn_civilians(count: int, origin: Vector2, is_enemy: bool) -> void:
	if not civilian_data: return
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	for i in range(count):
		var civ = scene_ref.instantiate()
		
		if is_enemy:
			civ.collision_layer = LAYER_ENEMY
			civ.add_to_group("enemy_units")
			if civ.is_in_group("player_units"): civ.remove_from_group("player_units")
		else:
			civ.collision_layer = LAYER_PLAYER
			civ.add_to_group("player_units")
			
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var pos = origin + (Vector2(cos(angle), sin(angle)) * distance)
		
		if SettlementManager:
			var safe_pos = SettlementManager.request_valid_spawn_point(pos, 2)
			if safe_pos != Vector2.INF: pos = safe_pos
			
		civ.global_position = pos
		unit_container.add_child(civ)
		
		if not is_enemy:
			EventBus.player_unit_spawned.emit(civ)

func _despawn_civilians(count: int, list: Array) -> void:
	for i in range(count):
		if i < list.size():
			var civ = list[i]
			if is_instance_valid(civ):
				if rts_controller: rts_controller.remove_unit(civ)
				civ.queue_free()

func spawn_worker_at(location: Vector2) -> void:
	if not civilian_data: return
	
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	var civ = scene_ref.instantiate()
	civ.global_position = location
	
	civ.collision_layer = LAYER_PLAYER
	civ.add_to_group("player_units")
	civ.add_to_group("civilians")
	
	if unit_container:
		unit_container.add_child(civ)
		EventBus.player_unit_spawned.emit(civ)
