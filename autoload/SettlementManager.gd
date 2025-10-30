# res://autoload/SettlementManager.gd

extends Node

var current_settlement: SettlementData
var astar_grid: AStarGrid2D
@onready var building_container: Node2D = $BuildingContainer

const TILE_SIZE: int = 32
const GRID_WIDTH: int = 50
const GRID_HEIGHT: int = 30

func _initialize_grid() -> void:
	astar_grid = AStarGrid2D.new()
	var playable_rect := Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	print("Settlement Grid Initialized.")

func load_settlement(data: SettlementData) -> void:
	if not data:
		push_error("SettlementManager: load_settlement called with null data.")
		return
	
	current_settlement = data
	_initialize_grid()
	
	for child in building_container.get_children():
		child.queue_free()

	for building_entry in current_settlement.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if building_data:
			place_building(building_data, grid_pos)
		else:
			push_error("Failed to load building resource from path: %s" % building_res_path)
	
	print("Settlement loaded with %d buildings." % building_container.get_child_count())

func place_building(building_data: BuildingData, grid_position: Vector2i) -> BaseBuilding:
	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return null
	
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	var world_pos_top_left: Vector2 = Vector2(grid_position) * astar_grid.cell_size
	var half_cell_offset: Vector2 = astar_grid.cell_size / 2.0
	new_building.global_position = world_pos_top_left + half_cell_offset
	
	building_container.add_child(new_building)
	
	if building_data.blocks_pathfinding:
		astar_grid.set_point_solid(grid_position, true)
		astar_grid.update()
		EventBus.pathfinding_grid_updated.emit(grid_position)
		
	return new_building

func deposit_loot(loot: Dictionary) -> void:
	if not current_settlement: return
	for resource_type in loot:
		if current_settlement.treasury.has(resource_type):
			current_settlement.treasury[resource_type] += loot[resource_type]
		else:
			current_settlement.treasury[resource_type] = loot[resource_type]
	EventBus.emit_signal("treasury_updated", current_settlement.treasury)
	print("Loot deposited. New treasury: %s" % current_settlement.treasury)

func attempt_purchase(item_cost: Dictionary) -> bool:
	if not current_settlement: return false
	
	for resource_type in item_cost:
		if not current_settlement.treasury.has(resource_type) or \
		current_settlement.treasury[resource_type] < item_cost[resource_type]:
			print("Purchase failed. Insufficient %s." % resource_type)
			EventBus.emit_signal("purchase_failed", "Insufficient %s" % resource_type)
			return false
			
	for resource_type in item_cost:
		current_settlement.treasury[resource_type] -= item_cost[resource_type]
	
	EventBus.emit_signal("treasury_updated", current_settlement.treasury)
	EventBus.emit_signal("purchase_successful") # Can pass item name later
	print("Purchase successful. New treasury: %s" % current_settlement.treasury)
	return true

func calculate_chunk_payout() -> Dictionary:
	# This function will be fully implemented in Task 6.
	# It is temporarily disabled to prevent dependency errors, as it relies on
	# EconomicBuildingData, which is not created until Task 4.
	if not current_settlement or current_settlement.last_visited_timestamp == 0:
		return {}

func calculate_chunk_payout() -> Dictionary:
	if not current_settlement or current_settlement.last_visited_timestamp == 0:
		return {}

	var current_time: int = Time.get_unix_time_from_system()
	var elapsed_seconds: int = current_time - current_settlement.last_visited_timestamp
	var elapsed_hours: float = float(elapsed_seconds) / 3600.0

	var total_payout: Dictionary = {}

	for building_entry in current_settlement.placed_buildings:
		var building_data: BuildingData = load(building_entry["resource_path"])
		if building_data is EconomicBuildingData:
			var eco_data: EconomicBuildingData = building_data
			var resource_type: String = eco_data.resource_type
			var generated_amount: int = floor(eco_data.accumulation_rate_per_hour * elapsed_hours)
			var capped_amount: int = min(generated_amount, eco_data.storage_cap)

			if not total_payout.has(resource_type):
				total_payout[resource_type] = 0
			total_payout[resource_type] += capped_amount
	
	if not total_payout.is_empty():
		print("Calculated chunk payout: %s" % total_payout)
	return total_payout
		push_warning("SettlementData has no resource_path, cannot save timestamp.")


func get_astar_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	if not astar_grid:
		push_error("AStarGrid is not initialized!")
		return PackedVector2Array()
	var start_id: Vector2i = Vector2i(start_pos / astar_grid.cell_size)
	var end_id: Vector2i = Vector2i(end_pos / astar_grid.cell_size)
	return astar_grid.get_point_path(start_id, end_id)
