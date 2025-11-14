# res://data/characters/JarlHeirData.gd
class_name JarlHeirData
extends Resource

enum HeirStatus {
	Available,
	OnExpedition,
	MarriedOff,
	LostAtSea,
	Deceased,
	Maimed # Added Maimed status per design doc
}

@export_group("Identity")
@export var display_name: String = "New Heir"
@export var age: int = 16
@export var gender: String = "Male" # "Male", "Female"
@export var portrait: Texture2D
@export var is_designated_heir: bool = false

@export_group("Status")
@export var status: HeirStatus = HeirStatus.Available
@export var expedition_years_remaining: int = 0

@export_group("Skills & Traits")
@export var command: int = 8
@export var stewardship: int = 8
@export var learning: int = 8
@export var prowess: int = 8
@export var traits: Array[JarlTraitData] = []
## The innate genetic trait (e.g., Strong, Frail) separate from learned traits
@export var genetic_trait: JarlTraitData
