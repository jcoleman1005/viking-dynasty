# res://scripts/units/SquadSoldier.gd
class_name SquadSoldier
extends BaseUnit

# --- References ---
var leader: SquadLeader
var formation_target: Vector2 = Vector2.ZERO

# --- Brawl State (Combat) ---
var brawl_target: Node2D = null
var return_to_formation_threshold: float = 10.0

# --- Rubber Banding (Anti-Stuck) ---
const MAX_DIST_FROM_LEADER = 300.0
const CATCHUP_DIST = 80.0
const SPRINT_SPEED_MULT = 2.5
var is_rubber_banding: bool = false

func _ready() -> void:
	# 1. Apply Physics defaults for Minions (Stronger separation to prevent stacking)
	separation_force = 80.0 
	separation_radius = 25.0
	separation_enabled = true
	
	super._ready()
	
	# 2. Disable BaseUnit FSM (Minions don't think, they obey)
	if fsm:
		fsm.set_script(null) 
		fsm = null
		
	# 3. Setup Brawl AI
	if attack_ai:
		attack_ai.attack_started.connect(_on_brawl_started)
		attack_ai.attack_stopped.connect(_on_brawl_stopped)
		
		# Soldiers have a smaller aggro range than the leader (Personal space only)
		if attack_ai.detection_area:
			for child in attack_ai.detection_area.get_children():
				if child is CollisionShape2D and child.shape is CircleShape2D:
					child.shape.radius = 120.0 # 120px Brawl Leash

func _physics_process(delta: float) -> void:
	if not is_instance_valid(leader):
		velocity = Vector2.ZERO # Wait for promotion or die
		return 
		
	var current_speed = data.move_speed
	
	# --- 1. RUBBER BANDING CHECK ---
	var dist_to_leader = global_position.distance_to(leader.global_position)
	
	if not is_rubber_banding and dist_to_leader > MAX_DIST_FROM_LEADER:
		_start_rubber_band()
	elif is_rubber_banding and dist_to_leader < CATCHUP_DIST:
		_end_rubber_band()
		
	if is_rubber_banding:
		# Panic run to leader, ignore enemies
		formation_target = leader.global_position 
		current_speed *= SPRINT_SPEED_MULT
		brawl_target = null 
	
	# --- 2. TARGET DETERMINATION ---
	var final_dest = Vector2.ZERO
	
	if is_instance_valid(brawl_target) and not is_rubber_banding:
		# BRAWL MODE: Chase Enemy
		final_dest = brawl_target.global_position
		if attack_ai: attack_ai.force_target(brawl_target)
	else:
		# FORMATION MODE: Move to slot
		final_dest = formation_target
	
	# --- 3. MOVEMENT ---
	if final_dest != Vector2.ZERO:
		var dist = global_position.distance_to(final_dest)
		
		# Stop jittering if close enough
		if dist > 5.0:
			var dir = (final_dest - global_position).normalized()
			
			# Separation (Boids) - only if not sprinting
			var push = Vector2.ZERO
			if separation_enabled and not is_rubber_banding:
				push = _calculate_separation_push(delta)
			
			velocity = (dir * current_speed) + push
			move_and_slide()
		else:
			velocity = Vector2.ZERO

func _start_rubber_band() -> void:
	is_rubber_banding = true
	# Ghost mode to pass through walls/units
	collision_mask = 1 
	modulate.a = 0.5 # Visual ghosting effect

func _end_rubber_band() -> void:
	is_rubber_banding = false
	_setup_collision_logic() # Restore mask from BaseUnit
	modulate.a = 1.0

# --- BRAWL HANDLERS ---
func _on_brawl_started(target: Node2D) -> void:
	if not is_rubber_banding:
		brawl_target = target

func _on_brawl_stopped() -> void:
	brawl_target = null

# --- OVERRIDES ---
func die() -> void:
	# Notify leader to remove from formation
	if is_instance_valid(leader) and leader.has_method("remove_soldier"):
		leader.remove_soldier(self)
	super.die()
