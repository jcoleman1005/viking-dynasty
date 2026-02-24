#res://data/missions/RaidResultData.gd
### FILE: res://data/missions/RaidResultData.gd ###
class_name RaidResultData
extends Resource

## Stores loot collected, using GameResources keys (e.g., "gold", "food").
@export var loot: Dictionary = {}

## Stores the total loot available on the map regardless of what was collected.
@export var potential_loot: Dictionary = {}

## List of UnitData resources representing casualties taken by the player.
@export var casualties: Array[UnitData] = []

## "victory", "retreat", or "defeat"
@export var outcome: String = "neutral" 

## "Standard", "Decisive", "Pyrrhic"
@export var victory_grade: String = "Standard"

## Renown specifically earned or lost due to mission bonuses/penalties.
@export var renown_earned: int = 0
