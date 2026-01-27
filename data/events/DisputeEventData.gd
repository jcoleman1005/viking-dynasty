class_name DisputeEventData
extends Resource

@export_group("Narrative")
@export var title: String = "Dispute Title"
@export_multiline var description: String = "Description of the conflict."

@export_group("Costs")
## Gold cost to settle peacefully (Wergild).
@export var gold_cost: int = 100
## Renown cost to settle by force.
@export var renown_cost: int = 25
## If true, "Force" removes a random unit instead of costing Renown (Banishment).
@export var bans_unit: bool = false
## How many Action Points (Hall Actions) this costs the Jarl.
@export var action_point_cost: int = 1

@export_group("Consequences")
## The key for the modifier applied next year if ignored (e.g., "angry_bondi").
@export var penalty_modifier_key: String = ""
## Text description of the penalty (for the tooltip).
@export var penalty_description: String = "Recruitment costs double next year."
