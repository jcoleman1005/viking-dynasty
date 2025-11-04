@tool
extends Control
class_name EnemyBaseEditorDockSimple

# Simple version without programmatic UI creation
# Available buildings cache
var available_buildings: Array[BuildingData] = []

func _ready():
	name = "EnemyBaseEditorDock"
	# Create a simple label to start
	var label = Label.new()
	label.text = "Enemy Base Editor - Simple Version"
	add_child(label)
	
	# Load buildings
	load_available_buildings()

func load_available_buildings():
	available_buildings.clear()
	
	# Load all building data files
	var dir = DirAccess.open("res://data/buildings")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				print("Enemy Base Editor: Attempting to load building file: ", file_name)
				var building_data = load("res://data/buildings/" + file_name)
				# Try to cast to BuildingData or any subclass
				if building_data is BuildingData:
					building_data = building_data as BuildingData
				else:
					building_data = null
				if building_data:
					print("Enemy Base Editor: Successfully loaded building: ", building_data.display_name)
					available_buildings.append(building_data)
				else:
					print("Enemy Base Editor: Failed to load building from: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Enemy Base Editor: Failed to open buildings directory")
	
	print("Enemy Base Editor: Loaded %d building types" % available_buildings.size())
