# res://data/buildings/EconomicBuildingData.gd
extends BuildingData
class_name EconomicBuildingData

@export_group("Economic Stats")
## The type of resource this building generates (e.g., "wood", "food", "gold").
@export var resource_type: String = "wood"

## How many units of the resource are generated per hour.
@export var accumulation_rate_per_hour: float = 10.0

## The maximum amount of the resource that can be stored before collection.
@export var storage_cap: int = 100
