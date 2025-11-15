# res://ui/StorefrontUI.gd
extends Control

const LegacyUpgradeData = preload("res://data/legacy/LegacyUpgradeData.gd")

# --- Header References (Permanent HUD) ---
# These are now children of MainLayout/Header, not the TabContainer
@onready var gold_label: Label = $PanelContainer/MarginContainer/MainLayout/Header/TreasuryDisplay/GoldLabel
@onready var wood_label: Label = $PanelContainer/MarginContainer/MainLayout/Header/TreasuryDisplay/WoodLabel
@onready var food_label: Label = $PanelContainer/MarginContainer/MainLayout/Header/TreasuryDisplay/FoodLabel
@onready var stone_label: Label = $PanelContainer/MarginContainer/MainLayout/Header/TreasuryDisplay/StoneLabel
@onready var unit_count_label: Label = $PanelContainer/MarginContainer/MainLayout/Header/UnitCountLabel

# --- Tab References ---
@onready var build_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/MainLayout/TabContainer/BuildTab/BuildButtonsContainer

@onready var recruit_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/MainLayout/TabContainer/RecruitTab/RecruitButtons
@onready var garrison_list_container: VBoxContainer = $PanelContainer/MarginContainer/MainLayout/TabContainer/RecruitTab/GarrisonList

# --- Legacy Tab References ---
@onready var renown_label: Label = $PanelContainer/MarginContainer/MainLayout/TabContainer/LegacyTab/JarlStatsDisplay/RenownLabel
@onready var authority_label: Label = $PanelContainer/MarginContainer/MainLayout/TabContainer/LegacyTab/JarlStatsDisplay/AuthorityLabel
@onready var legacy_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/MainLayout/TabContainer/LegacyTab/LegacyButtonsContainer

# --- Exported Data ---
@export var available_buildings: Array[BuildingData] = []
@export var available_units: Array[UnitData] = []
@export var default_treasury_display: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var auto_load_units_from_directory: bool = true

# --- Internal state ---
var minimum_inherited_legitimacy: int = 0 

func _ready() -> void:
	# Allow unused mouse events to pass to the Camera
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Connect to SettlementManager for treasury
	EventBus.treasury_updated.connect(_update_treasury_display)
	EventBus.purchase_successful.connect(_on_purchase_successful)
	
	# Connect to settlement loading signal to update treasury when settlement loads
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	
	# Initial treasury display - defer to ensure settlement is loaded
	call_deferred("_update_initial_treasury")

	# Connect to DynastyManager for Jarl stats
	DynastyManager.jarl_stats_updated.connect(_update_jarl_stats_display)
	
	# Initial load
	_load_building_data()
	_load_unit_data()
	
	# Setup UI
	if DynastyManager.current_jarl:
		_update_jarl_stats_display(DynastyManager.get_current_jarl())
	
	_setup_recruit_buttons()
	_update_garrison_display()
	_populate_legacy_buttons() 

# --- Utility Functions ---
func _format_cost(cost: Dictionary) -> String:
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
	if item_name.contains("Raider") or item_name.contains("Unit") or item_name.contains("Viking"):
		_update_garrison_display()

func _on_settlement_loaded(settlement_data: SettlementData) -> void:
	"""Called when settlement is loaded to update treasury display"""
	if settlement_data and settlement_data.treasury:
		_update_treasury_display(settlement_data.treasury)
	else:
		_update_treasury_display(default_treasury_display)
	
	# Also update garrison/unit count on load
	_update_garrison_display()

func _update_initial_treasury() -> void:
	"""Deferred treasury update to ensure settlement is loaded"""
	if SettlementManager.current_settlement and SettlementManager.current_settlement.treasury:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		_update_treasury_display(default_treasury_display)

func _update_garrison_display() -> void:
	# 1. Update the Detailed List (Inside the Recruit Tab)
	if garrison_list_container:
		for child in garrison_list_container.get_children():
			child.queue_free()
		
		if SettlementManager.current_settlement and not SettlementManager.current_settlement.garrisoned_units.is_empty():
			var header_label = Label.new()
			header_label.text = "Garrison Details:"
			header_label.add_theme_font_size_override("font_size", 16)
			garrison_list_container.add_child(header_label)
			
			for unit_path in SettlementManager.current_settlement.garrisoned_units:
				var unit_count: int = SettlementManager.current_settlement.garrisoned_units[unit_path]
				var unit_data: UnitData = load(unit_path)
				if unit_data:
					var unit_label = Label.new()
					unit_label.text = "• %s x%d" % [unit_data.display_name, unit_count]
					garrison_list_container.add_child(unit_label)
		else:
			var empty_label = Label.new()
			empty_label.text = "No units in garrison"
			garrison_list_container.add_child(empty_label)

	# 2. Update the Permanent Header Count (Outside the Tab)
	var total_units = 0
	if SettlementManager.current_settlement:
		var garrison = SettlementManager.current_settlement.garrisoned_units
		for unit_path in garrison:
			total_units += garrison[unit_path]
	
	if unit_count_label:
		unit_count_label.text = "Garrison: %d" % total_units
		# Add simple color coding for feedback
		if total_units == 0:
			unit_count_label.modulate = Color.SALMON
		else:
			unit_count_label.modulate = Color.WHITE

# --- Jarl Stats UI ---
func _update_jarl_stats_display(jarl_data: JarlData) -> void:
	if not jarl_data: return
	renown_label.text = "Renown: %d" % jarl_data.renown
	authority_label.text = "Authority: %d / %d" % [jarl_data.current_authority, jarl_data.max_authority]
	_populate_legacy_buttons()

func _populate_legacy_buttons() -> void:
	for child in legacy_buttons_container.get_children():
		child.queue_free()
	
	if DynastyManager.loaded_legacy_upgrades.is_empty():
		var placeholder_label = Label.new()
		placeholder_label.text = "No legacy upgrades found."
		legacy_buttons_container.add_child(placeholder_label)
		return
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return

	var is_pious = jarl.has_trait("Pious")

	for upgrade_data in DynastyManager.loaded_legacy_upgrades:
		var current_renown_cost = upgrade_data.renown_cost
		var trait_modifier_text = ""
		
		if is_pious and upgrade_data.effect_key == "UPG_BUILD_CHAPEL":
			current_renown_cost = max(0, upgrade_data.renown_cost - 25)
			trait_modifier_text = " (-25 Pious)"

		var button = Button.new()
		var cost_text = "Cost: %d Renown%s, %d Auth" % [current_renown_cost, trait_modifier_text, upgrade_data.authority_cost]
		
		var title_text = upgrade_data.display_name
		if upgrade_data.required_progress > 1:
			title_text += " (%d/%d)" % [upgrade_data.current_progress, upgrade_data.required_progress]
		
		button.text = "%s\n%s" % [title_text, cost_text]
		button.tooltip_text = upgrade_data.description
		
		# Constrain Legacy Button Icons
		if upgrade_data.icon:
			button.icon = upgrade_data.icon
			button.expand_icon = true
			button.custom_minimum_size = Vector2(0, 64)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var can_buy_renown = jarl.renown >= current_renown_cost
		var can_buy_auth = jarl.current_authority >= upgrade_data.authority_cost
		
		if upgrade_data.is_purchased:
			button.disabled = true
			button.text = "%s (Completed)" % upgrade_data.display_name
		elif not can_buy_renown:
			button.disabled = true
			button.text += "\n(Not enough Renown)"
		elif not can_buy_auth:
			button.disabled = true
			button.text += "\n(Not enough Authority)"
		
		button.pressed.connect(_on_legacy_upgrade_pressed.bind(upgrade_data, current_renown_cost))
		legacy_buttons_container.add_child(button)

func _on_legacy_upgrade_pressed(upgrade_data: LegacyUpgradeData, final_renown_cost: int) -> void:
	if not DynastyManager.can_spend_renown(final_renown_cost):
		EventBus.purchase_failed.emit("Not enough Renown")
		return
	if not DynastyManager.can_spend_authority(upgrade_data.authority_cost):
		EventBus.purchase_failed.emit("Not enough Authority")
		return
	
	var spent_renown = DynastyManager.spend_renown(final_renown_cost)
	var spent_auth = DynastyManager.spend_authority(upgrade_data.authority_cost)
	
	if spent_renown and spent_auth:
		upgrade_data.current_progress += 1
		if upgrade_data.is_purchased:
			DynastyManager.purchase_legacy_upgrade(upgrade_data.effect_key)
			_apply_legacy_upgrade_effect(upgrade_data.effect_key)
		_populate_legacy_buttons()
		EventBus.purchase_successful.emit(upgrade_data.display_name)

func _apply_legacy_upgrade_effect(effect_key: String) -> void:
	match effect_key:
		"UPG_TRELLEBORG":
			if SettlementManager.current_settlement:
				SettlementManager.current_settlement.max_garrison_bonus += 10
				SettlementManager.save_settlement()
		"UPG_JELLING_STONE":
			var jarl = DynastyManager.get_current_jarl()
			if jarl:
				jarl.heir_starting_renown_bonus += 50
				DynastyManager.minimum_inherited_legitimacy = 25
		"UPG_BUILD_CHAPEL":
			Loggie.msg("Applied UPG_BUILD_CHAPEL: Dynasty's piety increased.").domain("UI").info()

# --- Building Tab Functions ---
func _load_building_data() -> void:
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
	var button = Button.new()
	button.text = "%s (Cost: %s)" % [building_data.display_name, _format_cost(building_data.build_cost)]
	
	# Constrain Building Icons
	if building_data.icon:
		button.icon = building_data.icon
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 64)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	button.pressed.connect(_on_buy_button_pressed.bind(building_data))
	build_buttons_container.add_child(button)

func _on_buy_button_pressed(item_data: BuildingData) -> void:
	if not item_data: return
	if SettlementManager.attempt_purchase(item_data.build_cost):
		EventBus.building_ready_for_placement.emit(item_data)
	else:
		Loggie.msg("UI received purchase failure for '%s'." % item_data.display_name).domain("UI").info()

# --- Recruit Tab Functions ---
func _load_unit_data() -> void:
	var dir = DirAccess.open("res://data/units/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var unit_path = "res://data/units/" + file_name
				var unit_data = load(unit_path) as UnitData
				if unit_data and _is_player_unit(unit_data):
					available_units.append(unit_data)
			file_name = dir.get_next()

func _setup_recruit_buttons() -> void:
	for unit_data in available_units:
		var button = Button.new()
		button.text = "%s (Cost: %s)" % [unit_data.display_name, _format_cost(unit_data.spawn_cost)]
		
		# Constrain Recruit Icons
		if unit_data.icon:
			button.icon = unit_data.icon
			button.expand_icon = true
			button.custom_minimum_size = Vector2(0, 64)
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
	if not unit_data: return
	if SettlementManager.attempt_purchase(unit_data.spawn_cost):
		SettlementManager.recruit_unit(unit_data)
