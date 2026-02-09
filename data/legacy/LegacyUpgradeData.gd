#res://data/legacy/LegacyUpgradeData.gd
# res://data/legacy/LegacyUpgradeData.gd
#
# Defines a permanent, one-time dynasty upgrade.
# These are purchased in the "Legacy" tab of the Storefront
# and cost Renown and Authority.
class_name LegacyUpgradeData
extends Resource

## The name displayed in the Storefront UI.
@export var display_name: String = "New Legacy Upgrade"

## The icon shown next to the upgrade name in the UI.
@export var icon: Texture2D

## The description shown in a tooltip or in the UI.
@export_multiline var description: String = "A permanent dynasty upgrade."

## The cost in Jarl's Renown.
@export var renown_cost: int = 100

## The cost in Jarl's Authority.
@export var authority_cost: int = 1

# --- NEW: Progress System ---
@export_group("Progress")
@export var required_progress: int = 1
@export var current_progress: int = 0
# --- END NEW ---

## A unique key to identify this upgrade's effect in code.
## e.g., "UPG_TRELLEBORG", "UPG_JELLING_STONE"
@export var effect_key: String = ""

## A key to check if a prerequisite upgrade has been purchased.
@export var prerequisite_key: String = ""

## 'is_purchased' is now a calculated variable, not stored.
var is_purchased: bool:
	get:
		return current_progress >= required_progress
