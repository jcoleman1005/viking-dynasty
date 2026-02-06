#res://data/world_map/MapState.gd
# res://data/world_map/MapState.gd
class_name MapState
extends Resource

# Dictionary mapping Region Node Names to their Data
# Format: { "Region1": WorldRegionData, "Region2": WorldRegionData }
@export var region_data_map: Dictionary = {}

# We can track global map flags here too
@export var turns_elapsed: int = 0
