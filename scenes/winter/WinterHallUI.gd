# res://scenes/winter/WinterHallUI.gd
# Winter Hall — main Winter phase UI.
# Replaces the deprecated SeasonalCouncilUI for the Winter season.
# Shows Hall Actions remaining as the primary resource, with action buttons.
# Opens automatically when season_changed fires "Winter".
extends Control

# --- Nodes (resolved against scene tree) ---
@onready var hall_actions_label: Label   = $MarginContainer/VBoxContainer/HallActionsLabel
@onready var severity_label: Label       = $MarginContainer/VBoxContainer/SeverityLabel
@onready var actions_container: VBoxContainer = $MarginContainer/VBoxContainer/ActionsContainer
@onready var end_winter_btn: Button      = $MarginContainer/VBoxContainer/EndWinterButton

# --- Heir Training (instantiated on demand) ---
@export var HEIR_TRAINING_SCENE :PackedScene

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.hall_action_updated.connect(_refresh_hall_actions)
	end_winter_btn.pressed.connect(_on_end_winter_pressed)


func _on_season_changed(season_name: String, _context: Dictionary) -> void:
	if season_name == "Winter":
		await get_tree().process_frame
		_open()


func _open() -> void:
	_refresh_all()
	visible = true
	move_to_front()
	Loggie.msg("WinterHallUI: Opened.").domain(LogDomains.UI).info()


func _refresh_all() -> void:
	_refresh_hall_actions()
	_refresh_severity()
	_build_action_buttons()


func _refresh_hall_actions() -> void:
	var jarl := DynastyManager.current_jarl
	if not jarl:
		hall_actions_label.text = "Hall Actions: —"
		return
	hall_actions_label.text = "Hall Actions: %d / %d" % [jarl.current_hall_actions, jarl.max_hall_actions]
	end_winter_btn.disabled = false


func _refresh_severity() -> void:
	var severity_names := ["Mild", "Normal", "Harsh"]
	var idx := WinterManager.current_severity as int
	severity_label.text = "Winter Severity: %s" % severity_names[clampi(idx, 0, 2)]


func _build_action_buttons() -> void:
	# Clear previous buttons (keep End Winter, which is outside this container)
	for child in actions_container.get_children():
		child.queue_free()

	var jarl := DynastyManager.current_jarl
	var actions_remaining: int = jarl.current_hall_actions if jarl else 0

	# Heir Training
	var heir_btn := Button.new()
	heir_btn.text = "Heir Training  (1 Action)"
	heir_btn.disabled = (actions_remaining <= 0) or (jarl == null) or (jarl.get_first_available_heir() == null)
	heir_btn.pressed.connect(_on_heir_training_pressed)
	actions_container.add_child(heir_btn)

	# Legacy Projects (stub)
	var legacy_btn := Button.new()
	legacy_btn.text = "Legacy Projects  — No projects available yet"
	legacy_btn.disabled = true
	actions_container.add_child(legacy_btn)

	# New Household / Warband Recruitment (stub)
	# TODO: Warband recruitment via Hall Actions is planned here.
	# Design intent carried over from retired Card_Winter_Recruit:
	#   cost 2 Hall Actions → chance of a warband pledging service for summer,
	#   gated by a gold-by-Autumn oath (must collect 150g before Winter).
	# Wire up when warband-joining event logic is implemented.
	var household_btn := Button.new()
	household_btn.text = "New Household / Warband  — No candidates seeking shelter"
	household_btn.disabled = true
	actions_container.add_child(household_btn)


func _on_heir_training_pressed() -> void:
	var packed = HEIR_TRAINING_SCENE
	if not packed:
		Loggie.msg("WinterHallUI: Could not load HeirTrainingAction scene.").domain(LogDomains.UI).error()
		return
	var panel :Node= packed.instantiate()
	add_child(panel)


func _on_end_winter_pressed() -> void:
	visible = false
	EventBus.advance_season_requested.emit()
	Loggie.msg("WinterHallUI: End Winter pressed.").domain(LogDomains.UI).info()
