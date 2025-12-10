class_name TestUtils
extends RefCounted

# Standard Dummy Data to prevent null crashes
static func create_dummy_data() -> UnitData:
	var d = UnitData.new()
	d.max_loot_capacity = 100
	d.move_speed = 100.0
	d.encumbrance_speed_penalty = 0.5
	d.wergild_cost = 50
	return d

# The Universal Unit Creator
static func create_mock_unit(unit_class, parent_node: Node, data_override: UnitData = null) -> Node2D:
	var unit = unit_class.new()
	
	# 1. Assign Data
	unit.data = data_override if data_override else create_dummy_data()
	
	# 2. Mock Sprite (Prevents "Sprite2D" crashes)
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(img)
	unit.add_child(sprite)
	
	# 3. Mock Physics (Prevents "CollisionShape2D" crashes)
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	unit.add_child(col)
	
	# 4. Mock Timers
	var timer = Timer.new()
	timer.name = "AttackTimer"
	unit.add_child(timer)
	
	# 5. Mock Separation Area (Detailed Structure)
	var sep = Area2D.new()
	sep.name = "SeparationArea"
	var sep_col = CollisionShape2D.new()
	sep_col.name = "CollisionShape2D" # Critical Name
	sep_col.shape = CircleShape2D.new()
	sep_col.shape.radius = 15.0
	sep.add_child(sep_col)
	unit.add_child(sep)
	
	# 6. Force Brain Init (Prevents Race Conditions in Tests)
	if not unit.fsm:
		unit.fsm = UnitFSM.new(unit, null)
		
	# 7. Add to Scene (Triggers _ready)
	if parent_node:
		parent_node.add_child(unit)
	
	return unit

# UI Mocker for EndOfYear Popup
static func create_mock_end_year_popup() -> PanelContainer:
	var root = PanelContainer.new()
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	root.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)
	
	var label = RichTextLabel.new()
	label.name = "PayoutLabel"
	vbox.add_child(label)
	
	var loot_panel = PanelContainer.new()
	loot_panel.name = "LootDistributionPanel"
	vbox.add_child(loot_panel)
	
	var slider = HSlider.new()
	slider.name = "LootSlider"
	loot_panel.add_child(slider)
	
	var dist_label = Label.new()
	dist_label.name = "DistributionResultLabel"
	vbox.add_child(dist_label)
	
	var btn = Button.new()
	btn.name = "CollectButton"
	vbox.add_child(btn)
	
	var script = load("res://ui/EndOfYear_Popup.gd")
	root.set_script(script)
	
	return root

static func create_mock_bridge() -> Node:
	var bridge_script = load("res://scripts/buildings/SettlementBridge.gd")
	var bridge = bridge_script.new()
	
	# Mock the dependencies that cause crashes
	var unit_cont = Node2D.new()
	unit_cont.name = "UnitContainer"
	bridge.add_child(unit_cont)
	
	var ui_node = CanvasLayer.new()
	ui_node.name = "UI"
	bridge.add_child(ui_node)
	
	return bridge
