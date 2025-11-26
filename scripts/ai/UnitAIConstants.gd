# res://scripts/ai/UnitAIConstants.gd
class_name UnitAIConstants
extends RefCounted

# Defines the possible states for the Unit Finite State Machine
enum State { 
	IDLE, 
	MOVING, 
	FORMATION_MOVING, 
	ATTACKING, 
	RETREATING,
	INTERACTING 
}

# Defines behavior stances
enum Stance { 
	DEFENSIVE, 
	HOLD_POSITION 
}
