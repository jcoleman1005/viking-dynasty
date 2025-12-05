# res://scripts/units/SquadSoldier.gd
class_name SquadSoldier
extends BaseUnit

var leader: SquadLeader
var formation_target: Vector2 = Vector2.ZERO
var brawl_target: Node2D = null
var is_rubber_banding: bool = false

const MAX_DIST_FROM_LEADER = 300.0
const CATCHUP_DIST = 80.0
const SPRINT_SPEED_MULT = 2.5

func _ready() -> void:
	separation_force = 80.0 
	separation_radius = 25.0
	separation_enabled = true
	super._ready()
	if fsm: 
		fsm.set_script(null)
		fsm = null
	if attack_ai:
		attack_ai.attack_started.connect(func(t): if not is_rubber_banding: brawl_target = t)
		attack_ai.attack_stopped.connect(func(): brawl_target = null)
		if attack_ai.detection_area:
			for c in attack_ai.detection_area.get_children():
				if c is CollisionShape2D and c.shape is CircleShape2D: c.shape.radius = 120.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(leader):
		velocity = Vector2.ZERO
		return
		
	var speed = data.move_speed
	var dist_leader = global_position.distance_to(leader.global_position)
	
	if not is_rubber_banding and dist_leader > MAX_DIST_FROM_LEADER:
		is_rubber_banding = true
		collision_mask = 1
		modulate.a = 0.5
	elif is_rubber_banding and dist_leader < CATCHUP_DIST:
		is_rubber_banding = false
		_setup_collision_logic()
		modulate.a = 1.0
		
	if is_rubber_banding:
		brawl_target = null
		speed *= SPRINT_SPEED_MULT
	
	var final_dest = formation_target
	var stop_dist = 5.0
	
	if is_instance_valid(brawl_target) and not is_rubber_banding:
		final_dest = brawl_target.global_position
		
		# --- RESTORED: Smart Stop Distance ---
		var range_limit = data.attack_range
		if brawl_target is BaseBuilding or (brawl_target.name == "Hitbox" and brawl_target.get_parent() is BaseBuilding):
			range_limit = data.building_attack_range
			
		var r_target = _get_radius(brawl_target)
		stop_dist = r_target + range_limit - 5.0
		if stop_dist < 5.0: stop_dist = 5.0
		
		if attack_ai: attack_ai.force_target(brawl_target)
		# -------------------------------------
	
	if final_dest != Vector2.ZERO:
		var dist = global_position.distance_to(final_dest)
		if dist > stop_dist:
			var dir = (final_dest - global_position).normalized()
			var push = Vector2.ZERO
			if separation_enabled and not is_rubber_banding: push = _calculate_separation_push(delta)
			velocity = (dir * speed) + push
			move_and_slide()
		else:
			velocity = Vector2.ZERO

func _get_radius(node: Node2D) -> float:
	if node.name == "Hitbox" and node.get_parent() is BaseBuilding:
		var b = node.get_parent()
		if b.data: return (min(b.data.grid_size.x, b.data.grid_size.y) * 32.0) / 2.0
	return 15.0
