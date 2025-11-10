# res://data/events/EventData.gd
#
# Defines a single, self-contained story event.
# This resource is the core of the "Full Event System" (Phase 3b).
# It is designed to be created and edited by designers in the Inspector.
class_name EventData
extends Resource

# --- The nested "class EventChoice" definition has been REMOVED ---

@export_group("Event Display")
## The title of the event window.
@export var title: String = "An Event Occurs"
## The main story text for the event.
@export_multiline var description: String = "Event description..."
## An optional icon or portrait for the event.
@export var portrait: Texture2D

@export_group("Event Triggering")
## The unique ID for this event.
@export var event_id: String = "unique_event_id"
## If true, this event can only fire once per campaign.
@export var is_unique: bool = true
## The base chance (0.0 to 1.0) for this event to fire when its
## conditions are met.
@export var base_chance: float = 0.5
## An array of prerequisite event_ids that must have fired
## *before* this event can be considered.
@export var prerequisites: Array[String] = []

@export_group("Event Conditions")
## Conditions related to the Jarl's stats.
@export var min_stewardship: int = -1
@export var min_command: int = -1
@export var min_prowess: int = -1
@export var min_renown: int = -1
## Conditions related to the Jarl's traits.
@export var must_have_trait: String = ""
@export var must_not_have_trait: String = ""
## Conditions related to the dynasty.
@export var min_available_heirs: int = -1
## Conditions related to the game world.
@export var min_conquered_regions: int = -1

@export_group("Event Choices")
## The array of choices to present to the player.
## This now correctly references the external EventChoice resource.
@export var choices: Array[EventChoice] = []
