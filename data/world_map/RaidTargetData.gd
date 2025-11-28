# res://data/world_map/RaidTargetData.gd
class_name RaidTargetData
extends Resource

@export var display_name: String = "Monastery"
@export_multiline var description: String = "A small, undefended religious site."
@export var settlement_data: SettlementData

@export_group("Raid Costs")
## The base Authority cost. Set by generators or manually.
@export var raid_cost_authority: int = 1

## If -1, the system uses 'raid_cost_authority'. 
## If > -1, this value takes priority.
@export var authority_cost_override: int = -1

@export var difficulty_rating: int = 1 # 1-5 Stars

@export_group("Victory Conditions")
## Time in seconds to achieve a 'Fast' rating.
@export var par_time_seconds: int = 300 
## Maximum casualties allowed to achieve a 'Decisive' rating.
@export var decisive_casualty_limit: int = 2
