# res://scripts/units/PlayerVikingRaider.gd
#
# Player-controlled Viking Raider unit.
# This script is now much simpler. It just inherits all the
# complex logic from BaseUnit and the FSM.

extends BaseUnit
class_name PlayerVikingRaider

func _ready() -> void:
	# --- FIX: Add to group BEFORE super._ready() ---
	# BaseUnit._ready() checks this group to apply the Thor damage buff.
	add_to_group("player_units")
	# -----------------------------------------------
	
	# Call parent _ready to initialize base unit systems (Health, AI, FSM)
	super._ready()
	
	Loggie.msg("PlayerVikingRaider '%s' initialized and ready for RTS control" % name).domain("RTS").info()

# We override the command_attack function just to add a print statement,
# then we call super.command_attack(target) to let the Base_Unit and FSM
# handle the *actual* logic correctly.
func command_attack(target: Node2D) -> void:
	if not fsm or not is_instance_valid(target):
		push_warning("Player Raider FSM or target is not valid.")
		return

	Loggie.msg("Player Viking Raider '%s' attacking %s" % [name, target.name]).domain("RTS").info()

	# Pass the command to the base class, which will pass it to the FSM
	super.command_attack(target)

# Override die method to handle player unit death
func die() -> void:
	"""Handle player unit death with proper cleanup"""
	# Remove from player units group
	remove_from_group("player_units")
	
	# Notify other systems about unit death
	EventBus.emit_signal("player_unit_died", self)
	
	Loggie.msg("Player Viking Raider '%s' has fallen in battle!" % name).domain("RTS").info()
	
	# Call parent die method
	super.die()
