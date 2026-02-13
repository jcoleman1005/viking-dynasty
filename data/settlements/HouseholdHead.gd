class_name HouseholdHead
extends Resource

## Data representing the current head of a clan household.
## Handles narrative identity and lineage tracking.

@export var given_name: String = ""
@export var patronymic: String = "Founder"
@export var generation: int = 1
@export var age: int = 35
@export var alive: bool = true

## Narrative lineage - stores given_names of all previous heads oldest to newest
@export var ancestors: Array[String] = []
