# res://ui/StorefrontUI.gd
extends Control

const LegacyUpgradeData = preload("res://data/legacy/LegacyUpgradeData.gd")

# --- Header References ---
@onready var gold_label: Label = %GoldLabel
@onready var wood_label: Label = %WoodLabel
@onready var food_label: Label = %FoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var unit_count_label: Label = %UnitCountLabel

# --- Window References ---
@onready var build_window: Control = %BuildWindow
@onready var recruit_window: Control = %RecruitWindow
@onready var legacy_window: Control = %LegacyWindow

# --- Content Containers ---
@onready var build_grid: Container = %BuildGrid
@onready var recruit_list: Container = %RecruitList
@onready var legacy_list: Container = %LegacyList

# --- Legacy Stats ---
@onready var renown_label: Label = %RenownLabel
@onready var authority_label: Label = %AuthorityLabel

# --- Dock Buttons ---
@onready var btn_build: Button = %Btn_Build
@onready var btn_recruit: Button = %Btn_Recruit
@onready var btn_legacy: Button = %Btn_Legacy
@onready var btn_map: Button = %Btn_Map
@onready var btn_end_year: Button = %Btn_EndYear

# --- Data ---
@export var available_buildings: Array[BuildingData] = []
@export var available_units: Array[UnitData] = []
@export var default_treasury_display: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var auto_load_units_from_directory: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.treasury_updated.connect(_update_treasury_display)
	EventBus.purchase_successful.connect(_on_purchase_successful)
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	DynastyManager.jarl_stats_updated.connect(_update_jarl_stats_display)
	DynastyManager.year_ended.connect(_update_garrison_display)
	
	_apply_theme_overrides()
	_setup_dock_icons()
	_setup_window_logic()
	
	call_deferred("_update_initial_treasury")
	_load_building_data()
	_load_unit_data()
	
	if DynastyManager.current_jarl:
		_update_jarl_stats_display(DynastyManager.get_current_jarl())
	
	_refresh_all()

# --- VISUAL SETUP ---
func _apply_theme_overrides() -> void:
	var tag_path = "res://ui/assets/resource_tag.png"
	var font_path = "res://assets/fonts/UncialAntiqua-Regular.ttf"
	var tooltip_bg_path = "res://ui/assets/tooltip_bg.png"
	var theme_path = "res://ui/themes/VikingDynastyTheme.tres"
	
	var plaque_tex = load(tag_path) if ResourceLoader.exists(tag_path) else null
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	var tooltip_tex = load(tooltip_bg_path) if ResourceLoader.exists(tooltip_bg_path) else null
	
	# 1. Resource Labels
	if plaque_tex and font:
		var style = StyleBoxTexture.new()
		style.texture = plaque_tex
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		
		var labels = [gold_label, wood_label, food_label, stone_label, unit_count_label]
		for lbl in labels:
			if lbl:
				lbl.add_theme_stylebox_override("normal", style)
				lbl.add_theme_font_override("font", font)
				lbl.add_theme_font_size_override("font_size", 32) 
				lbl.add_theme_color_override("font_color", Color("#f5e6d3"))
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.custom_minimum_size.y = 60
	
	# 2. Tooltip Styling
	if tooltip_tex:
		var style_tooltip = StyleBoxTexture.new()
		style_tooltip.texture = tooltip_tex
		style_tooltip.content_margin_left = 12
		style_tooltip.content_margin_right = 12
		style_tooltip.content_margin_top = 8
		style_tooltip.content_margin_bottom = 8
		
		# --- FIX: SAFELY LOAD THEME ---
		# If self.theme is null, load it from disk.
		var base_theme = theme
		if not base_theme:
			if ResourceLoader.exists(theme_path):
				base_theme = load(theme_path)
			else:
				base_theme = Theme.new() # Fallback if file missing
		
		# Duplicate to create local override
		theme = base_theme.duplicate()
		self.theme = theme 
		# ------------------------------
		
		theme.set_stylebox("panel", "TooltipPanel", style_tooltip)
		theme.set_color("font_color", "TooltipLabel", Color.WHITE)
		theme.set_font_size("font_size", "TooltipLabel", 18)

func _setup_dock_icons() -> void:
	_set_btn_icon(btn_build, "res://ui/assets/icon_build.png")
	_set_btn_icon(btn_recruit, "res://ui/assets/icon_army.png")
	_set_btn_icon(btn_legacy, "res://ui/assets/icon_crown.png")
	_set_btn_icon(btn_map, "res://ui/assets/icon_map.png")
	_set_btn_icon(btn_end_year, "res://ui/assets/icon_time.png")

func _set_btn_icon(btn: Button, path: String) -> void:
	if btn and ResourceLoader.exists(path):
		btn.icon = load(path)
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(80, 80) 
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

func _setup_window_logic() -> void:
	btn_build.pressed.connect(_toggle_window.bind(build_window))
	btn_recruit.pressed.connect(_toggle_window.bind(recruit_window))
	btn_legacy.pressed.connect(_toggle_window.bind(legacy_window))
	
	# --- ACTIONS ---
	btn_map.pressed.connect(func(): EventBus.scene_change_requested.emit("world_map"))
	
	# FIX: Connect End Year button
	btn_end_year.pressed.connect(func(): EventBus.end_year_requested.emit())
	# ---------------
	
	var windows = [build_window, recruit_window, legacy_window]
	for win in windows:
		if win:
			win.mouse_entered.connect(func(): EventBus.camera_input_lock_requested.emit(true))
			win.mouse_exited.connect(func(): EventBus.camera_input_lock_requested.emit(false))
	
	_close_all_windows()

func _toggle_window(target_window: Control) -> void:
	if not target_window.visible:
		_close_all_windows()
		target_window.show()
	else:
		target_window.hide()

func _close_all_windows() -> void:
	if build_window: build_window.hide()
	if recruit_window: recruit_window.hide()
	if legacy_window: legacy_window.hide()
	EventBus.camera_input_lock_requested.emit(false)

func _refresh_all() -> void:
	_populate_build_grid()
	_update_garrison_display()
	_populate_legacy_buttons()
	
func _update_treasury_display(treasury: Dictionary) -> void:
	gold_label.text = "%d" % treasury.get("gold", 0)
	wood_label.text = "%d" % treasury.get("wood", 0)
	food_label.text = "%d" % treasury.get("food", 0)
	stone_label.text = "%d" % treasury.get("stone", 0)
	if SettlementManager.current_settlement:
		unit_count_label.text = "%d" % SettlementManager.current_settlement.warbands.size()

func _update_initial_treasury() -> void:
	await get_tree().process_frame
	if SettlementManager.current_settlement and SettlementManager.current_settlement.treasury:
		_update_treasury_display(SettlementManager.current_settlement.treasury)

func _on_purchase_successful(_item: String) -> void:
	_refresh_all()

func _on_settlement_loaded(data: SettlementData) -> void:
	if data: _update_treasury_display(data.treasury)
	_refresh_all()

func _update_jarl_stats_display(jarl_data: JarlData) -> void:
	if not jarl_data: return
	if renown_label: renown_label.text = "Renown: %d" % jarl_data.renown
	if authority_label: authority_label.text = "Auth: %d/%d" % [jarl_data.current_authority, jarl_data.max_authority]
	_populate_legacy_buttons()

# --- BUILD TAB ---
func _populate_build_grid() -> void:
	for child in build_grid.get_children(): child.queue_free()
	
	for b_data in available_buildings:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(110, 110) 
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.expand_icon = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.clip_text = true
		
		if b_data.icon:
			btn.icon = b_data.icon
		else:
			btn.text = b_data.display_name 
			
		if b_data.icon: btn.text = b_data.display_name
		
		btn.tooltip_text = "[b]%s[/b]\nCost: %s\n%s" % [
			b_data.display_name, 
			_format_cost(b_data.build_cost),
			"Generates resources" if b_data is EconomicBuildingData else "Defensive Structure"
		]
		
		btn.pressed.connect(func():
			if SettlementManager.attempt_purchase(b_data.build_cost):
				EventBus.building_ready_for_placement.emit(b_data)
				_close_all_windows()
		)
		build_grid.add_child(btn)

# --- RECRUIT TAB ---
func _update_garrison_display() -> void:
	if recruit_list:
		for child in recruit_list.get_children(): child.queue_free()
		
		var header = Label.new()
		header.text = "Active Warbands"
		header.add_theme_color_override("font_color", Color("#c5a54e")) 
		recruit_list.add_child(header)
		
		if SettlementManager.current_settlement:
			for warband in SettlementManager.current_settlement.warbands:
				_create_warband_entry(warband)
		
		var sep = HSeparator.new()
		recruit_list.add_child(sep)
		var header2 = Label.new()
		header2.text = "Recruit New"
		header2.add_theme_color_override("font_color", Color("#c5a54e"))
		recruit_list.add_child(header2)
		
		for u_data in available_units:
			var btn = Button.new()
			btn.text = "%s (%s)" % [u_data.display_name, _format_cost(u_data.spawn_cost)]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if u_data.icon:
				btn.icon = u_data.icon
				btn.expand_icon = true
				btn.custom_minimum_size = Vector2(0, 48)
			btn.pressed.connect(func():
				if SettlementManager.attempt_purchase(u_data.spawn_cost):
					SettlementManager.recruit_unit(u_data)
					_refresh_all()
			)
			recruit_list.add_child(btn)

func _create_warband_entry(warband: WarbandData) -> void:
	var row = HBoxContainer.new()
	recruit_list.add_child(row)
	
	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.custom_minimum_size = Vector2(250, 40)
	
	var jarl_name = "Jarl"
	if DynastyManager.current_jarl: jarl_name = DynastyManager.current_jarl.display_name
	
	lbl.text = "[b]%s[/b] (Lvl %d)\n%s" % [warband.custom_name, warband.get_level(), warband.get_loyalty_description(jarl_name)]
	row.add_child(lbl)
	
	if warband.gear_tier < WarbandData.MAX_GEAR_TIER:
		var btn = Button.new()
		btn.text = "^ %d G" % warband.get_gear_cost()
		btn.pressed.connect(SettlementManager.upgrade_warband_gear.bind(warband))
		row.add_child(btn)
		
	var guard = Button.new()
	guard.text = "G"
	guard.tooltip_text = "Toggle Hearth Guard"
	if warband.is_hearth_guard: guard.modulate = Color.CYAN
	guard.pressed.connect(SettlementManager.toggle_hearth_guard.bind(warband))
	row.add_child(guard)

# --- LEGACY TAB ---
func _populate_legacy_buttons() -> void:
	if not legacy_list: return
	for child in legacy_list.get_children(): child.queue_free()
	
	if DynastyManager.loaded_legacy_upgrades.is_empty():
		var label = Label.new()
		label.text = "No upgrades available."
		legacy_list.add_child(label)
		return
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	var is_pious = jarl.has_trait("Pious")

	for upgrade_data in DynastyManager.loaded_legacy_upgrades:
		var current_renown_cost = upgrade_data.renown_cost
		if is_pious and upgrade_data.effect_key == "UPG_BUILD_CHAPEL":
			current_renown_cost = max(0, upgrade_data.renown_cost - 25)

		var btn = Button.new()
		var cost_text = "Cost: %d Renown, %d Auth" % [current_renown_cost, upgrade_data.authority_cost]
		btn.text = "%s\n%s" % [upgrade_data.display_name, cost_text]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if upgrade_data.is_purchased:
			btn.disabled = true
			btn.text = "%s (Owned)" % upgrade_data.display_name
			
		btn.pressed.connect(func():
			if DynastyManager.spend_renown(upgrade_data.renown_cost) and DynastyManager.spend_authority(upgrade_data.authority_cost):
				DynastyManager.purchase_legacy_upgrade(upgrade_data.effect_key)
				_refresh_all()
		)
		legacy_list.add_child(btn)

# --- LOADING ---
func _load_building_data() -> void:
	var dir = DirAccess.open("res://data/buildings/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var data = load("res://data/buildings/" + file)
				if data and data.is_player_buildable: available_buildings.append(data)
			file = dir.get_next()

func _load_unit_data() -> void:
	var dir = DirAccess.open("res://data/units/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var data = load("res://data/units/" + file)
				if data and "Player" in data.resource_path: available_units.append(data)
			file = dir.get_next()

func _format_cost(cost: Dictionary) -> String:
	var s = []
	for k in cost: s.append("%d %s" % [cost[k], k])
	return ", ".join(s)
	
