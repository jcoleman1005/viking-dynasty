# res://ui/StorefrontUI.gd
extends Control

const LegacyUpgradeData = preload("res://data/legacy/LegacyUpgradeData.gd")

# --- Header References (Permanent HUD) ---
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
@export var available_buildings: Array = []
@export var available_units: Array = []
@export var default_treasury_display: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var auto_load_units_from_directory: bool = true

func _ready() -> void:
	Loggie.info("StorefrontUI initializing", "StorefrontUI")
	
	# -----------------------------------------------------------------------
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Connect signals
	EventBus.treasury_updated.connect(_update_treasury_display)
	EventBus.purchase_successful.connect(_on_purchase_successful)
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	DynastyManager.jarl_stats_updated.connect(_update_jarl_stats_display)
	DynastyManager.year_ended.connect(_update_garrison_display)
	Loggie.debug("Event Bus signals connected", "StorefrontUI")
	
	# Initial Setup
	call_deferred("_update_initial_treasury")
	_load_building_data()
	_load_unit_data()
	
	if DynastyManager.current_jarl:
		_update_jarl_stats_display(DynastyManager.get_current_jarl())
		Loggie.debug("Jarl stats loaded for: %s" % DynastyManager.current_jarl.display_name, "StorefrontUI")
	else:
		Loggie.warn("No current jarl found during StorefrontUI initialization", "StorefrontUI")
	
	_setup_recruit_buttons()
	_update_garrison_display()
	_populate_legacy_buttons()
	
	Loggie.info("StorefrontUI initialization complete", "StorefrontUI") 

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

func _on_purchase_successful(_item_name: String) -> void:
	_update_garrison_display()

func _on_settlement_loaded(settlement_data: SettlementData) -> void:
	if settlement_data and settlement_data.treasury:
		_update_treasury_display(settlement_data.treasury)
	else:
		_update_treasury_display(default_treasury_display)
	_update_garrison_display()

func _update_initial_treasury() -> void:
	var attempts := 0
	var max_attempts := 30
	while (SettlementManager.current_settlement == null or SettlementManager.current_settlement.treasury == null) and attempts < max_attempts:
		await get_tree().process_frame
		attempts += 1

	if SettlementManager.current_settlement and SettlementManager.current_settlement.treasury:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		_update_treasury_display(default_treasury_display)

# --- WARBAND GARRISON DISPLAY ---
func _update_garrison_display() -> void:
	# 1. Update the Detailed List
	if garrison_list_container:
		for child in garrison_list_container.get_children():
			child.queue_free()
		
		if SettlementManager.current_settlement and not SettlementManager.current_settlement.warbands.is_empty():
			var header_label := Label.new()
			header_label.text = "Active Warbands:"
			header_label.add_theme_font_size_override("font_size", 16)
			garrison_list_container.add_child(header_label)
			
			for warband in SettlementManager.current_settlement.warbands:
				# --- UI CHANGE: Use RichTextLabel ---
				# We need RichTextLabel for the colors to work.
				# Since the container expects Control nodes, we can swap Label for RichTextLabel.
				var unit_label := RichTextLabel.new()
				unit_label.fit_content = true
				unit_label.bbcode_enabled = true
				unit_label.custom_minimum_size = Vector2(300, 24) # Ensure width
				
				var status = ""
				if warband.is_wounded: status += " [color=red](Wounded)[/color]"
				
				# Get Jarl Name for flavor text
				var jarl_name = "the Jarl"
				if DynastyManager.current_jarl:
					jarl_name = DynastyManager.current_jarl.display_name
				
				var loyalty_text = warband.get_loyalty_description(jarl_name)
				
				unit_label.text = "• %s (%d/10) - %s%s" % [
					warband.custom_name, 
					warband.current_manpower,
					loyalty_text,
					status
				]
				
				# Tooltip
				if not warband.history_log.is_empty():
					unit_label.mouse_filter = Control.MOUSE_FILTER_STOP
					unit_label.tooltip_text = "\n".join(warband.history_log)
				
				garrison_list_container.add_child(unit_label)
		else:
			var empty_label := Label.new()
			empty_label.text = "No active warbands."
			garrison_list_container.add_child(empty_label)

	# 2. Update the Permanent Header Count
	var total_units := 0
	if SettlementManager.current_settlement:
		total_units = SettlementManager.current_settlement.warbands.size()
	
	if unit_count_label:
		unit_count_label.text = "Warbands: %d" % total_units
		if total_units == 0:
			unit_count_label.modulate = Color.SALMON
		else:
			unit_count_label.modulate = Color.WHITE

# --- Jarl Stats UI ---
func _update_jarl_stats_display(jarl_data: JarlData) -> void:
	if not jarl_data: return
	
	renown_label.text = "Renown: %d" % jarl_data.renown
	
	# --- CRITICAL FIX: Use 'jarl_data' instead of 'jarl' ---
	authority_label.text = "Authority: %d / %d" % [jarl_data.current_authority, jarl_data.max_authority]
	# -------------------------------------------------------
	
	_populate_legacy_buttons()

func _populate_legacy_buttons() -> void:
	if not legacy_buttons_container: return
	
	for child in legacy_buttons_container.get_children(): 
		child.queue_free()
	
	if DynastyManager.loaded_legacy_upgrades.is_empty():
		var placeholder_label := Label.new()
		placeholder_label.text = "No legacy upgrades found."
		legacy_buttons_container.add_child(placeholder_label)
		return
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return

	var is_pious = jarl.has_trait("Pious")

	for upgrade_data in DynastyManager.loaded_legacy_upgrades:
		var current_renown_cost = upgrade_data.renown_cost
		var trait_modifier_text := ""
		
		if is_pious and upgrade_data.effect_key == "UPG_BUILD_CHAPEL":
			current_renown_cost = max(0, upgrade_data.renown_cost - 25)
			trait_modifier_text = " (-25 Pious)"

		var button := Button.new()
		var cost_text = "Cost: %d Renown%s, %d Auth" % [current_renown_cost, trait_modifier_text, upgrade_data.authority_cost]
		
		var title_text = upgrade_data.display_name
		if upgrade_data.required_progress > 1:
			title_text += " (%d/%d)" % [upgrade_data.current_progress, upgrade_data.required_progress]
		
		button.text = "%s\n%s" % [title_text, cost_text]
		button.tooltip_text = upgrade_data.description
		
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
			Loggie.info("Legacy upgrade applied: Build Chapel - Dynasty's piety increased", "StorefrontUI")

# --- Building Tab Functions ---
func _load_building_data() -> void:
	Loggie.debug("Loading building data from res://data/buildings/", "StorefrontUI")
	var building_count := 0
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
					building_count += 1
			file_name = dir.get_next()
		Loggie.info("Loaded %d player-buildable buildings" % building_count, "StorefrontUI")
	else:
		Loggie.error("Failed to open buildings directory: res://data/buildings/", "StorefrontUI")

func _create_building_button(building_data: BuildingData) -> void:
	var button := Button.new()
	button.text = "%s (Cost: %s)" % [building_data.display_name, _format_cost(building_data.build_cost)]
	
	if building_data.icon:
		button.icon = building_data.icon
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 64)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	button.pressed.connect(_on_buy_button_pressed.bind(building_data))
	build_buttons_container.add_child(button)
	
	Loggie.debug("Building button created: %s" % building_data.display_name, "StorefrontUI")

func _on_buy_button_pressed(item_data: BuildingData) -> void:
	if not item_data:
		return
	if SettlementManager.attempt_purchase(item_data.build_cost):
		EventBus.building_ready_for_placement.emit(item_data)
	else:
		Loggie.info("Purchase failed: %s - insufficient resources" % item_data.display_name, "StorefrontUI")

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
		var button := Button.new()
		button.text = "%s (Cost: %s)" % [unit_data.display_name, _format_cost(unit_data.spawn_cost)]
		
		if unit_data.icon:
			button.icon = unit_data.icon
			button.expand_icon = true
			button.custom_minimum_size = Vector2(0, 64)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

		button.pressed.connect(_on_recruit_button_pressed.bind(unit_data))
		recruit_buttons_container.add_child(button)

func _is_player_unit(unit_data: UnitData) -> bool:
	if not unit_data:
		return false
	if "Player" in unit_data.display_name:
		return true
	if "Player" in unit_data.resource_path:
		return true
	if unit_data.scene_to_spawn and "Player" in unit_data.scene_to_spawn.resource_path:
		return true
	if unit_data.display_name in ["Viking Raider"]:
		return false
	return true

func _on_recruit_button_pressed(unit_data: UnitData) -> void:
	if not unit_data:
		return
	if SettlementManager.attempt_purchase(unit_data.spawn_cost):
		SettlementManager.recruit_unit(unit_data)
