class_name ConstructionDecree
extends Resource

enum DecreeState { DRAFT, AUTHORIZED, SEALED }

@export var building_data: BuildingData
@export var target_resource_node: NodePath
@export var resolved_grid_pos: Vector2i = Vector2i(-999, -999)
@export var assigned_household_name: String = ""
@export var state: DecreeState = DecreeState.DRAFT
@export var decree_id: String = ""

func _init() -> void:
	decree_id = "dec_%d_%d" % [Time.get_unix_time_from_system(), randi() % 9999]

func get_household() -> HouseholdData:
	if not SettlementManager.current_settlement:
		return null
	for house in SettlementManager.current_settlement.households:
		if house.household_name == assigned_household_name:
			return house
	return null
