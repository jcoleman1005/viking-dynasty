extends HBoxContainer

## HouseholdOathRow - UI component for a single household.
## Displays name, count, and allows oath selection via dropdown.

@onready var name_label: Label = $HouseholdNameLabel
@onready var count_label: Label = $MemberCountLabel
@onready var oath_dropdown: OptionButton = $OathDropdown
@onready var preview_label: Label = $YieldPreviewLabel

var household_data: HouseholdData

func setup(data: HouseholdData) -> void:
	household_data = data
	name_label.text = data.household_name
	count_label.text = "%d members" % data.member_count
	
	_populate_oath_dropdown()
	_update_yield_preview()

func _populate_oath_dropdown() -> void:
	oath_dropdown.clear()
	# Order MUST match HouseholdData.SeasonalOath enum
	oath_dropdown.add_item("Resting", HouseholdData.SeasonalOath.IDLE)
	oath_dropdown.add_item("Harvest", HouseholdData.SeasonalOath.HARVEST)
	oath_dropdown.add_item("Timber", HouseholdData.SeasonalOath.TIMBER)
	oath_dropdown.add_item("Build", HouseholdData.SeasonalOath.BUILD)
	oath_dropdown.add_item("Raid", HouseholdData.SeasonalOath.RAID)
	
	oath_dropdown.select(household_data.current_oath)
	
	if not oath_dropdown.item_selected.is_connected(_on_oath_selected):
		oath_dropdown.item_selected.connect(_on_oath_selected)

func _on_oath_selected(index: int) -> void:
	household_data.current_oath = index as HouseholdData.SeasonalOath
	_update_yield_preview()
	
	# Notify parent to update the overall summary
	var parent = get_parent()
	while parent and not parent.has_method("_update_summary"):
		parent = parent.get_parent()
	
	if parent:
		parent._update_summary()

func _update_yield_preview() -> void:
	var labor = int(household_data.member_count * household_data.labor_efficiency)
	
	match household_data.current_oath:
		HouseholdData.SeasonalOath.HARVEST:
			preview_label.text = "↑ %d Food" % labor
			preview_label.modulate = Color.GREEN_YELLOW
		HouseholdData.SeasonalOath.TIMBER:
			preview_label.text = "↑ %d Wood" % labor
			preview_label.modulate = Color.BURLYWOOD
		HouseholdData.SeasonalOath.BUILD:
			preview_label.text = "↑ %d Builders" % labor
			preview_label.modulate = Color.SKY_BLUE
		HouseholdData.SeasonalOath.RAID:
			preview_label.text = "⚔️ %d Raiders" % labor
			preview_label.modulate = Color.TOMATO
		_:
			preview_label.text = "Resting"
			preview_label.modulate = Color.LIGHT_GRAY
