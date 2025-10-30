# res://scenes/units/VikingRaider.gd
#
# Concrete implementation of the Viking Raider enemy unit.
# It starts by immediately trying to move to a fixed target.

extends BaseUnit

# --- PROVISIONAL DEFAULT ---
# This is a temporary, hard-coded target for testing Task 4.
# The GDD specifies the Great Hall as the target, so we'll use a 
# placeholder position in the center of our 50x30 grid.
const TEST_TARGET_POSITION: Vector2 = Vector2(25 * 32, 15 * 32) # (800, 480)

func _ready() -> void:
	super._ready()
	
	# Assign the target and immediately start the movement FSM
	if fsm:
		fsm.target_position = TEST_TARGET_POSITION
		fsm.change_state(UnitFSM.State.MOVE)
		print("Viking Raider initialized and moving to target: %s" % TEST_TARGET_POSITION)
