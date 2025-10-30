# res://autoload/EventBus.gd
#
# A global Singleton (Autoload) that acts as a central "switchboard"
# for decoupled signal communication between major systems.


extends Node

# Emitted by the UI, listened for by the SettlementManager.
signal build_request_made(building_data: BuildingData, grid_position: Vector2i)

# --- ADDED ---
# Emitted by the SettlementManager when a wall is placed.
# Listened for by any unit's FSM to trigger a re-path.
signal pathfinding_grid_updated(grid_position: Vector2i)
