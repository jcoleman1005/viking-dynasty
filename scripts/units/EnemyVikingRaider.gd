# res://scripts/units/VikingRaider.gd
#
# Concrete implementation of the Viking Raider enemy unit.
#
# --- MODIFIED: Target position is now adjacent to the Hall ---

extends BaseUnit

# This function is called by the 'SettlementBridge' spawner
func set_attack_target(target: BaseBuilding) -> void:
	"""
	Gives the Raider its one and only goal.
	"""
	if not fsm or not is_instance_valid(target):
		push_warning("Raider FSM or target is not valid.")
		return

	# Set the node (for attacking)
	fsm.target_unit = target
	
	# --- THIS IS THE FIX ---
	# Set the position (for moving) to be one tile *below*
	# the Hall's center. This is a walkable tile, so
	# pathfinding will succeed.
	fsm.target_position = target.global_position + Vector2(0, 32)
	
	# Start the FSM
	fsm.change_state(UnitFSM.State.MOVING)
	print("Viking Raider initialized and moving to target: %s" % target.data.display_name)
