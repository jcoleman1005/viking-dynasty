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

# --- Settlement Management Signals ---
signal settlement_loaded(settlement_data: SettlementData)

# --- Unit Management Signals ---
signal player_unit_died(unit: Node2D)

# --- NEW: RTS Command Signals (GDD Section 10) ---
# Emitted by SelectionBox.gd, consumed by RTSController.gd

# Emitted on left-click or drag-release
signal select_command(select_rect: Rect2, is_box_select: bool)

# Emitted on right-click on the ground
signal move_command(target_position: Vector2)

# Emitted on right-click on an enemy
signal attack_command(target_node: Node2D)
