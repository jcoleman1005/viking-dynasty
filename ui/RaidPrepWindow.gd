class_name RaidPrepWindow
extends PanelContainer

signal raid_launched(target: RaidTargetData, warbands: Array[WarbandData], provision_level: int)
signal closed

# --- UI References ---
@onready var target_name_label: Label = %TargetNameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var val_diff: Label = %ValDiff
@onready var val_cost: Label = %ValCost
@onready var capacity_label: Label = %CapacityLabel
@onready var warband_list: VBoxContainer = %WarbandList
@onready var provision_slider: HSlider = %ProvisionSlider
@onready var cost_label: Label = %CostLabel
@onready var effect_label: Label = %EffectLabel
@onready var launch_button: Button = %LaunchButton
@onready var cancel_button: Button = %CancelButton

# --- BONDI REFS ---
@onready var bondi_slider: HSlider = %BondiSlider
@onready var bondi_count_label: Label = %BondiCountLabel
# ----------------------

# --- State ---
var current_target: RaidTargetData
var selected_warbands: Array[WarbandData] = []
var max_capacity: int = 0
var current_provision_level: int = 1
var calculated_food_cost: int = 0
var available_idle_peasants: int = 0

const FOOD_COST_PER_HEAD_WELL_FED = 25
@export var BONDI_UNIT_DATA_PATH: UnitData

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	provision_slider.value_changed.connect(_on_provision_slider_changed)
	
	# Bondi Connections
	bondi_slider.value_changed.connect(_on_bondi_slider_changed)
	
	# Default UI state
	provision_slider.value = 1
	_update_provision_ui()
	hide()

func setup(target: RaidTargetData) -> void:
	if not target or not SettlementManager.has_current_settlement():
		Loggie.msg("RaidPrepWindow: Setup failed.").domain(LogDomains.UI).error()
		return
		
	current_target = target
	selected_warbands.clear()
	
	# 1. Update Target Info
	target_name_label.text = target.display_name
	description_label.text = target.description
	val_diff.text = "%d Stars" % target.difficulty_rating
	
	var auth_cost = target.raid_cost_authority
	if target.authority_cost_override > -1:
		auth_cost = target.authority_cost_override
	val_cost.text = "%d" % auth_cost
	
	val_cost.modulate = Color.SALMON if not DynastyManager.can_spend_authority(auth_cost) else Color.WHITE

	# 2. Capacity & Population
	max_capacity = SettlementManager.get_total_ship_capacity_squads()
	available_idle_peasants = SettlementManager.get_idle_peasants()
	
	# 3. Setup Bondi Slider
	bondi_slider.min_value = 0
	bondi_slider.max_value = available_idle_peasants
	bondi_slider.value = 0
	_update_bondi_ui()
	
	# 4. Populate Warbands
	_populate_warband_list()
	
	# 5. Reset & Open
	current_provision_level = 1
	provision_slider.value = 1
	_update_provision_ui()
	_update_capacity_ui()
	show()

func _populate_warband_list() -> void:
	for child in warband_list.get_children():
		child.queue_free()
		
	var warbands = SettlementManager.current_settlement.warbands
	for wb in warbands:
		# Don't list Bondi if they somehow persisted (safety)
		if wb.is_bondi: continue
		
		var checkbox = CheckBox.new()
		checkbox.text = "%s (%d/%d)" % [wb.custom_name, wb.current_manpower, WarbandData.MAX_MANPOWER]
		checkbox.toggled.connect(_on_warband_toggled.bind(wb, checkbox))
		warband_list.add_child(checkbox)

func _on_warband_toggled(is_checked: bool, warband: WarbandData, checkbox_node: CheckBox) -> void:
	if is_checked:
		if _get_total_fleet_usage() >= max_capacity:
			checkbox_node.set_pressed_no_signal(false)
			_shake_capacity_label()
			return
		selected_warbands.append(warband)
	else:
		selected_warbands.erase(warband)
	
	_update_capacity_ui()
	_update_provision_cost()

func _on_bondi_slider_changed(_value: float) -> void:
	_update_bondi_ui()
	_update_capacity_ui() # Bondi consume slots!
	_update_provision_cost() # Bondi need food!

func _update_bondi_ui() -> void:
	var count = int(bondi_slider.value)
	bondi_count_label.text = "%d / %d" % [count, available_idle_peasants]
	
	if count > 0:
		bondi_count_label.modulate = Color.YELLOW
	else:
		bondi_count_label.modulate = Color.WHITE

func _get_total_fleet_usage() -> int:
	var slots = selected_warbands.size()
	
	# Calculate Bondi Warbands needed
	var bondi_count = int(bondi_slider.value)
	if bondi_count > 0:
		var bondi_bands = ceil(float(bondi_count) / WarbandData.MAX_MANPOWER)
		slots += int(bondi_bands)
		
	return slots

func _update_capacity_ui() -> void:
	var usage = _get_total_fleet_usage()
	capacity_label.text = "Fleet Capacity: %d / %d" % [usage, max_capacity]
	
	if usage > max_capacity:
		capacity_label.modulate = Color.SALMON
		launch_button.disabled = true
	elif usage == max_capacity:
		capacity_label.modulate = Color.YELLOW
		_validate_launch_readiness()
	else:
		capacity_label.modulate = Color.WHITE
		_validate_launch_readiness()

func _validate_launch_readiness() -> void:
	# 1. Check Usage vs Capacity
	if _get_total_fleet_usage() > max_capacity:
		launch_button.disabled = true
		launch_button.tooltip_text = "Fleet Over capacity!"
		return
		
	# 2. Check Troops (Need at least 1 regular OR some bondi)
	if selected_warbands.is_empty() and bondi_slider.value <= 0:
		launch_button.disabled = true
		launch_button.tooltip_text = "Must select at least one Warband or Bondi."
		return
		
	# 3. Check Authority
	var cost = current_target.raid_cost_authority
	if current_target.authority_cost_override > -1:
		cost = current_target.authority_cost_override
		
	if not DynastyManager.can_spend_authority(cost):
		launch_button.disabled = true
		launch_button.tooltip_text = "Not enough Authority."
		return
		
	# 4. Check Food
	var current_food = SettlementManager.current_settlement.treasury.get(GameResources.FOOD, 0)
	if current_food < calculated_food_cost:
		launch_button.disabled = true
		launch_button.tooltip_text = "Not enough food!"
		return

	launch_button.disabled = false
	launch_button.tooltip_text = "Ready to sail!"

func _on_launch_pressed() -> void:
	# Handle Bondi Creation
	var bondi_count = int(bondi_slider.value)
	if bondi_count > 0:
		_create_and_append_bondi(bondi_count)
	
	# Handle Purchase
	if calculated_food_cost > 0:
		SettlementManager.attempt_purchase({GameResources.FOOD: calculated_food_cost})
			
	raid_launched.emit(current_target, selected_warbands, current_provision_level)
	hide()

func _create_and_append_bondi(count: int) -> void:
	var unit_data = BONDI_UNIT_DATA_PATH
	if not unit_data:
		Loggie.msg("RaidPrep: Missing Bondi Unit Data!").domain(LogDomains.UI).error()
		return
		
	# Deduct Population (They are now soldiers)
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.population_peasants -= count
	
	# Distribute into Warbands of 10
	var remaining = count
	while remaining > 0:
		var batch_size = min(remaining, WarbandData.MAX_MANPOWER)
		
		var bondi_band = WarbandData.new(unit_data)
		bondi_band.is_bondi = true
		bondi_band.current_manpower = batch_size
		bondi_band.custom_name = "The Bondi"
		
		# Add to selection AND settlement warbands (so they persist if saved)
		if SettlementManager.current_settlement:
			SettlementManager.current_settlement.warbands.append(bondi_band)
			
		selected_warbands.append(bondi_band)
		
		remaining -= batch_size
		
	Loggie.msg("Drafted %d peasants into Bondi." % count).domain(LogDomains.UI).info()

func _on_cancel_pressed() -> void:
	hide()
	closed.emit()

func _update_provision_cost() -> void:
	# Recalculate total men including Bondi
	var total_men = 0
	for wb in selected_warbands:
		total_men += wb.current_manpower
	
	# Add Bondi from slider if not yet created
	if bondi_slider.value > 0:
		total_men += int(bondi_slider.value)

	if current_provision_level == 2:
		calculated_food_cost = total_men * FOOD_COST_PER_HEAD_WELL_FED
	else:
		calculated_food_cost = 0
		
	cost_label.text = "%d Food" % calculated_food_cost
	_validate_launch_readiness()

func _on_provision_slider_changed(value: float) -> void:
	current_provision_level = int(value)
	_update_provision_ui()
	_update_provision_cost()

func _update_provision_ui() -> void:
	if not current_target: return
	
	# NEW: Call RaidManager for live forecast (preview=true)
	# Assumes current_target has 'distance' property (based on standard RaidTargetData)
	var dist = current_target.distance if "distance" in current_target else 200.0
	
	var forecast = RaidManager.calculate_journey_attrition(dist, current_provision_level, true)
	effect_label.text = forecast.description
	
	# Update color based on risk severity returned by logic
	var risk_pct = forecast.get("risk_pct", 0)
	if risk_pct >= 50:
		effect_label.modulate = Color.SALMON
	elif risk_pct >= 20:
		effect_label.modulate = Color.YELLOW
	else:
		effect_label.modulate = Color.GREEN

func _shake_capacity_label() -> void:
	var tween = create_tween()
	var original_pos = capacity_label.position.x
	tween.tween_property(capacity_label, "position:x", original_pos + 5, 0.05)
	tween.tween_property(capacity_label, "position:x", original_pos - 5, 0.05)
	tween.tween_property(capacity_label, "position:x", original_pos, 0.05)
