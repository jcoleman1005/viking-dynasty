# res://scenes/founding/FoundingEpithetScreen.gd
# Screen 5 of 5 (reveal): Shows the assembled founding epithet and lets the player
# confirm their Jarl name before Year 880 begins.
extends CanvasLayer

const PILLAR_LINES: Dictionary = {
	"command":     "You carry his iron will and his sword-arm.",
	"prowess":     "You carry his iron and his battlefield fury.",
	"stewardship": "You carry his careful eye and his grain-sense.",
	"learning":    "You carry his stone-knowledge and his patient mind.",
	"diplomacy":   "You carry his silver tongue and his peace-craft.",
	"charisma":    "You carry his hall-voice and his gathered loyalty.",
}

const EXILE_LINES: Dictionary = {
	"frankish_persecution": "You came with nothing. That is not nothing.",
	"rival_jarl":           "He kept the hall. You kept the warband. That is not over.",
	"seeking_opportunity":  "No one drove you here. That is the rarest kind of freedom.",
}

const FIRST_ACT_LINES: Dictionary = {
	"oath_of_protection": "You swore to protect them before you knew what that would cost.",
	"challenged_advisor": "You cleared the old voice from your hall. Now it is truly yours.",
	"generous_gift":      "You gave half the stores away. They will remember. So will your ledger.",
}

@onready var epithet_name:  Label       = $MarginContainer/CenterContainer/ContentBox/EpithetName
@onready var sentence_rich: RichTextLabel = $MarginContainer/CenterContainer/ContentBox/SentenceLabel
@onready var exile_line:    Label       = $MarginContainer/CenterContainer/ContentBox/ContextBlock/ExileLine
@onready var first_act_line:Label       = $MarginContainer/CenterContainer/ContentBox/ContextBlock/FirstActLine
@onready var pillar_line:   Label       = $MarginContainer/CenterContainer/ContentBox/PillarLine
@onready var name_entry:    LineEdit    = $MarginContainer/CenterContainer/ContentBox/NameEntry
@onready var begin_button:  Button      = $MarginContainer/CenterContainer/ContentBox/BeginButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate()
	begin_button.pressed.connect(_on_begin_pressed)


func _populate() -> void:
	var fd := FoundingSequenceManager.current_founding_data
	var jarl := DynastyManager.current_jarl
	if not fd or not jarl:
		return

	epithet_name.text = fd.founding_epithet
	sentence_rich.text = "[i]He %s, but %s.[/i]" % [fd.father_strength_clause, fd.father_flaw_clause]
	exile_line.text    = EXILE_LINES.get(fd.exile_reason, "")
	first_act_line.text = FIRST_ACT_LINES.get(fd.first_act, "")
	pillar_line.text   = PILLAR_LINES.get(fd.boosted_stat, "")

	name_entry.placeholder_text = jarl.display_name
	name_entry.text = jarl.display_name


func _on_begin_pressed() -> void:
	var jarl := DynastyManager.current_jarl
	if jarl:
		var entered := name_entry.text.strip_edges()
		if not entered.is_empty() and entered != jarl.display_name:
			jarl.display_name = entered
			# Rebuild the epithet with the new name
			FoundingSequenceManager._assemble_founding_epithet()
	FoundingSequenceManager.complete_sequence()
