# res://ui/RaidPrepWindow.gd
class_name RaidPrepWindow
extends PanelContainer

## Emitted when the player confirms launch. 
## Passes the target data, selected warbands, and provision level (0=None, 1=Std, 2=Well-Fed)
signal raid_launched(target: RaidTargetData, warbands: Array[WarbandData], provision_level: int)
signal closed

# --- UI References ---
@onready var target_name_label: Label = $MarginContainer/MainVBox/ContentHBox/LeftCol/TargetNameLabel
@onready var description_label: RichTextLabel = $MarginContainer/MainVBox/ContentHBox/LeftCol/DescriptionLabel
@onready var val_diff: Label = $MarginContainer/MainVBox/ContentHBox/LeftCol/StatsGrid/ValDiff
@onready var val_cost: Label = $MarginContainer/MainVBox/ContentHBox/LeftCol/StatsGrid/ValCost
@onready var capacity_label: Label = $MarginContainer/MainVBox/ContentHBox/RightCol/CapacityLabel
@onready var warband_list: VBoxContainer = $MarginContainer/MainVBox/ContentHBox/RightCol/ScrollContainer/WarbandList
@onready var provision_slider: HSlider = $MarginContainer/MainVBox/ProvisionsPanel/HBox/ProvisionSlider
@onready var cost_label: Label = $MarginContainer/MainVBox/ProvisionsPanel/HBox/CostLabel
@onready var effect_label: Label = $MarginContainer/MainVBox/ProvisionsPanel/HBox/EffectLabel
@onready var launch_button: Button = $MarginContainer/MainVBox/ActionButtons/LaunchButton
@onready var cancel_button: Button = $MarginContainer/MainVBox/ActionButtons/CancelButton

# --- State ---
var current_target: RaidTargetData
var selected_warbands: Array[WarbandData] = []
var max_capacity: int = 0
var current_provision_level: int = 1 # Default to Standard
var calculated_food_cost: int = 0

const FOOD_COST_PER_HEAD_WELL_FED = 25

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	provision_slider.value_changed.connect(_on_provision_slider_changed)
	
	# Default UI state
	provision_slider.value = 1
	_update_provision_ui()
	hide()

func setup(target: RaidTargetData) -> void:
	if not target:
		Loggie.msg("RaidPrepWindow: Setup failed. Target is null.").domain(LogDomains.UI).error()
		return
		
	if not SettlementManager.has_current_settlement():
		Loggie.msg("RaidPrepWindow: Setup failed. No settlement loaded.").domain(LogDomains.UI).error()
		return
		
	current_target = target
	selected_warbands.clear()
	
	# 1. Update Target Info
	target_name_label.text = target.display_name
	description_label.text = target.description
	val_diff.text = "%d Stars" % target.difficulty_rating
	
	# Resolve Authority Cost
	var auth_cost = target.raid_cost_authority
	if target.authority_cost_override > -1:
		auth_cost = target.authority_cost_override
	val_cost.text = "%d" % auth_cost
	
	# Visual Warning for Authority
	if not DynastyManager.can_spend_authority(auth_cost):
		val_cost.modulate = Color.SALMON
	else:
		val_cost.modulate = Color.WHITE

	# 2. Get Fleet Capacity
	max_capacity = SettlementManager.current_settlement.get_fleet_capacity()
	
	# 3. Populate Warbands
	_populate_warband_list()
	
	# 4. Reset & Open
	current_provision_level = 1
	provision_slider.value = 1
	_update_provision_ui()
	_update_capacity_ui()
	show()

func _populate_warband_list() -> void:
	for child in warband_list.get_children():
		child.queue_free()
		
	var warbands = SettlementManager.current_settlement.warbands
	
	if warbands.is_empty():
		var lbl = Label.new()
		lbl.text = "No Warbands available!"
		lbl.modulate = Color.SALMON
		warband_list.add_child(lbl)
		return

	for wb in warbands:
		var checkbox = CheckBox.new()
		checkbox.text = "%s (%d/%d men)" % [wb.custom_name, wb.current_manpower, WarbandData.MAX_MANPOWER]
		
		# Disable if wounded or busy? (Future feature)
		# For now, just checking logic
		
		checkbox.toggled.connect(_on_warband_toggled.bind(wb, checkbox))
		warband_list.add_child(checkbox)

func _on_warband_toggled(is_checked: bool, warband: WarbandData, checkbox_node: CheckBox) -> void:
	if is_checked:
		if selected_warbands.size() >= max_capacity:
			checkbox_node.set_pressed_no_signal(false) # Reject check
			_shake_capacity_label()
			return
		selected_warbands.append(warband)
	else:
		selected_warbands.erase(warband)
	
	_update_capacity_ui()
	_update_provision_cost()

func _on_provision_slider_changed(value: float) -> void:
	current_provision_level = int(value)
	_update_provision_ui()
	_update_provision_cost()

func _update_provision_ui() -> void:
	match current_provision_level:
		0:
			effect_label.text = "High Attrition Risk!"
			effect_label.modulate = Color.SALMON
		1:
			effect_label.text = "Standard Risk"
			effect_label.modulate = Color.WHITE
		2:
			effect_label.text = "Risk Reduced (-15%)"
			effect_label.modulate = Color.GREEN

func _update_provision_cost() -> void:
	if current_provision_level == 2:
		var total_men = 0
		for wb in selected_warbands:
			total_men += wb.current_manpower
		
		calculated_food_cost = total_men * FOOD_COST_PER_HEAD_WELL_FED
	else:
		calculated_food_cost = 0
		
	cost_label.text = "%d Food" % calculated_food_cost
	
	# Validate Food Affordability
	var current_food = SettlementManager.current_settlement.treasury.get(GameResources.FOOD, 0)
	if current_food < calculated_food_cost:
		cost_label.modulate = Color.SALMON
		launch_button.disabled = true
		launch_button.tooltip_text = "Not enough food!"
	else:
		cost_label.modulate = Color.WHITE
		_validate_launch_readiness()

func _update_capacity_ui() -> void:
	capacity_label.text = "Fleet Capacity: %d / %d" % [selected_warbands.size(), max_capacity]
	
	if selected_warbands.size() == max_capacity:
		capacity_label.modulate = Color.YELLOW
	else:
		capacity_label.modulate = Color.WHITE
		
	_validate_launch_readiness()

func _validate_launch_readiness() -> void:
	# 1. Check Troops
	if selected_warbands.is_empty():
		launch_button.disabled = true
		launch_button.tooltip_text = "Must select at least one Warband."
		return
		
	# 2. Check Authority
	var cost = current_target.raid_cost_authority
	if current_target.authority_cost_override > -1:
		cost = current_target.authority_cost_override
		
	if not DynastyManager.can_spend_authority(cost):
		launch_button.disabled = true
		launch_button.tooltip_text = "Not enough Authority."
		return
		
	# 3. Check Food (Redundant check but safe)
	var current_food = SettlementManager.current_settlement.treasury.get(GameResources.FOOD, 0)
	if current_food < calculated_food_cost:
		launch_button.disabled = true
		return

	# All Green
	launch_button.disabled = false
	launch_button.tooltip_text = "Ready to sail!"

func _on_launch_pressed() -> void:
	if calculated_food_cost > 0:
		if not SettlementManager.attempt_purchase({GameResources.FOOD: calculated_food_cost}):
			Loggie.msg("RaidPrepWindow: Purchase failed logic mismatch!").domain(LogDomains.UI).error()
			return
			
	raid_launched.emit(current_target, selected_warbands, current_provision_level)
	hide()

func _on_cancel_pressed() -> void:
	hide()
	closed.emit()

func _shake_capacity_label() -> void:
	var tween = create_tween()
	var original_pos = capacity_label.position.x
	tween.tween_property(capacity_label, "position:x", original_pos + 5, 0.05)
	tween.tween_property(capacity_label, "position:x", original_pos - 5, 0.05)
	tween.tween_property(capacity_label, "position:x", original_pos, 0.05)
