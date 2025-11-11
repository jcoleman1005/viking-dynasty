# res://data/buildings/EconomicBuildingData.gd
extends BuildingData
class_name EconomicBuildingData

@export_group("Economic Stats")
## The type of resource this building generates (e.g., "wood", "food", "stone").
@export var resource_type: String = "wood"

## The fixed amount of resources generated passively per turn.
@export var fixed_payout_amount: int = 10

## The maximum amount of the resource that can be stored before collection.
@export var storage_cap: int = 100

## The max number of workers that can be assigned to gather this resource here.
@export var max_workers: int = 3
