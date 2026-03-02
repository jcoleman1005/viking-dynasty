# res://ui/seasonal/WinterScreen.gd
extends Control

@onready var hall_actions_label := %HallActionsLabel
@onready var action_pips := %ActionPips
@onready var actions_list := %ActionsList
@onready var severity_badge := %SeverityBadge
@onready var resource_snapshot := %ResourceSnapshot
@onready var jarl_info := %JarlInfo
@onready var household_list := %HouseholdList
@onready var end_year_btn := %EndYearBtn

const HEIR_TRAINING_SCENE = preload("res://scenes/winter/HeirTrainingAction.tscn")

func _ready() -> void:
	end_year_btn.pressed.connect(_on_end_year_pressed)
	EventBus.hall_action_updated.connect(_refresh_all)
	_refresh_all()

func _on_season_changed(season_name: String, context: Dictionary) -> void:
	if season_name == "Winter":
		_populate_context(context)
		_refresh_all()

func _populate_context(context: Dictionary) -> void:
	var severity = context.get("winter_severity", "Normal")
	severity_badge.text = "Severity: %s" % severity
	
	var treasury = context.get("treasury", {})
	resource_snapshot.text = "Food: %d | Wood: %d | Gold: %d" % [
		treasury.get("food", 0),
		treasury.get("wood", 0),
		treasury.get("gold", 0)
	]
	
	var jarl = DynastyManager.current_jarl
	if jarl:
		jarl_info.text = "%s (Age %d)" % [jarl.display_name, jarl.age]
		
	# Households
	for child in household_list.get_children(): child.queue_free()
	var settlement = SettlementManager.current_settlement
	if settlement:
		for h in settlement.households:
			var lbl = Label.new()
			lbl.text = "%s (Loyalty: %d)" % [h.household_name, h.loyalty]
			lbl.theme_type_variation = "SeasonLabel"
			household_list.add_child(lbl)

func _refresh_all() -> void:
	_update_hall_actions()
	_build_actions_list()

func _update_hall_actions() -> void:
	var jarl = DynastyManager.current_jarl
	if not jarl: return
	
	hall_actions_label.text = "Hall Actions: %d/%d" % [jarl.current_hall_actions, jarl.max_hall_actions]
	
	# Update Pips
	for child in action_pips.get_children(): child.queue_free()
	for i in range(jarl.max_hall_actions):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.color = Color("#d4a843") if i < jarl.current_hall_actions else Color("#3d3828")
		action_pips.add_child(pip)

func _build_actions_list() -> void:
	for child in actions_list.get_children(): child.queue_free()
	
	var jarl = DynastyManager.current_jarl
	var can_act = jarl and jarl.current_hall_actions > 0
	
	# Categories
	_add_category("HEIR")
	_add_action("Train the Heir", "Focus on a child's education.", 1, can_act and jarl.get_first_available_heir() != null, _on_train_heir)
	
	_add_category("LEGACY")
	_add_action("Great Feast", "100 Food. Boost loyalty and renown.", 1, can_act, _on_feast)
	_add_action("Legacy Project", "Focus on long-term goals.", 1, false, func(): pass) # Stub
	
	_add_category("HOUSEHOLDS")
	_add_action("Recruit Household", "50 Gold. Increase population.", 1, can_act, _on_recruit)
	_add_action("Negotiate Marriage", "Form alliances with other lands.", 1, can_act, func(): pass) # Stub

func _add_category(title: String) -> void:
	var lbl = Label.new()
	lbl.text = title
	lbl.theme_type_variation = "SectionHeader"
	actions_list.add_child(lbl)

func _add_action(title: String, desc: String, cost: int, enabled: bool, callback: Callable) -> void:
	var panel = PanelContainer.new()
	panel.theme_type_variation = "PanelContainerCard"
	if not enabled: panel.modulate.a = 0.5
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var t_lbl = Label.new()
	t_lbl.text = title
	vbox.add_child(t_lbl)
	
	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.theme_type_variation = "SeasonLabel"
	vbox.add_child(d_lbl)
	
	var btn = Button.new()
	btn.text = "Execute (%d)" % cost
	btn.disabled = not enabled
	btn.pressed.connect(callback)
	hbox.add_child(btn)
	
	actions_list.add_child(panel)

func _on_train_heir() -> void:
	var instance = HEIR_TRAINING_SCENE.instantiate()
	add_child(instance)

func _on_feast() -> void:
	# Simplified feast logic
	if SettlementManager.attempt_purchase({"food": 100}):
		DynastyManager.perform_hall_action(1)
		Loggie.msg("Great Feast held!").domain("DYNASTY").info()
		_refresh_all()

func _on_recruit() -> void:
	if SettlementManager.attempt_purchase({"gold": 50}):
		DynastyManager.perform_hall_action(1)
		# Add household logic here
		Loggie.msg("New household recruited!").domain("DYNASTY").info()
		_refresh_all()

func _on_end_year_pressed() -> void:
	DynastyManager.end_winter_cycle_complete()
	queue_free()
