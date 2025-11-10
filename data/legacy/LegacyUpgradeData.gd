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

## A unique key to identify this upgrade's effect in code.
## e.g., "UPG_TRELLEBORG", "UPG_JELLING_STONE"
@export var effect_key: String = ""

## A key to check if a prerequisite upgrade has been purchased.
@export var prerequisite_key: String = ""

## Used by the UI to disable the button after purchase.
var is_purchased: bool = false
