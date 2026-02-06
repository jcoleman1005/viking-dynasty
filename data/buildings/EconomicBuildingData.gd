#res://data/buildings/EconomicBuildingData.gd
# res://data/buildings/EconomicBuildingData.gd
class_name EconomicBuildingData
extends BuildingData

@export_group("Thrall Economy")
@export var resource_type: String = "wood"

## What this building produces automatically (Peasant labor).
@export var base_passive_output: int = 50

## Extra resource generated per assigned Thrall.
@export var output_per_thrall: int = 50

## Maximum number of Thralls this building can manage.
@export var thrall_capacity: int = 5

# --- Capacity definition ---
## Maximum number of Peasants/Citizens this building can employ.
@export var peasant_capacity: int = 5

## NEW: How much this building adds to the global resource cap.
@export var storage_capacity_bonus: int = 0
