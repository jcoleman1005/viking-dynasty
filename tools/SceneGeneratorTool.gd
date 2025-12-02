# res://tools/GenerateBuildingInspector.gd
@tool
extends EditorScript

const SCENE_PATH = "res://ui/components/BuildingInspector.tscn"
const SCRIPT_PATH = "res://ui/components/BuildingInspector.gd"

# Visual Constants matching your Theme
const COL_INK = Color("#2b221b") 

func _run() -> void:
	print("--- Generating Building Inspector (v2) ---")
	
	var root = PanelContainer.new()
	root.name = "BuildingInspector"
	
	if ResourceLoader.exists(SCRIPT_PATH):
		root.set_script(load(SCRIPT_PATH))
	
	# We rely on the Theme (Parchment) instead of forcing a dark box
	# giving it a min-width ensures it doesn't feel cramped
	root.custom_minimum_size.x = 280

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	root.add_child(margin)
	margin.set_owner(root)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	vbox.set_owner(root)
	
	# --- Header ---
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header)
	header.set_owner(root)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.unique_name_in_owner = true
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	icon.set_owner(root)
	
	var title = Label.new()
	title.name = "NameLabel"
	title.unique_name_in_owner = true
	title.text = "Building Name"
	# Use the Header variation from ThemeBuilder
	title.theme_type_variation = "HeaderLabel" 
	header.add_child(title)
	title.set_owner(root)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	sep.set_owner(root)
	
	# --- Stats (The Fix) ---
	var stats = RichTextLabel.new()
	stats.name = "StatsLabel"
	stats.unique_name_in_owner = true
	stats.text = "Production: 100\nWorkers: 0/5"
	
	# CRITICAL SETTINGS FOR VISIBILITY
	stats.fit_content = true
	stats.scroll_active = false # Required for fit_content to work in Containers
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.bbcode_enabled = true
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Force color to Ink (Dark) to ensure contrast on Parchment
	stats.add_theme_color_override("default_color", COL_INK)
	
	vbox.add_child(stats)
	stats.set_owner(root)
	
	# --- Worker Controls ---
	var worker_box = HBoxContainer.new()
	worker_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(worker_box)
	worker_box.set_owner(root)
	
	var lbl_assign = Label.new()
	lbl_assign.text = "Assign Worker:"
	worker_box.add_child(lbl_assign)
	lbl_assign.set_owner(root)
	
	var btn_rem = Button.new()
	btn_rem.name = "BtnRemove"
	btn_rem.unique_name_in_owner = true
	btn_rem.text = " - "
	btn_rem.custom_minimum_size = Vector2(32, 32)
	worker_box.add_child(btn_rem)
	btn_rem.set_owner(root)
	
	var count_lbl = Label.new()
	count_lbl.name = "WorkerCountLabel"
	count_lbl.unique_name_in_owner = true
	count_lbl.text = "0 / 5"
	count_lbl.custom_minimum_size.x = 60
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worker_box.add_child(count_lbl)
	count_lbl.set_owner(root)
	
	var btn_add = Button.new()
	btn_add.name = "BtnAdd"
	btn_add.unique_name_in_owner = true
	btn_add.text = " + "
	btn_add.custom_minimum_size = Vector2(32, 32)
	worker_box.add_child(btn_add)
	btn_add.set_owner(root)
	
	# Save
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, SCENE_PATH)
	print("✅ BuildingInspector updated at: ", SCENE_PATH)
	EditorInterface.get_resource_filesystem().scan()
