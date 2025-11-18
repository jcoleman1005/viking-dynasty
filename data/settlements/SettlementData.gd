extends Resource
class_name SettlementData

@export var treasury: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}

# Active Buildings
@export var placed_buildings: Array[Dictionary] = []

# Pending Blueprints
@export var pending_construction_buildings: Array = []

# Garrison
@export var warbands: Array[WarbandData] = []
@export var max_garrison_bonus: int = 0

# --- NEW: Phase 2 Population Data ---
@export_group("Population & Labor")
## Total population available for work assignments.
@export var population_total: int = 10

## Current worker assignments for the year.
## Keys: "construction", "food", "wood", "stone", "gold"
@export var worker_assignments: Dictionary = {
	"construction": 0,
	"food": 0,
	"wood": 0,
	"stone": 0,
	"gold": 0
}
# ------------------------------------

@export var has_stability_debuff: bool = false
