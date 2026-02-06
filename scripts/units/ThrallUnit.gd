#res://scripts/units/ThrallUnit.gd
class_name ThrallUnit
extends BaseUnit

var assigned_leader: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	# Thralls are slow but carry a lot (defined in their UnitData usually)
	# For now, we ensure they don't fight back
	if fsm:
		fsm.change_state(UnitAIConstants.State.IDLE)

func _physics_process(delta: float) -> void:
	# Passive Logic: Baggage Train Movement
	# If we have a leader, we drift towards our assigned slot behind them
	if is_instance_valid(assigned_leader):
		_process_baggage_movement(delta)
	else:
		super._physics_process(delta)

func _process_baggage_movement(delta: float) -> void:
	# Calculate where we should be relative to the leader
	# We use the leader's global position + our random offset, rotated by leader's facing
	# Note: Leader facing isn't explicitly stored, so we use velocity or last_facing
	var target_pos = assigned_leader.global_position + follow_offset
	
	var dist = global_position.distance_to(target_pos)
	if dist > 10.0:
		var dir = (target_pos - global_position).normalized()
		# Thralls match leader speed roughly, but rubber band if far behind
		var move_speed = data.move_speed
		if dist > 200.0: move_speed *= 1.5 # Catch up sprint
		
		velocity = dir * move_speed
		move_and_slide()
