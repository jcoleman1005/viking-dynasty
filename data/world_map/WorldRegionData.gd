# res://data/world_map/WorldRegionData.gd
class_name WorldRegionData
extends Resource

@export var display_name: String = "New Region"
@export_multiline var description: String = "A description of this region."

# --- MODIFIED: Now a list of targets ---
@export var raid_targets: Array[RaidTargetData] = []
# --------------------------------------

@export var region_type_tag: String = "Province"
@export var yearly_income: Dictionary = {"gold": 10}

# Deprecated (Keep for temporary compatibility if needed, or delete)
# @export var target_settlement_data: SettlementData 
@export var base_authority_cost: int = 1
