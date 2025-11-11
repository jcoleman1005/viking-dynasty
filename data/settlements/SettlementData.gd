extends Resource
class_name SettlementData

@export var treasury: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}

# Active Buildings
# Structure: {"resource_path": "res://...", "grid_position": Vector2i(x, y)}
@export var placed_buildings: Array[Dictionary] = []

# --- NEW: Phase 1.3 Blueprint Tracking ---
# Stores buildings that are currently blueprints or under construction
# Structure: {"resource_path": "res://...", "grid_position": Vector2i(x, y), "progress": 0}
@export var pending_construction_buildings: Array = []
# -----------------------------------------

# Stores unit type (path) and count (int)
@export var garrisoned_units: Dictionary = {}

@export var has_stability_debuff: bool = false

@export var max_garrison_bonus: int = 0
