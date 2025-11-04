# res://scripts/units/PlayerVikingRaider.gd
#
# Player-controlled Viking Raider unit with full RTS integration.
# Extends BaseUnit to inherit all core unit functionality and adds
# player-specific behaviors for selection, command, and group management.

extends BaseUnit
class_name PlayerVikingRaider

func _ready() -> void:
	# Call parent _ready first to initialize base unit systems
	super._ready()
	
	# Add to player units group for RTS selection and control
	add_to_group("player_units")
	
	# Initialize player-specific behaviors
	_setup_player_behaviors()
	
	print("PlayerVikingRaider '%s' initialized and ready for RTS control" % name)

func _setup_player_behaviors() -> void:
	"""Initialize player-specific unit behaviors and properties"""
	# Ensure the unit can be selected and commanded
	# The BaseUnit already provides the necessary methods:
	# - command_move_to()
	# - command_attack() 
	# - set_selected()
	
	# Set any player-specific properties
	if data:
		print("Player Viking Raider ready: %s (Health: %d)" % [data.display_name, current_health])

# Override command methods to add player-specific feedback and behavior
func command_move_to(target_pos: Vector2) -> void:
	"""Enhanced move command with player feedback"""
	print("Player Viking Raider '%s' moving to position %s" % [name, target_pos])
	super.command_move_to(target_pos)

func command_attack(target: Node2D) -> void:
	"""Enhanced attack command with player feedback"""
	if not fsm or not is_instance_valid(target):
		push_warning("Player Raider FSM or target is not valid.")
		return

	print("Player Viking Raider '%s' attacking %s" % [name, target.name])

	# --- Logic copied from EnemyVikingRaider ---
	# Set the node (for attacking)
	fsm.target_unit = target
	
	# Set the position (for moving) to be adjacent to the target
	# This ensures pathfinding can succeed. Adjust offset as needed.
	fsm.target_position = target.global_position + Vector2(0, 32) 
	
	# Start the FSM
	fsm.change_state(UnitFSM.State.MOVING)
	# ---------------------------------------------

# Override selection methods to provide enhanced player feedback
func set_selected(selected: bool) -> void:
	"""Enhanced selection with player-specific visual feedback"""
	super.set_selected(selected)
	
	if selected:
		# Could add player-specific selection effects here
		# e.g., special sound effects, enhanced visual indicators
		pass
	else:
		# Handle deselection
		pass

# Player-specific utility methods
func get_unit_status() -> Dictionary:
	"""Get comprehensive unit status for UI display"""
	return {
		"name": name,
		"display_name": data.display_name if data else "Unknown",
		"health": current_health,
		"max_health": data.max_health if data else 100,
		"is_selected": is_selected,
		"current_state": fsm.current_state if fsm else "None",
		"position": global_position
	}

func is_player_controlled() -> bool:
	"""Identify this as a player-controlled unit"""
	return true

# Override die method to handle player unit death
func die() -> void:
	"""Handle player unit death with proper cleanup"""
	# Remove from player units group
	remove_from_group("player_units")
	
	# Notify other systems about unit death
	EventBus.emit_signal("player_unit_died", self)
	
	print("Player Viking Raider '%s' has fallen in battle!" % name)
	
	# Call parent die method
	super.die()
