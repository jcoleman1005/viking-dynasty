# res://ui/StorefrontUI.gd (Fully Refactored)
extends Control

const LegacyUpgradeData = preload("res://data/legacy/LegacyUpgradeData.gd")
# --- Node References ---
@onready var gold_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/GoldLabel
@onready var wood_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/WoodLabel
@onready var food_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/FoodLabel
@onready var stone_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/StoneLabel

@onready var build_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/BuildTab/BuildButtonsContainer

@onready var recruit_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/RecruitTab/RecruitButtons
@onready var garrison_list_container: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/RecruitTab/GarrisonList

# --- Legacy Tab References ---
@onready var renown_label: Label = $PanelContainer/MarginContainer/TabContainer/LegacyTab/JarlStatsDisplay/RenownLabel
@onready var authority_label: Label = $PanelContainer/MarginContainer/TabContainer/LegacyTab/JarlStatsDisplay/AuthorityLabel
@onready var legacy_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/LegacyTab/LegacyButtonsContainer

# --- Exported Data ---
@export var available_buildings: Array[BuildingData] = []
@export var available_units: Array[UnitData] = []
@export var default_treasury_display: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var auto_load_units_from_directory: bool = true

# --- Internal state for legacy upgrades ---
# --- THIS IS THE FIX: This variable is no longer needed here ---
# var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []
# --- END FIX ---
var minimum_inherited_legitimacy: int = 0 # This will be set by the upgrade


# --- MOVED FUNCTIONS UP TO FIX PARSING ERROR ---

# --- Utility Functions ---
func _format_cost(cost: Dictionary) -> String:
	"""Format cost dictionary as readable string"""
	var cost_parts: Array[String] = []
	for resource in cost:
		cost_parts.append("%d %s" % [cost[resource], resource])
	return ", ".join(cost_parts)

func _update_treasury_display(new_treasury: Dictionary) -> void:
	gold_label.text = "Gold: %d" % new_treasury.get("gold", 0)
	wood_label.text = "Wood: %d" % new_treasury.get("wood", 0)
	food_label.text = "Food: %d" % new_treasury.get("food", 0)
	stone_label.text = "Stone: %d" % new_treasury.get("stone", 0)

func _on_purchase_successful(item_name: String) -> void:
	"""Handle purchase success event - refresh garrison display"""
	# Check if the item was a unit to avoid unnecessary UI churn
	# A bit of a hack, but good for performance.
	if item_name.contains("Raider") or item_name.contains("Unit"):
		_update_garrison_display()
	
	# If a legacy upgrade was purchased, the jarl_stats_updated signal
	# will handle refreshing the legacy button list.
	# We don't need to refresh the build list, as it's static for now.
	pass

func _update_garrison_display() -> void:
	"""Update the garrison list display with current garrisoned units"""
	if not garrison_list_container:
		return
	
	for child in garrison_list_container.get_children():
		child.queue_free()
	
	if not SettlementManager.current_settlement:
		var no_settlement_label = Label.new()
		no_settlement_label.text = "No settlement loaded"
		garrison_list_container.add_child(no_settlement_label)
		return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	
	if garrison.is_empty():
		var empty_garrison_label = Label.new()
		empty_garrison_label.text = "No units in garrison"
		garrison_list_container.add_child(empty_garrison_label)
		return
	
	var header_label = Label.new()
	header_label.text = "Current Garrison:"
	header_label.add_theme_font_size_override("font_size", 16)
	garrison_list_container.add_child(header_label)
	
	for unit_path in garrison:
		var unit_count: int = garrison[unit_path]
		var unit_data: UnitData = load(unit_path)
		
		if unit_data:
			var unit_label = Label.new()
			unit_label.text = "â€¢ %s x%d" % [unit_data.display_name, unit_count]
			garrison_list_container.add_child(unit_label)
		else:
			var error_label = Label.new()
			error_label.text = "â€¢ Unknown unit x%d" % unit_count
			garrison_list_container.add_child(error_label)
	
	var total_units = 0
	for unit_path in garrison:
		total_units += garrison[unit_path]
	
	var total_label = Label.new()
	total_label.text = "Total units: %d" % total_units
	total_label.add_theme_font_size_override("font_size", 12)
	garrison_list_container.add_child(total_label)

# --- END MOVED FUNCTIONS ---


func _ready() -> void:
	# Allow unused mouse events to pass to the Camera ---
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Connect to SettlementManager for treasury
	EventBus.treasury_updated.connect(_update_treasury_display)
	EventBus.purchase_successful.connect(_on_purchase_successful)
	
	if SettlementManager.current_settlement:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		_update_treasury_display(default_treasury_display)

	# Connect to DynastyManager for Jarl stats
	DynastyManager.jarl_stats_updated.connect(_update_jarl_stats_display)
	
	# Initial load
	_load_building_data()
	_load_unit_data()
	
	# --- THIS IS THE FIX: Removed local call ---
	# _load_legacy_upgrades() # Load the data first
	# --- END FIX ---
	
	# Setup UI
	if DynastyManager.current_jarl:
		_update_jarl_stats_display(DynastyManager.get_current_jarl())
	
	_setup_recruit_buttons()
	_update_garrison_display()
	_populate_legacy_buttons() # Populate buttons after data is loaded

# --- Jarl Stats UI ---
func _update_jarl_stats_display(jarl_data: JarlData) -> void:
	"""Updates the Renown and Authority labels in the Legacy tab."""
	if not jarl_data:
		return
	renown_label.text = "Renown: %d" % jarl_data.renown
	authority_label.text = "Authority: %d / %d" % [jarl_data.current_authority, jarl_data.max_authority]
	
	# This ensures buttons are enabled/disabled when stats change (e.g., End Year)
	_populate_legacy_buttons()

# --- Legacy Upgrade Functions ---
# --- THIS IS THE FIX: Removed _load_legacy_upgrades() function ---
# --- END FIX ---

func _populate_legacy_buttons() -> void:
	"""
	Populate the Legacy tab with available upgrades.
	This function now creates real buttons from loaded data.
	"""
	for child in legacy_buttons_container.get_children():
		child.queue_free()
	
	# --- THIS IS THE FIX ---
	# Read the list from the manager, not our internal variable
	if DynastyManager.loaded_legacy_upgrades.is_empty():
	# --- END FIX ---
		var placeholder_label = Label.new()
		placeholder_label.text = "No legacy upgrades found."
		legacy_buttons_container.add_child(placeholder_label)
		return
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl:
		push_error("StorefrontUI: Cannot get Jarl from DynastyManager!")
		return

	# --- "SOFT-GUIDE" LITMUS TEST ---
	# Check for traits that modify costs
	var is_pious = jarl.has_trait("Pious")
	# ---------------------------------

	# --- THIS IS THE FIX ---
	# Create a button for each loaded upgrade
	for upgrade_data in DynastyManager.loaded_legacy_upgrades:
	# --- END FIX ---
		
		# --- "SOFT-GUIDE" LOGIC ---
		# This is the core mechanic of the proposal in action.
		var current_renown_cost = upgrade_data.renown_cost
		var trait_modifier_text = ""
		
		if is_pious and upgrade_data.effect_key == "UPG_BUILD_CHAPEL":
			# Example: "Pious" trait gives a 25 Renown discount
			current_renown_cost = max(0, upgrade_data.renown_cost - 25)
			trait_modifier_text = " (-25 Pious)"
		# --------------------------

		var button = Button.new()
		var cost_text = "Cost: %d Renown%s, %d Auth" % [current_renown_cost, trait_modifier_text, upgrade_data.authority_cost]
		
		# Set the text (without the name, as the icon is present)
		# --- MODIFIED: Show Progress ---
		var title_text = upgrade_data.display_name
		if upgrade_data.required_progress > 1:
			title_text += " (%d/%d)" % [upgrade_data.current_progress, upgrade_data.required_progress]
		
		button.text = "%s\\n%s" % [title_text, cost_text]
		# --- END MODIFIED ---
		button.tooltip_text = upgrade_data.description
		
		# --- NEW: Set Icon ---
		if upgrade_data.icon:
			button.icon = upgrade_data.icon
			# Optional: Align text to the left if an icon is present
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# --- END NEW ---
		
		# --- MODIFIED: Check affordability and purchase status ---
		var can_buy_renown = jarl.renown >= current_renown_cost # Use modified cost
		var can_buy_auth = jarl.current_authority >= upgrade_data.authority_cost
		
		# --- THIS IS THE FIX ---
		# We must check the Jarl's *data*, not the local copy
		var is_purchased = DynastyManager.has_purchased_upgrade(upgrade_data.effect_key)
		# We should also check the progress on the *manager's* copy
		if upgrade_data.is_purchased:
		# --- END FIX ---
			button.disabled = true
			button.text = "%s (Completed)" % upgrade_data.display_name
		elif not can_buy_renown:
			button.disabled = true
			button.text += "\n(Not enough Renown)"
		elif not can_buy_auth:
			button.disabled = true
			button.text += "\n(Not enough Authority)"
		
		# We must bind the *original* upgrade_data (which holds the modified cost)
		# to the pressed signal.
		button.pressed.connect(_on_legacy_upgrade_pressed.bind(upgrade_data, current_renown_cost))
		legacy_buttons_container.add_child(button)

func _on_legacy_upgrade_pressed(upgrade_data: LegacyUpgradeData, final_renown_cost: int) -> void:
	"""
	Handles the purchase logic for a Legacy Upgrade.
	Uses the dynamically calculated final_renown_cost.
	"""
	print("Attempting to purchase legacy upgrade: %s" % upgrade_data.display_name)
	
	# 1. Double-check costs using the calculated cost
	if not DynastyManager.can_spend_renown(final_renown_cost):
		print("Purchase failed: Not enough Renown.")
		EventBus.purchase_failed.emit("Not enough Renown")
		return
		
	if not DynastyManager.can_spend_authority(upgrade_data.authority_cost):
		print("Purchase failed: Not enough Authority.")
		EventBus.purchase_failed.emit("Not enough Authority")
		return
	
	# 2. Spend resources
	var spent_renown = DynastyManager.spend_renown(final_renown_cost)
	var spent_auth = DynastyManager.spend_authority(upgrade_data.authority_cost)
	
	if not (spent_renown and spent_auth):
		push_error("Legacy purchase failed mid-transaction! This should not happen.")
		if spent_renown: DynastyManager.award_renown(final_renown_cost) # Refund
		return
	
	# 3. Mark as purchased (This is now progress)
	upgrade_data.current_progress += 1
	
	# 4. Apply the effect ONLY if progress is complete
	if upgrade_data.is_purchased: # This check now works
		DynastyManager.purchase_legacy_upgrade(upgrade_data.effect_key)
		_apply_legacy_upgrade_effect(upgrade_data.effect_key)
	
	# 5. Refresh the UI
	_populate_legacy_buttons() # This will now show the button as "Purchased"
	EventBus.purchase_successful.emit(upgrade_data.display_name)

func _apply_legacy_upgrade_effect(effect_key: String) -> void:
	"""
	Applies the permanent game-state change for a purchased upgrade.
	"""
	match effect_key:
		"UPG_TRELLEBORG":
			if SettlementManager.current_settlement:
				SettlementManager.current_settlement.max_garrison_bonus += 10 # Example value
				SettlementManager.save_settlement()
				print("Applied UPG_TRELLEBORG: Max garrison bonus +10")
			else:
				push_error("Cannot apply Trelleborg upgrade: No current settlement!")
				
		"UPG_JELLING_STONE":
			var jarl = DynastyManager.get_current_jarl()
			if jarl:
				jarl.heir_starting_renown_bonus += 50
				# --- NEW: Set Minimum Legitimacy ---
				# --- THIS IS THE FIX ---
				# We set this on the *manager*, not a local var
				DynastyManager.minimum_inherited_legitimacy = 25 # Example: 25
				# --- END FIX ---
				print("Applied UPG_JELLING_STONE: Heir renown +50, Min Legitimacy set to 25")
			else:
				push_error("Cannot apply Jelling Stone upgrade: No current Jarl!")
		
		"UPG_BUILD_CHAPEL":
			# For this test, we just log the success.
			# A real implementation might add a modifier to SettlementManager.
			print("Applied UPG_BUILD_CHAPEL: Dynasty's piety increased.")
		
		_:
			push_warning("Unknown legacy upgrade effect key: %s" % effect_key)

# --- Building Tab Functions ---
func _load_building_data() -> void:
	"""Scan res://data/buildings/ for buildable .tres files and create buttons."""
	var dir = DirAccess.open("res://data/buildings/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var building_path = "res://data/buildings/" + file_name
				var building_data = load(building_path) as BuildingData
				
				if building_data and building_data.is_player_buildable:
					_create_building_button(building_data)
					
			file_name = dir.get_next()

func _create_building_button(building_data: BuildingData) -> void:
	"""Creates and connects a single button for the build tab."""
	var button = Button.new()
	button.text = "%s (Cost: %s)" % [building_data.display_name, _format_cost(building_data.build_cost)]
	
	# --- Set Icon for Build Tab ---
	if building_data.icon:
		button.icon = building_data.icon
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	button.pressed.connect(_on_buy_button_pressed.bind(building_data))
	build_buttons_container.add_child(button)

func _on_buy_button_pressed(item_data: BuildingData) -> void:
	if not item_data:
		return
	
	print("UI attempting to purchase '%s'." % item_data.display_name)
	var purchase_successful: bool = SettlementManager.attempt_purchase(item_data.build_cost)
	
	if purchase_successful:
		print("UI received purchase confirmation for '%s'." % item_data.display_name)
		EventBus.building_ready_for_placement.emit(item_data)
	else:
		print("UI received purchase failure for '%s'." % item_data.display_name)

# --- Recruit Tab Functions ---
func _load_unit_data() -> void:
	"""Scan res://data/units/ directory for .tres files and load them as UnitData"""
	var dir = DirAccess.open("res://data/units/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var unit_path = "res://data/units/" + file_name
				var unit_data = load(unit_path) as UnitData
				if unit_data:
					if _is_player_unit(unit_data):
						available_units.append(unit_data)
			file_name = dir.get_next()

func _setup_recruit_buttons() -> void:
	"""Create recruit buttons for each available unit"""
	for unit_data in available_units:
		var button = Button.new()
		button.text = "%s (Cost: %s)" % [unit_data.display_name, _format_cost(unit_data.spawn_cost)]
		
		# --- Set Icon for Recruit Tab ---
		if unit_data.icon:
			button.icon = unit_data.icon
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

		button.pressed.connect(_on_recruit_button_pressed.bind(unit_data))
		recruit_buttons_container.add_child(button)

func _is_player_unit(unit_data: UnitData) -> bool:
	if not unit_data: return false
	if "Player" in unit_data.display_name: return true
	if "Player" in unit_data.resource_path: return true
	if unit_data.scene_to_spawn and "Player" in unit_data.scene_to_spawn.resource_path: return true
	if unit_data.display_name in ["Viking Raider"]: return false
	return true

func _on_recruit_button_pressed(unit_data: UnitData) -> void:
	"""Handle recruit button press"""
	if not unit_data:
		return
	
	print("UI attempting to recruit '%s'." % unit_data.display_name)
	var purchase_successful: bool = SettlementManager.attempt_purchase(unit_data.spawn_cost)
	
	if purchase_successful:
		print("UI received purchase confirmation for '%s'." % unit_data.display_name)
		SettlementManager.recruit_unit(unit_data)
	else:
		print("UI received purchase failure for '%s'." % unit_data.display_name)
