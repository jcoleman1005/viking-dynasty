extends HBoxContainer

## HouseholdOathRow - UI component for a single household.
## Displays name, count, and allows oath selection via dropdown.

@onready var household_icon: TextureRect = %HouseholdIcon
@onready var name_label: Label = $HouseholdNameLabel
@onready var generation_label: Label = $GenerationLabel
@onready var count_label: Label = $MemberCountLabel
@onready var loyalty_bar: ColorRect = %LoyaltyBar
@onready var oath_dropdown: OptionButton = $OathDropdown
@onready var preview_label: Label = $YieldPreviewLabel

var household_data: HouseholdData

func setup(data: HouseholdData) -> void:
	household_data = data
	
	# 0. Icon
	if household_icon:
		if data.icon:
			household_icon.texture = data.icon
			household_icon.show()
		else:
			household_icon.hide()
	
	# 1. Identity & Lineage
	name_label.text = _get_display_name(data)
	name_label.tooltip_text = _build_ancestry_tooltip(data)
	
	if data.head_of_household:
		generation_label.text = "Gen. %d" % data.head_of_household.generation
	else:
		generation_label.text = ""
		
	# 2. Member Count
	count_label.text = "%d members" % data.member_count
	
	# 3. Loyalty Bar
	var loyalty_pct = data.loyalty / 100.0
	loyalty_bar.custom_minimum_size.x = 60.0 * loyalty_pct
	
	if loyalty_pct > 0.6:
		loyalty_bar.color = Color.GREEN
	elif loyalty_pct > 0.3:
		loyalty_bar.color = Color.ORANGE
	else:
		loyalty_bar.color = Color.RED
	
	# 4. Oath & Yield
	_populate_oath_dropdown()
	_update_yield_preview()

func _get_display_name(data: HouseholdData) -> String:
	if data.head_of_household and data.head_of_household.given_name != "":
		return "%s %s" % [data.head_of_household.given_name, data.head_of_household.patronymic]
	return data.household_name

func _build_ancestry_tooltip(data: HouseholdData) -> String:
	if not data.head_of_household:
		return ""
	
	var head = data.head_of_household
	var tooltip = "[b]%s %s[/b]\n" % [head.given_name, head.patronymic]
	tooltip += "Generation: %d\n" % head.generation
	
	if head.ancestors.size() > 1:
		tooltip += "Lineage: %s" % " → ".join(head.ancestors)
	else:
		tooltip += "Founder of the household."
		
	return tooltip

func _populate_oath_dropdown() -> void:
	oath_dropdown.clear()
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
