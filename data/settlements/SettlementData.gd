extends Resource
class_name SettlementData

@export var treasury: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var last_visited_timestamp: int = 0

# Stores building data and position. Structure:
# {"resource_path": "res://...", "grid_position": Vector2i(x, y)}
@export var placed_buildings: Array[Dictionary] = []
