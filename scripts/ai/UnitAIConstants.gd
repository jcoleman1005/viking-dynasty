# res://scripts/ai/UnitAIConstants.gd
#
# Holds shared enums for the Unit AI system to break
# circular dependencies between BaseUnit and UnitFSM.
class_name UnitAIConstants

enum State { IDLE, MOVING, FORMATION_MOVING, ATTACKING }
enum Stance { DEFENSIVE, HOLD_POSITION }
