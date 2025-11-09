# res://scripts/units/EnemyVikingRaider.gd
#
# Concrete implementation of the Viking Raider enemy unit.
#
# --- MODIFIED: Target position is now set correctly ---

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
	# Target the building's actual center.
	# The FSM will find the closest walkable spot.
	fsm.target_position = target.global_position
	# --- END FIX ---
	
	# Start the FSM
	fsm.change_state(UnitFSM.State.MOVING)
	print("Viking Raider initialized and moving to target: %s" % target.data.display_name)
