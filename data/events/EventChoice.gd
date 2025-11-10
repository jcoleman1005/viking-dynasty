# res://data/events/EventChoice.gd
#
# Defines a single choice for a story event.
# This resource is designed to be embedded within an EventData resource.
class_name EventChoice
extends Resource

## The text displayed on the button for this choice.
@export var choice_text: String = "Choice Text"

## A tooltip to show what the likely (or guaranteed) outcome is.
@export var tooltip_text: String = "Tooltip"

## A unique key (e.g., "CHOICE_ACCEPT", "CHOICE_DECLINE")
## The EventManager will use this key to apply the correct consequence.
@export var effect_key: String = ""
