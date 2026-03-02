# res://autoload/FoundingSequenceManager.gd
# Manages the founding sequence as defined in the UI Overhaul.
extends Node

signal founding_complete(data: FoundingData)

const SCREEN_PATHS := [
	"res://ui/founding/FoundingChoice1.tscn",
	"res://ui/founding/FoundingChoice2.tscn",
	"res://ui/founding/FoundingChoice3.tscn",
	"res://ui/founding/FoundingEpithet.tscn"
]

var current_founding_data: FoundingData = null
var current_screen_index := 0
var current_screen_instance: Node = null

func begin_sequence() -> void:
	current_founding_data = FoundingData.new()
	current_screen_index = 0
	_show_screen(0)

func advance_sequence() -> void:
	if is_instance_valid(current_screen_instance):
		current_screen_instance.queue_free()
		current_screen_instance = null
		
	current_screen_index += 1
	
	if current_screen_index >= SCREEN_PATHS.size():
		_finish_sequence()
	else:
		_show_screen(current_screen_index)

func _show_screen(index: int) -> void:
	var packed = load(SCREEN_PATHS[index])
	if not packed:
		Loggie.msg("FoundingSequenceManager: Failed to load screen %d" % index).domain("UI").error()
		return
	current_screen_instance = packed.instantiate()
	get_tree().root.add_child(current_screen_instance)

func _finish_sequence() -> void:
	founding_complete.emit(current_founding_data)
	var jarl = FoundingGenerator.generate_from_founding(current_founding_data)
	DynastyManager.start_new_campaign_with_jarl(jarl)
	Loggie.msg("FoundingSequenceManager: Sequence complete.").domain("DYNASTY").info()
