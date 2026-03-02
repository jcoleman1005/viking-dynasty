# res://ui/founding/FoundingChoice1.gd
extends Control

# ---- Clause pools ----

const WARRIOR_STRENGTH: Array[Dictionary] = [
	{"text": "never lost a battle",             "stat": "command", "seed": "Iron-Handed"},
	{"text": "trained his men harder than any jarl alive", "stat": "command", "seed": "the Unyielding"},
	{"text": "was feared across three fjords",  "stat": "prowess", "seed": "the Feared"},
	{"text": "fought at the front of every raid", "stat": "prowess", "seed": "the Bold"},
	{"text": "had never been bested in single combat", "stat": "prowess", "seed": "the Unbroken"},
]

const BUILDER_STRENGTH: Array[Dictionary] = [
	{"text": "could stretch a winter's grain to feed twice the mouths", "stat": "stewardship", "seed": "the Provider"},
	{"text": "knew every timber and stone in the settlement",           "stat": "stewardship", "seed": "the Builder"},
	{"text": "planned three winters ahead",                            "stat": "learning",    "seed": "the Far-Sighted"},
	{"text": "kept records no other jarl bothered with",               "stat": "learning",    "seed": "the Learned"},
	{"text": "never let a harvest go to waste",                        "stat": "stewardship", "seed": "the Careful"},
]

const DIPLOMAT_STRENGTH: Array[Dictionary] = [
	{"text": "could end a blood feud with three words",   "stat": "diplomacy", "seed": "the Peacemaker"},
	{"text": "made alliances that lasted generations",    "stat": "diplomacy", "seed": "the Alliance-Maker"},
	{"text": "could silence a room with a single word",   "stat": "charisma",  "seed": "the Silver-Tongued"},
	{"text": "inspired loyalty in men who hated each other", "stat": "charisma", "seed": "the Beloved"},
	{"text": "was welcomed at every jarl's table",        "stat": "diplomacy", "seed": "the Well-Travelled"},
]

const SHARED_FLAWS: Array[Dictionary] = [
	{"text": "carried a grudge to his dying day",         "stat": "diplomacy"},
	{"text": "never forgave a slight",                    "stat": "charisma"},
	{"text": "drank away half his winters",               "stat": "stewardship"},
	{"text": "spent gold like it grew on the fjord",      "stat": "stewardship"},
	{"text": "trusted no man's word over his own ledger", "stat": "diplomacy"},
	{"text": "his own men questioned his nerve",          "stat": "command"},
	{"text": "could never sit still long enough to plan", "stat": "learning"},
]

# ---- State ----

enum Beat { ARCHE_CHOICE, STRENGTH_CHOICE, FLAW_CHOICE, READY }
var current_beat := Beat.ARCHE_CHOICE

@onready var strength_slot := %StrengthSlot
@onready var flaw_slot := %FlawSlot
@onready var archetype_row := %ArchetypeRow
@onready var clause_panel := %ClausePanel
@onready var commit_btn := %CommitBtn

var selected_archetype := ""
var selected_strength := {}
var selected_flaw := {}

func _ready() -> void:
	# Connect signals
	archetype_row.get_node("Warrior").pressed.connect(_on_archetype_selected.bind("warrior"))
	archetype_row.get_node("Builder").pressed.connect(_on_archetype_selected.bind("builder"))
	archetype_row.get_node("Diplomat").pressed.connect(_on_archetype_selected.bind("diplomat"))
	commit_btn.pressed.connect(_on_commit_pressed)
	
	_update_beat_ui()

func _update_beat_ui() -> void:
	match current_beat:
		Beat.ARCHE_CHOICE:
			archetype_row.show()
			clause_panel.hide()
			commit_btn.hide()
			strength_slot.modulate = Color(1, 1, 1, 0.3)
			flaw_slot.modulate = Color(1, 1, 1, 0.3)
		Beat.STRENGTH_CHOICE:
			archetype_row.hide()
			clause_panel.show()
			_populate_clauses(_get_strength_pool())
			strength_slot.modulate = Color(1, 1, 1, 1.0)
			flaw_slot.modulate = Color(1, 1, 1, 0.3)
		Beat.FLAW_CHOICE:
			archetype_row.hide()
			clause_panel.show()
			_populate_clauses(SHARED_FLAWS)
			strength_slot.modulate = Color(1, 1, 1, 0.7)
			flaw_slot.modulate = Color(1, 1, 1, 1.0)
		Beat.READY:
			archetype_row.hide()
			clause_panel.hide()
			commit_btn.show()
			strength_slot.modulate = Color(1, 1, 1, 1.0)
			flaw_slot.modulate = Color(1, 1, 1, 1.0)

func _on_archetype_selected(archetype: String) -> void:
	selected_archetype = archetype
	current_beat = Beat.STRENGTH_CHOICE
	_update_beat_ui()

func _populate_clauses(pool: Array[Dictionary]) -> void:
	for child in clause_panel.get_children():
		child.queue_free()
		
	for data in pool:
		var btn = Button.new()
		btn.text = data["text"]
		btn.pressed.connect(_on_clause_selected.bind(data))
		clause_panel.add_child(btn)

func _on_clause_selected(data: Dictionary) -> void:
	if current_beat == Beat.STRENGTH_CHOICE:
		selected_strength = data
		strength_slot.get_node("Label").text = data["text"]
		current_beat = Beat.FLAW_CHOICE
	elif current_beat == Beat.FLAW_CHOICE:
		selected_flaw = data
		flaw_slot.get_node("Label").text = data["text"]
		current_beat = Beat.READY
		
	_update_beat_ui()

func _get_strength_pool() -> Array[Dictionary]:
	match selected_archetype:
		"warrior": return WARRIOR_STRENGTH
		"builder": return BUILDER_STRENGTH
		"diplomat": return DIPLOMAT_STRENGTH
	return []

func _on_commit_pressed() -> void:
	var fd := FoundingSequenceManager.current_founding_data
	fd.father_archetype = selected_archetype
	fd.strength_clause = selected_strength["text"]
	fd.strength_stat = selected_strength["stat"]
	fd.flaw_clause = selected_flaw["text"]
	fd.flaw_stat = selected_flaw["stat"]
	fd.founding_epithet = FoundingGenerator.assemble_epithet(fd)
	
	FoundingSequenceManager.advance_sequence()
