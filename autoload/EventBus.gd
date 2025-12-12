# res://autoload/EventBus.gd
extends Node

# --- Build System Signals ---
signal building_right_clicked(building: Node2D)
signal building_state_changed(building: BaseBuilding, new_state: int)
signal build_request_made(building_data: BuildingData, grid_position: Vector2i)
signal building_ready_for_placement(building_data: BuildingData)
signal building_placement_cancelled(building_data: BuildingData)

# --- Inspector Signals ---
signal building_selected(building: BaseBuilding)
signal building_deselected()
signal request_worker_assignment(target_building: BaseBuilding)
signal request_worker_removal(target_building: BaseBuilding)

# --- Pathfinding Signals ---
signal pathfinding_grid_updated(grid_position: Vector2i)

# --- Treasury & Economy Signals ---
signal treasury_updated(new_treasury: Dictionary)
signal purchase_successful(item_name: String)
signal purchase_failed(reason: String)
signal raid_loot_secured(type: String, amount: int)
# --- Navigation Signals ---
signal scene_change_requested(scene_key: String)
signal world_map_opened()
signal raid_mission_started(target_type: String)

# --- Settlement Management Signals ---
signal settlement_loaded(settlement_data: SettlementData)

# --- Unit Management Signals ---
signal player_unit_died(unit: Node2D)
# --- NEW: Unit Spawn Signal ---
signal player_unit_spawned(unit: Node2D)
# ------------------------------
signal worker_management_toggled()
signal dynasty_view_requested()

# --- RTS Command Signals ---
signal select_command(select_rect: Rect2, is_box_select: bool)
signal move_command(target_position: Vector2)
signal attack_command(target_node: Node2D)
signal formation_move_command(target_position: Vector2, direction_vector: Vector2)
signal interact_command(target: Node2D)
signal pillage_command(target_node: Node2D)  # Steal Loot (Enemy)

# --- Keyboard Commands ---
signal control_group_command(group_index: int, is_assigning: bool)
signal formation_change_command(formation_type: int)

# --- Event System ---
signal event_system_finished()
signal succession_choices_made(renown_choice: String, gold_choice: String)

# --- Camera Control ---
signal camera_input_lock_requested(is_locked: bool)

# --- Game Loop Signals ---
signal end_year_requested()

signal floating_text_requested(text: String, world_position: Vector2, color: Color)
