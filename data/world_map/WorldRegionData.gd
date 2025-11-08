# res://data/world_map/WorldRegionData.gd
#
# Defines the data for a single clickable region on the Macro Map. 
# This allows the map to be data-driven.
class_name WorldRegionData
extends Resource

## The name displayed in tooltips and UI [cite: 424]
@export var display_name: String = "New Region"

## The flavor text description shown when selected
@export_multiline var description: String = "A description of this region." # [cite: 425]

## The SettlementData.tres file to load for the RaidMission
@export var target_settlement_data: SettlementData # [cite: 426]

## The base Authority cost to launch a raid here [cite: 427]
@export var base_authority_cost: int = 1

## Flag for future conquest loop (GDD 4.D) [cite: 428, 534]
@export var is_conquered: bool = false
