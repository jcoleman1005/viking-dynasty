# res://tools/SceneGenerator_RaidPrep.gd
@tool
extends EditorScript

const SCENE_PATH = "res://ui/RaidPrepWindow.tscn"
const SCRIPT_PATH = "res://ui/RaidPrepWindow.gd"

func _run() -> void:
	print("--- Generating Raid Prep Window Scene (v3 - Bondi) ---")
	
	var root = PanelContainer.new()
	root.name = "RaidPrepWindow"
	var script = load(SCRIPT_PATH)
	if not script:
		printerr("Error: Could not find script at ", SCRIPT_PATH)
		return
	root.set_script(script)
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	root.add_child(margin)
	margin.set_owner(root)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)
	main_vbox.set_owner(root)
	
	# Header
	var header = Label.new()
	header.name = "HeaderLabel"
	header.text = "Muster the Leidang" # Historically accurate flavor!
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(header)
	header.set_owner(root)
	
	var sep1 = HSeparator.new()
	sep1.name = "HSeparator"
	main_vbox.add_child(sep1)
	sep1.set_owner(root)
	
	# Content
	var content_hbox = HBoxContainer.new()
	content_hbox.name = "ContentHBox"
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(content_hbox)
	content_hbox.set_owner(root)
	
	# --- LEFT COL ---
	var left_col = VBoxContainer.new()
	left_col.name = "LeftCol"
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(left_col)
	left_col.set_owner(root)
	
	var target_name = Label.new()
	target_name.name = "TargetNameLabel"
	target_name.text = "Target Name"
	target_name.add_theme_font_size_override("font_size", 20)
	target_name.add_theme_color_override("font_color", Color.GOLD)
	left_col.add_child(target_name)
	target_name.set_owner(root)
	
	var desc_label = RichTextLabel.new()
	desc_label.name = "DescriptionLabel"
	desc_label.text = "Description goes here..."
	desc_label.fit_content = true
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(desc_label)
	desc_label.set_owner(root)
	
	var stats_grid = GridContainer.new()
	stats_grid.name = "StatsGrid"
	stats_grid.columns = 2
	left_col.add_child(stats_grid)
	stats_grid.set_owner(root)
	
	_add_stat_row(stats_grid, root, "LabelDiff", "Difficulty:", "ValDiff", "1 Star")
	_add_stat_row(stats_grid, root, "LabelCost", "Auth Cost:", "ValCost", "1")
	_add_stat_row(stats_grid, root, "LabelTravel", "Travel Time:", "ValTravel", "Medium")
	
	# Separator
	var vsep = VSeparator.new()
	vsep.name = "VSeparator"
	content_hbox.add_child(vsep)
	vsep.set_owner(root)
	
	# --- RIGHT COL (Muster) ---
	var right_col = VBoxContainer.new()
	right_col.name = "RightCol"
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_col)
	right_col.set_owner(root)
	
	var cap_label = Label.new()
	cap_label.name = "CapacityLabel"
	cap_label.text = "Fleet Capacity: 0/4"
	cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_col.add_child(cap_label)
	cap_label.set_owner(root)
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)
	scroll.set_owner(root)
	
	var warband_list = VBoxContainer.new()
	warband_list.name = "WarbandList"
	warband_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(warband_list)
	warband_list.set_owner(root)
	
	# --- NEW: BONDI PANEL ---
	var bondi_panel = PanelContainer.new()
	bondi_panel.name = "BondiPanel"
	right_col.add_child(bondi_panel)
	bondi_panel.set_owner(root)
	
	var bondi_vbox = VBoxContainer.new()
	bondi_vbox.name = "BondiVBox"
	bondi_panel.add_child(bondi_vbox)
	bondi_vbox.set_owner(root)
	
	var bondi_label = Label.new()
	bondi_label.name = "BondiLabel"
	bondi_label.text = "Call the Bondi (Farmers)"
	bondi_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	bondi_vbox.add_child(bondi_label)
	bondi_label.set_owner(root)
	
	var bondi_slider_box = HBoxContainer.new()
	bondi_slider_box.name = "BondiSliderBox"
	bondi_vbox.add_child(bondi_slider_box)
	bondi_slider_box.set_owner(root)
	
	var bondi_slider = HSlider.new()
	bondi_slider.name = "BondiSlider"
	bondi_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bondi_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bondi_slider.min_value = 0
	bondi_slider.max_value = 10
	bondi_slider_box.add_child(bondi_slider)
	bondi_slider.set_owner(root)
	
	var bondi_count_lbl = Label.new()
	bondi_count_lbl.name = "BondiCountLabel"
	bondi_count_lbl.text = "0 / 10"
	bondi_count_lbl.custom_minimum_size.x = 60
	bondi_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bondi_slider_box.add_child(bondi_count_lbl)
	bondi_count_lbl.set_owner(root)
	
	# --- BOTTOM SECTION ---
	var sep2 = HSeparator.new()
	sep2.name = "HSeparator2"
	main_vbox.add_child(sep2)
	sep2.set_owner(root)
	
	var prov_panel = PanelContainer.new()
	prov_panel.name = "ProvisionsPanel"
	main_vbox.add_child(prov_panel)
	prov_panel.set_owner(root)
	
	var prov_hbox = HBoxContainer.new()
	prov_hbox.name = "HBox"
	prov_panel.add_child(prov_hbox)
	prov_hbox.set_owner(root)
	
	var l_supplies = Label.new()
	l_supplies.name = "Label"
	l_supplies.text = "Supplies:"
	prov_hbox.add_child(l_supplies)
	l_supplies.set_owner(root)
	
	var slider = HSlider.new()
	slider.name = "ProvisionSlider"
	slider.min_value = 0
	slider.max_value = 2
	slider.value = 1
	slider.tick_count = 3
	slider.ticks_on_borders = true
	slider.custom_minimum_size.x = 150
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prov_hbox.add_child(slider)
	slider.set_owner(root)
	
	var cost_l = Label.new()
	cost_l.name = "CostLabel"
	cost_l.text = "0 Food"
	prov_hbox.add_child(cost_l)
	cost_l.set_owner(root)
	
	var eff_l = Label.new()
	eff_l.name = "EffectLabel"
	eff_l.text = "Normal Risk"
	eff_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prov_hbox.add_child(eff_l)
	eff_l.set_owner(root)
	
	var actions = HBoxContainer.new()
	actions.name = "ActionButtons"
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 20)
	main_vbox.add_child(actions)
	actions.set_owner(root)
	
	var btn_cancel = Button.new()
	btn_cancel.name = "CancelButton"
	btn_cancel.text = "Cancel"
	btn_cancel.custom_minimum_size = Vector2(100, 40)
	actions.add_child(btn_cancel)
	btn_cancel.set_owner(root)
	
	var btn_launch = Button.new()
	btn_launch.name = "LaunchButton"
	btn_launch.text = "Set Sail"
	btn_launch.custom_minimum_size = Vector2(120, 40)
	actions.add_child(btn_launch)
	btn_launch.set_owner(root)
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(root)
	var error = ResourceSaver.save(packed_scene, SCENE_PATH)
	if error == OK:
		print("✅ Scene generated: ", SCENE_PATH)
		EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("❌ Failed to save scene: ", error)

func _add_stat_row(parent, owner, label_name, label_text, val_name, val_text):
	var l = Label.new()
	l.name = label_name
	l.text = label_text
	l.modulate = Color.LIGHT_GRAY
	parent.add_child(l)
	l.set_owner(owner)
	
	var v = Label.new()
	v.name = val_name
	v.text = val_text
	parent.add_child(v)
	v.set_owner(owner)
