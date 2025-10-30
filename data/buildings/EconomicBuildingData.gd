# res://data/buildings/EconomicBuildingData.gd
extends BuildingData
class_name EconomicBuildingData

@export_group("Economic Stats")
## The type of resource this building generates (e.g., "wood", "food", "gold").
@export var resource_type: String = "wood"

## The fixed amount of resources generated after each successful attack.
@export var fixed_payout_amount: int = 10

## The maximum amount of the resource that can be stored before collection.
@export var storage_cap: int = 100
