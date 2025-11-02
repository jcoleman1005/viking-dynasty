# res://autoload/EventBus.gd
#
# A global Singleton (Autoload) that acts as a central "switchboard"
# for decoupled signal communication between major systems.


extends Node

# --- Build System Signals ---
signal build_request_made(building_data: BuildingData, grid_position: Vector2i)

# --- Pathfinding Signals ---
signal pathfinding_grid_updated(grid_position: Vector2i)

# --- Treasury & Economy Signals (Phase 2) ---
signal treasury_updated(new_treasury: Dictionary)
signal purchase_successful(item_name: String)
signal purchase_failed(reason: String)

# --- Navigation Signals (Phase 3) ---
signal scene_change_requested(scene_path: String)
signal world_map_opened()
signal raid_mission_started(target_type: String)
