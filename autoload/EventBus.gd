# res://autoload/EventBus.gd
#
# A global Singleton (Autoload) that acts as a central "switchboard"
# for decoupled signal communication between major systems.

extends Node

# --- Build System Signals ---
# TODO: Connect this signal when implementing advanced building system
signal building_right_clicked(building: Node2D) # Emitted when a placed building is right-clicked
signal building_state_changed(building: BaseBuilding, new_state: int) # Emitted when building state changes
# @warning_ignore("unused_signal")
signal build_request_made(building_data: BuildingData, grid_position: Vector2i)
# Emitted when a building is purchased and ready for cursor placement
signal building_ready_for_placement(building_data: BuildingData)
# Emitted when building placement is cancelled (should refund cost)
signal building_placement_cancelled(building_data: BuildingData)

# --- Pathfinding Signals ---
signal pathfinding_grid_updated(grid_position: Vector2i)

# --- Treasury & Economy Signals (Phase 2) ---
signal treasury_updated(new_treasury: Dictionary)
signal purchase_successful(item_name: String)
signal purchase_failed(reason: String)

# --- Navigation Signals (Phase 3) ---
# MODIFIED: Now emits a string KEY name, not a full path.
signal scene_change_requested(scene_key: String)
signal world_map_opened()
signal raid_mission_started(target_type: String)

# --- Settlement Management Signals ---
signal settlement_loaded(settlement_data: SettlementData)

# --- Unit Management Signals ---
signal player_unit_died(unit: Node2D)
signal worker_management_toggled()
signal dynasty_view_requested()
# --- NEW: RTS Command Signals (GDD Section 10) ---
# Emitted by SelectionBox.gd, consumed by RTSController.gd

# Emitted on left-click or drag-release
signal select_command(select_rect: Rect2, is_box_select: bool)

# Emitted on right-click on the ground
signal move_command(target_position: Vector2)

# Emitted on right-click on an enemy
signal attack_command(target_node: Node2D)

# --- NEW: Emitted on right-click-and-drag ---
signal formation_move_command(target_position: Vector2, direction_vector: Vector2)
signal interact_command(target: Node2D)
# --- NEW: Keyboard Commands (Refactor Step) ---
# Emitted when 0-9 is pressed. is_assigning = true if CTRL is held.
signal control_group_command(group_index: int, is_assigning: bool)

# Emitted when formation keys (F1-F4) are pressed.
# Passes the integer value of the Enum (0=Line, 1=Column, etc.)
signal formation_change_command(formation_type: int)


# --- NEW: Event System Flow Control ---
signal event_system_finished()

# --- NEW: Succession Crisis System ---
signal succession_choices_made(renown_choice: String, gold_choice: String)
# --- NEW: Camera Control ---
# Emitted by UI to lock/unlock the RTS camera (prevent zoom/pan while in menus)
signal camera_input_lock_requested(is_locked: bool)

# --- NEW: Game Loop Signals ---
signal end_year_requested()


signal building_selected(building: BaseBuilding)
signal building_deselected()
signal request_worker_assignment(target_building: BaseBuilding)
signal request_worker_removal(target_building: BaseBuilding)
