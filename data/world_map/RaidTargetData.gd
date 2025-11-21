# res://data/world_map/RaidTargetData.gd
class_name RaidTargetData
extends Resource

@export var display_name: String = "Monastery"
@export var description: String = "A small, undefended religious site."
@export var settlement_data: SettlementData

@export var raid_cost_authority: int = 1
@export var difficulty_rating: int = 1 # 1-5 Stars
