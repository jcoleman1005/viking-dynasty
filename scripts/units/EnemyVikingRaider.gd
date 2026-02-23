#res://scripts/units/EnemyVikingRaider.gd
# res://scripts/units/EnemyVikingRaider.gd
#
# Concrete implementation of the Viking Raider enemy unit.
#
# --- MODIFIED: Target position is now set correctly ---

extends BaseUnit

var skip_unaware: bool = false

# This function is called by the 'SettlementBridge' spawner
func set_attack_target(target: BaseBuilding) -> void:
	"""
	Gives the Raider its one and only goal.
	"""
	if not fsm or not is_instance_valid(target):
		push_warning("Raider FSM or target is not valid.")
		return

	# Set the node (for attacking)
	fsm.objective_target = target
	
	# --- THIS IS THE FIX ---
	# Target the building's actual center.
	# The FSM will find the closest walkable spot.
	fsm.target_position = target.global_position
	# --- END FIX ---
	
	# Start the FSM
	# --- THIS IS THE FINAL FIX ---
	# Updated to use the new constants script
	fsm.change_state(UnitAIConstants.State.MOVING)
	# --- END FIX ---
	Loggie.msg("Viking Raider initialized and moving to target: %s" % target.data.display_name).domain("RTS").info()

func _deferred_setup(damage_mult: float = 1.0) -> void:
	super._deferred_setup(damage_mult)
	
	Loggie.msg("DEFERRED_SETUP: %s skip_unaware=%s setting_state=%s" % [
		name,
		str(skip_unaware),
		"SKIPPED" if skip_unaware else "UNAWARE"]
	).domain("RAID").warn()
	
	if fsm and not skip_unaware:
		fsm.change_state(UnitAIConstants.State.UNAWARE)
