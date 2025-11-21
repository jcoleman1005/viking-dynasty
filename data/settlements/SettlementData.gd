# res://data/settlements/SettlementData.gd
extends Resource
class_name SettlementData

@export var treasury: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var placed_buildings: Array[Dictionary] = []
@export var pending_construction_buildings: Array = []
@export var warbands: Array[WarbandData] = []
@export var max_garrison_bonus: int = 0

# --- NEW: THRALL POPULATION ---
@export var population_peasants: int = 10 # Free Peasants
@export var population_thralls: int = 5 # Captive Workers
@export var worker_assignments: Dictionary = {} # Deprecated but kept for safe loading
# ------------------------------

@export var has_stability_debuff: bool = false
