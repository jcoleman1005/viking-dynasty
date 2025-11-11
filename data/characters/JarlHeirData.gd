# res://data/characters/JarlHeirData.gd
#
# Defines the data for a single heir in the dynasty.
# This allows heirs to be "spent" or go on missions.
class_name JarlHeirData
extends Resource

enum HeirStatus {
	Available,
	OnExpedition,
	MarriedOff,
	LostAtSea,
	Deceased
}

## The heir's name.
@export var display_name: String = "New Heir"

## The heir's age.
@export var age: int = 16

## The heir's current status.
@export var status: HeirStatus = HeirStatus.Available

## If on expedition, how many "years" remain.
@export var expedition_years_remaining: int = 0

# --- NEW: Heir Skills & Traits ---
@export_group("Skills & Traits")
@export var command: int = 8
@export var stewardship: int = 8
@export var learning: int = 8
@export var prowess: int = 8
@export var traits: Array[JarlTraitData] = []
# --- END NEW ---
