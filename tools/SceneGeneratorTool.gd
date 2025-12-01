@tool
extends EditorScript

const SCENE_PATH = "res://ui/components/TreasuryHUD.tscn"
const SCRIPT_PATH = "res://ui/components/TreasuryHUD.gd"
const THEME_PATH = "res://ui/themes/VikingDynastyTheme.tres"

# Asset Paths
const ICON_GOLD = "res://ui/assets/res_gold.png"
const ICON_WOOD = "res://ui/assets/res_wood.png"
const ICON_FOOD = "res://ui/assets/res_food.png"
const ICON_STONE = "res://ui/assets/res_stone.png"
const ICON_POP = "res://ui/assets/res_peasant.png"
const ICON_THRALL = "res://ui/assets/res_thrall.png"

func _run() -> void:
	print("--- Generating TreasuryHUD Component ---")
	
	# 1. Root Panel
	var root = PanelContainer.new()
	root.name = "TreasuryHUD"
	
	if ResourceLoader.exists(SCRIPT_PATH):
		root.set_script(load(SCRIPT_PATH))
	if ResourceLoader.exists(THEME_PATH):
		root.theme = load(THEME_PATH)
		
	# Style override to make it look like a distinct bar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.4) # Semi-transparent black backing
	style.set_corner_radius_all(10)
	root.add_theme_stylebox_override("panel", style)

	# 2. HBox Layout
	var hbox = HBoxContainer.new()
	hbox.name = "Layout"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	# Add internal padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	root.add_child(margin)
	margin.set_owner(root)
	margin.add_child(hbox)
	hbox.set_owner(root)
	
	# 3. Add Resources
	hbox.add_child(_create_res_label("ResGold", ICON_GOLD))
	hbox.add_child(_create_res_label("ResWood", ICON_WOOD))
	hbox.add_child(_create_res_label("ResFood", ICON_FOOD))
	hbox.add_child(_create_res_label("ResStone", ICON_STONE))
	
	# Separator
	var vsep = VSeparator.new()
	hbox.add_child(vsep)
	vsep.set_owner(root)
	
	# 4. Add Population
	hbox.add_child(_create_res_label("ResPop", ICON_POP))
	hbox.add_child(_create_res_label("ResThrall", ICON_THRALL))

	# Save
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, SCENE_PATH)
	print("✅ TreasuryHUD saved to: %s" % SCENE_PATH)
	EditorInterface.get_resource_filesystem().scan()

func _create_res_label(name: String, icon_path: String) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.name = name
	container.unique_name_in_owner = true 
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	container.add_child(icon)
	
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = "0"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(lbl)
	
	return container
