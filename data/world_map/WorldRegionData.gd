# res://data/world_map/WorldRegionData.gd
#
# Defines the data for a single clickable region on the Macro Map.
# This allows the map to be data-driven.
class_name WorldRegionData
extends Resource

## The name displayed in tooltips and UI
@export var display_name: String = "New Region"

## The flavor text description shown when selected
@export_multiline var description: String = "A description of this region."

## The SettlementData.tres file to load for the RaidMission
@export var target_settlement_data: SettlementData

## The base Authority cost to launch a raid here
@export var base_authority_cost: int = 1

# --- NEW: Phase 2 Properties ---

## A tag for the "soft-guide" system (e.g., "Monastery", "Settlement", "Ruins")
@export var region_type_tag: String = "Settlement"

## The passive, yearly income this region provides *after* being subjugated.
@export var yearly_income: Dictionary = {"gold": 10}

# --- REMOVED ---
# @export var is_conquered: bool = false
# This is now tracked on JarlData.gd for better persistence.
