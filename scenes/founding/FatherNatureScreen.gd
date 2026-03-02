# res://scenes/founding/FatherNatureScreen.gd
# Screen 1 of 4: Choose your father's archetype.
# Three cards are shown — each displays an assembled sentence from a random strength
# and flaw clause. The player's selection maps to a boosted_stat and penalised_stat.
extends CanvasLayer

# ---- Clause pools ----

const WARRIOR_STRENGTH: Array[Dictionary] = [
	{"text": "never lost a battle",             "stat": "command"},
	{"text": "trained his men harder than any jarl alive", "stat": "command"},
	{"text": "was feared across three fjords",  "stat": "prowess"},
]

const BUILDER_STRENGTH: Array[Dictionary] = [
	{"text": "could stretch a winter's grain to feed twice the mouths", "stat": "stewardship"},
	{"text": "knew every timber and stone",                             "stat": "learning"},
	{"text": "planned three winters ahead",                            "stat": "stewardship"},
]

const DIPLOMAT_STRENGTH: Array[Dictionary] = [
	{"text": "could end a blood feud with three words", "stat": "diplomacy"},
	{"text": "made alliances that lasted generations",  "stat": "diplomacy"},
	{"text": "could silence a room with a single word", "stat": "charisma"},
]

const SHARED_FLAWS: Array[Dictionary] = [
	{"text": "carried a grudge to his dying day",         "stat": "diplomacy"},
	{"text": "never forgave a slight",                    "stat": "charisma"},
	{"text": "drank away half his winters",               "stat": "stewardship"},
	{"text": "spent gold like it grew on the fjord",      "stat": "stewardship"},
	{"text": "trusted no man's word over his own ledger", "stat": "learning"},
	{"text": "his own men questioned his nerve",          "stat": "prowess"},
]

# ---- State ----

var _selected_archetype: String = ""
var _cards: Array[Dictionary] = []  # [{archetype, strength, flaw, boosted_stat, penalised_stat}]
var _card_buttons: Array[Button] = []
var _confirm_button: Button

# ---- Lifecycle ----

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_cards()
	_populate_ui()


func _build_cards() -> void:
	var flaw := SHARED_FLAWS[randi() % SHARED_FLAWS.size()]

	var archetypes := [
		{"archetype": "warrior",   "label": "The Warrior",   "pool": WARRIOR_STRENGTH},
		{"archetype": "builder",   "label": "The Builder",   "pool": BUILDER_STRENGTH},
		{"archetype": "diplomat",  "label": "The Diplomat",  "pool": DIPLOMAT_STRENGTH},
	]

	for entry in archetypes:
		var strength := entry["pool"][randi() % entry["pool"].size()] as Dictionary
		# Each archetype can share the same flaw, or draw a unique one
		var card_flaw := SHARED_FLAWS[randi() % SHARED_FLAWS.size()]
		_cards.append({
			"archetype":     entry["archetype"],
			"label":         entry["label"],
			"strength":      strength,
			"flaw":          card_flaw,
			"boosted_stat":  strength["stat"],
			"penalised_stat": card_flaw["stat"],
		})


func _populate_ui() -> void:
	var title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
	if title_label:
		title_label.text = "Your Father's Nature"

	var card_container: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/CardContainer")
	if not card_container:
		return

	for i in _cards.size():
		var card_data := _cards[i]

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		var archetype_label := Label.new()
		archetype_label.text = card_data["label"]
		archetype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(archetype_label)

		var desc := RichTextLabel.new()
		desc.bbcode_enabled = true
		desc.fit_content = true
		desc.text = '[color=#FFD700][font_size=22]He [b]%s[/b], but [i]%s[/i].[/font_size][/color]' % [card_data["strength"]["text"], card_data["flaw"]["text"]]
		vbox.add_child(desc)

		var btn := Button.new()
		btn.text = "Choose"
		var idx := i  # capture for closure
		btn.pressed.connect(func(): _on_card_selected(idx))
		_card_buttons.append(btn)
		vbox.add_child(btn)

		card_container.add_child(panel)

	_confirm_button = get_node_or_null("MarginContainer/VBoxContainer/ConfirmButton")
	if _confirm_button:
		_confirm_button.disabled = true
		_confirm_button.pressed.connect(_on_confirm_pressed)


# ---- Handlers ----

func _on_card_selected(index: int) -> void:
	_selected_archetype = _cards[index]["archetype"]

	var fd := FoundingSequenceManager.current_founding_data
	fd.father_archetype    = _cards[index]["archetype"]
	fd.father_strength_clause = _cards[index]["strength"]["text"]
	fd.father_flaw_clause  = _cards[index]["flaw"]["text"]
	fd.boosted_stat        = _cards[index]["boosted_stat"]
	fd.penalised_stat      = _cards[index]["penalised_stat"]

	# Visual feedback — highlight selected card
	for i in _card_buttons.size():
		_card_buttons[i].disabled = (i == index)

	if _confirm_button:
		_confirm_button.disabled = false


func _on_confirm_pressed() -> void:
	if _selected_archetype.is_empty():
		return
	FoundingSequenceManager.advance_sequence()
