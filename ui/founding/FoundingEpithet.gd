# res://ui/founding/FoundingEpithet.gd
extends Control

@onready var epithet_label := %EpithetLabel
@onready var sentence_label := %SentenceLabel
@onready var exile_label := %ExileLabel
@onready var first_act_label := %FirstActLabel
@onready var pillar_label := %PillarLabel
@onready var name_entry := %NameEntry
@onready var begin_btn := %BeginBtn

func _ready() -> void:
	var fd := FoundingSequenceManager.current_founding_data
	
	epithet_label.text = fd.founding_epithet
	sentence_label.text = "He %s, but %s." % [fd.strength_clause, fd.flaw_clause]
	
	# Exile one-liners
	match fd.exile_reason:
		"frankish": exile_label.text = "He came from Frankish lands with nothing but his people."
		"rival": exile_label.text = "He was driven out by a rival, leaving his halls to another."
		"opportunity": exile_label.text = "He sought a new name in a new land, following the call of the horizon."
	
	# First act one-liners
	match fd.first_act:
		"sworn": first_act_label.text = "His first act as Jarl was to swear an oath before he had the means to keep it."
		"challenged": first_act_label.text = "He proved himself to the hall, but made an enemy of his father's advisor."
		"generous": first_act_label.text = "He fed the poorest from his own stores, choosing loyalty over safety."
		
	# Pillar language
	match fd.father_archetype:
		"warrior": pillar_label.text = "You carry his iron and his pride."
		"builder": pillar_label.text = "You carry his patience and his restlessness."
		"diplomat": pillar_label.text = "You carry his voice and his mistrust."
		
	name_entry.text = "Bjorn" # Default
	
	begin_btn.pressed.connect(_on_begin_pressed)

func _on_begin_pressed() -> void:
	FoundingSequenceManager.current_founding_data.jarl_name = name_entry.text
	FoundingSequenceManager.advance_sequence()
