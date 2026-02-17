extends PanelContainer

## DecreeAuthorizationPopup
## Allows the player to assign a household to a construction decree and authorize it.

@onready var building_name_label: Label = %BuildingNameLabel
@onready var cost_label: Label = %CostLabel
@onready var upkeep_label: Label = %UpkeepLabel
@onready var household_list: ItemList = %HouseholdList
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var error_label: Label = %ErrorLabel

var _current_decree: ConstructionDecree
var _valid_households: Array[HouseholdData] = []

func setup(decree: ConstructionDecree) -> void:
	_current_decree = decree
	_refresh_ui()

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	error_label.hide()
	
	# Center the popup
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

func _refresh_ui() -> void:
	if not _current_decree: return
	
	var data = _current_decree.building_data
	building_name_label.text = data.display_name
	cost_label.text = "Build Cost: " + _format_cost(data.build_cost)
	
	if data.heating_cost > 0:
		upkeep_label.text = "Winter Upkeep: %d Wood/Day" % data.heating_cost
		upkeep_label.show()
	else:
		upkeep_label.hide()
		
	_populate_household_list()

func _populate_household_list() -> void:
	household_list.clear()
	_valid_households.clear()
	
	if not SettlementManager.current_settlement: return
	
	var households = SettlementManager.current_settlement.households
	for h in households:
		# Rule: Must be on BUILD oath and NOT already locked
		if h.current_oath == HouseholdData.SeasonalOath.BUILD:
			if not ConstructionAuthority._locked_households.has(h.household_name):
				_valid_households.append(h)
				var display_name = _get_household_display_name(h)
				household_list.add_item("%s (%d members)" % [display_name, h.member_count])

func _get_household_display_name(h: HouseholdData) -> String:
	if h.head_of_household and h.head_of_household.given_name != "":
		return "%s %s" % [h.head_of_household.given_name, h.head_of_household.patronymic]
	return h.household_name

func _on_confirm_pressed() -> void:
	var selected_indices = household_list.get_selected_items()
	if selected_indices.is_empty():
		_show_error("Please select a household.")
		return
		
	var household = _valid_households[selected_indices[0]]
	
	if ConstructionAuthority.authorize_decree(_current_decree, household):
		Loggie.msg("Decree Authorized: %s sworn to %s" % [_current_decree.building_data.display_name, household.household_name]).domain(LogDomains.UI).info()
		EventBus.decree_authorized.emit(_current_decree)
		EventBus.decree_interaction_finished.emit()
		queue_free()
	else:
		_show_error("Authorization failed. Check resources.")

func _on_cancel_pressed() -> void:
	EventBus.decree_cancelled.emit(_current_decree.resolved_grid_pos)
	ConstructionAuthority.cancel_decree(_current_decree)
	Loggie.msg("Decree Cancelled: %s" % _current_decree.building_data.display_name).domain(LogDomains.UI).info()
	queue_free()

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.show()

func _format_cost(cost: Dictionary) -> String:
	var s: PackedStringArray = []
	for k in cost:
		var name = k.capitalize() # Fallback if GameResources not available or doesn't have names
		s.append("%d %s" % [cost[k], name])
	return ", ".join(s)
