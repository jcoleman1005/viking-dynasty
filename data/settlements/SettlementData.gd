#res://data/settlements/SettlementData.gd
# res://data/settlements/SettlementData.gd
extends Resource
class_name SettlementData

@export var treasury: Dictionary = {
	GameResources.GOLD: 0, 
	GameResources.WOOD: 0, 
	GameResources.FOOD: 0, 
	GameResources.STONE: 0
}

# --- Array of Dictionaries (Building Persistence) ---
# Format: { "resource_path": String, "x": int, "y": int, ... }
@export var placed_buildings: Array[Dictionary] = []
@export var pending_construction_buildings: Array = []
@export var warbands: Array[WarbandData] = []
@export var max_garrison_bonus: int = 0
@export var map_seed: int = 0

@export_category("Population")
@export var population_peasants: int = 10 # Free Peasants
@export var population_thralls: int = 0 # Captive Workers
@export var worker_assignments: Dictionary = {}
@export var sick_population: int = 0
## Current food rationing setting. Defaults to NORMAL (0) for backward compatibility.
@export var rationing_policy: RationingPolicy = RationingPolicy.NORMAL
# --- Stability ---
@export var has_stability_debuff: bool = false
@export var unrest: int = 0 # 0-100 scale. 100 = Rebellion.

# --- Naval State (New) ---
@export_group("Naval State")
## 0.0 (Rotting) to 1.0 (Pristine). Affects journey attrition.
@export var fleet_readiness: float = 1.0 


## Rationing Policy Enum. 
## NORMAL (0) maps to legacy behavior.
enum RationingPolicy {
	NORMAL = 0,
	HALF = 1,
	NONE = 2
}



# --- Helper Functions ---
func get_fleet_capacity() -> int:
	var capacity = 2 # Base capacity (2 Warbands)
	
	for entry in placed_buildings:
		if not entry.has("resource_path"): continue
		var res_path = entry["resource_path"]
		
		# Check for Docks/Harbors (String check for now)
		if "dock" in res_path.to_lower() or "harbor" in res_path.to_lower():
			capacity += 2
			
	return capacity
