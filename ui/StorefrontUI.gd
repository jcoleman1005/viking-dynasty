#res://scripts/ui/StorefrontUI.gd

extends Control

const LegacyUpgradeData = preload("res://data/legacy/LegacyUpgradeData.gd")
const RICH_TOOLTIP_SCRIPT = preload("res://ui/components/RichTooltipButton.gd")

# --- Reference to the Build Preview ---
@export var building_preview: BuildingPreviewCursor

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
@onready var btn_upgrades: Button = %Btn_LegacyUpgrades
@onready var btn_family: Button = %Btn_Family
@onready var btn_map: Button = %Btn_Map
@onready var btn_end_year: Button = %Btn_EndYear

# --- Data ---
@export var available_buildings: Array[BuildingData] = []
@export var available_units: Array[UnitData] = []
@export var auto_load_units_from_directory: bool = true

# --- State for Refunds ---
var pending_cost: Dictionary = {} 

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.purchase_successful.connect(_on_purchase_successful)
	EventBus.purchase_failed.connect(_on_purchase_failed)
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	
	DynastyManager.jarl_stats_updated.connect(_update_jarl_stats_display)
	DynastyManager.year_ended.connect(_on_year_ended)
	
	_apply_theme_overrides()
	_setup_dock_icons()
	_setup_window_logic()
	
	_load_building_data()
	_load_unit_data()
	
	if DynastyManager.current_jarl:
		_update_jarl_stats_display(DynastyManager.get_current_jarl())
	
	if EventBus.has_signal("units_selected"):
		EventBus.units_selected.connect(_on_units_selected)
	
	# Initial State: Hide Build Button
	if has_node("BottomDeck/BtnBuild"):
		$BottomDeck/BtnBuild.visible = false
	
	_refresh_all()
	
	# LISTEN TO PREVIEW CURSOR FOR REFUNDS
	# (Assumes the Cursor exists in the scene or EventBus signals logic)
	# Since BuildingPreviewCursor is a separate node, we hook into the EventBus 
	# if you have a signal there, OR we trust the cancellation to be handled manually.
	# Ideally, we should add `EventBus.placement_cancelled` signal.
	# For now, we rely on the specific `building_ready_for_placement` flow.

# --- BUILD TAB (UPDATED) ---
func _populate_build_grid() -> void:
	for child in build_grid.get_children(): child.queue_free()
	
	for b_data in available_buildings:
		var btn = Button.new()
		
		if RICH_TOOLTIP_SCRIPT:
			btn.set_script(RICH_TOOLTIP_SCRIPT)
		
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
			
		var details = ""
		if b_data is EconomicBuildingData:
			var eco = b_data as EconomicBuildingData
			details = "[color=green]Production:[/color] %d %s / Year\n" % [eco.base_passive_output, eco.resource_type.capitalize()]
			details += "Capacity: %d Workers" % eco.peasant_capacity
		elif b_data.is_defensive_structure:
			details = "[color=salmon]Defense:[/color] %d Dmg | Range: %.0f" % [b_data.attack_damage, b_data.attack_range]
		
		if b_data.is_territory_hub:
			details += "\n[color=cyan]Territory Hub[/color]"
		elif b_data.extends_territory:
			details += "\n[color=cyan]Extends Territory[/color]"
			
		btn.tooltip_text = "[b]%s[/b]\n[i]%s[/i]\n\n%s\n\n[color=gold]Cost:[/color] %s" % [
			b_data.display_name, 
			b_data.description,
			details,
			_format_cost(b_data.build_cost)
		]
		
		# --- FIX: CALL ECONOMY MANAGER DIRECTLY ---
		btn.pressed.connect(func():
			if EconomyManager.attempt_purchase(b_data.build_cost):
				# Track cost for potential refund
				pending_cost = b_data.build_cost.duplicate()
				
				# Start Placement
				EventBus.building_ready_for_placement.emit(b_data)
				_close_all_windows()
				
				# Connect to cancellation signal ONLY ONCE (via EventBus or direct node finding)
				# For robustness, we will try to find the cursor if it exists, 
				# OR we recommend adding `placement_cancelled` to EventBus.
				# Assuming `BuildingPreviewCursor` is unique in scene:
				var cursor = get_tree().get_first_node_in_group("building_preview_cursor")
				if cursor and not cursor.placement_cancelled.is_connected(_on_placement_cancelled):
					cursor.placement_cancelled.connect(_on_placement_cancelled, CONNECT_ONE_SHOT)
					cursor.placement_completed.connect(_on_placement_completed, CONNECT_ONE_SHOT)
		)
		build_grid.add_child(btn)

# --- NEW: Selection Handler ---
func _on_units_selected(units: Array) -> void:
	var build_btn = get_node_or_null("BottomDeck/BtnBuild")
	if not build_btn: return
	
	if units.is_empty():
		build_btn.visible = false
		# Also close the build window if no one is selected
		# if has_node("BuildWindow") and $BuildWindow.visible: _toggle_window($BuildWindow)
		return

	# Check if ANY selected unit is a builder ( Villager / Peasant )
	var has_builder = false
	for u in units:
		# Check by Class, Group, or Data property
		if u.is_in_group("player_units"): 
			# Refine this check based on your UnitData structure
			# e.g., if u.data.can_build:
			has_builder = true
			break
	
	build_btn.visible = has_builder

# --- NEW: Button Callback (Connect your UI button here) ---
func _on_building_button_pressed(data: BuildingData) -> void:
	# This function should be called when clicking a specific building icon in the BuildWindow
	if is_instance_valid(building_preview):
		building_preview.activate(data)
		
		# Close the window if desired
		# _toggle_window($BuildWindow)
	else:
		Loggie.msg("BuildingPreviewCursor not assigned in StorefrontUI!").domain(LogDomains.UI).error()

func _on_placement_cancelled() -> void:
	if not pending_cost.is_empty():
		EconomyManager.add_resources(pending_cost)
		EventBus.purchase_successful.emit("Refunded") # Just to refresh UI
		pending_cost.clear()

func _on_placement_completed() -> void:
	# Money is already gone, just clear the pending track
	pending_cost.clear()

# --- DOCK & WINDOW LOGIC (UNCHANGED) ---

func _setup_dock_icons() -> void:
	_set_btn_icon(btn_build, "res://ui/assets/icon_build.png")
	_set_btn_icon(btn_recruit, "res://ui/assets/icon_army.png")
	_set_btn_icon(btn_upgrades, "res://ui/assets/icon_crown.png")
	_set_btn_icon(btn_family, "res://ui/assets/icon_family.png")
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
	btn_upgrades.pressed.connect(_toggle_window.bind(legacy_window))
	
	btn_family.pressed.connect(func(): EventBus.dynasty_view_requested.emit())
	btn_map.pressed.connect(func(): EventBus.scene_change_requested.emit(GameScenes.WORLD_MAP))
	btn_end_year.pressed.connect(func(): EventBus.end_year_requested.emit())
	
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
	
func _on_purchase_successful(_item: String) -> void:
	_refresh_all()

func _on_purchase_failed(reason: String) -> void:
	_show_toast(reason, Color.SALMON)

func _show_toast(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.position = get_viewport_rect().size / 2.0 - Vector2(100, 50)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 100, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _on_settlement_loaded(_data: SettlementData) -> void:
	_refresh_all()

func _on_year_ended() -> void:
	_update_garrison_display()
	_refresh_all()

func _update_jarl_stats_display(jarl_data: JarlData) -> void:
	if not jarl_data: return
	if renown_label: renown_label.text = "Renown: %d" % jarl_data.renown
	if authority_label: authority_label.text = "Auth: %d/%d" % [jarl_data.current_authority, jarl_data.max_authority]
	_populate_legacy_buttons()

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
				
			# --- FIX: CALL ECONOMY MANAGER DIRECTLY ---
			btn.pressed.connect(func():
				if EconomyManager.attempt_purchase(u_data.spawn_cost):
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

func _load_building_data() -> void:
	available_buildings.clear()
	
	# 1. Load Hand-Crafted Buildings
	_scan_directory_for_buildings("res://data/buildings/")
	
	# 2. Load AI-Generated Buildings
	_scan_directory_for_buildings("res://data/buildings/generated/")

func _scan_directory_for_buildings(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var full_path = path + file
				var data = load(full_path)
				# Validate it is a building and player is allowed to build it
				if data is BuildingData and data.is_player_buildable: 
					available_buildings.append(data)
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
	for k in cost:
		var display_name = GameResources.get_display_name(k)
		s.append("%d %s" % [cost[k], display_name])
	return ", ".join(s)

func _apply_theme_overrides() -> void:
	var tooltip_bg_path = "res://ui/assets/tooltip_bg.png"
	var default_theme_path = "res://ui/themes/VikingDynastyTheme.tres"
	
	if ResourceLoader.exists(tooltip_bg_path):
		var tooltip_tex = load(tooltip_bg_path)
		var style_tooltip = StyleBoxTexture.new()
		style_tooltip.texture = tooltip_tex
		style_tooltip.content_margin_left = 12
		style_tooltip.content_margin_right = 12
		style_tooltip.content_margin_top = 8
		style_tooltip.content_margin_bottom = 8
		
		if theme == null:
			if ResourceLoader.exists(default_theme_path):
				theme = load(default_theme_path)
			else:
				theme = Theme.new()

		theme = theme.duplicate() 
		self.theme = theme
		
		theme.set_stylebox("panel", "TooltipPanel", style_tooltip)
		theme.set_color("font_color", "TooltipLabel", Color.WHITE)
		theme.set_font_size("font_size", "TooltipLabel", 18)
