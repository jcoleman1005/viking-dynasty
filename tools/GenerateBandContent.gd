#res://tools/GenerateBandContent.gd
# res://tools/GenerateBondiContent.gd
@tool
extends EditorScript

func _run():
	print("--- Generating Bondi Content ---")
	
	# 1. Create Unit Data
	var bondi_data = UnitData.new()
	bondi_data.display_name = "Bondi"
	bondi_data.max_health = 40 # Slightly tougher than a peasant
	bondi_data.attack_damage = 6 
	bondi_data.move_speed = 75.0
	bondi_data.spawn_cost = {"food": 0} # Costs population to draft
	
	# Link to the scene
	bondi_data.scene_path = "res://scenes/units/Bondi.tscn"
	
	# Load visual
	if ResourceLoader.exists("res://ui/assets/res_peasant.png"):
		bondi_data.icon = load("res://ui/assets/res_peasant.png")
	
	# Save Data
	ResourceSaver.save(bondi_data, "res://data/units/Unit_Bondi.tres")
	print("Saved UnitData: res://data/units/Unit_Bondi.tres")
	
	# 2. Create Unit Scene
	var source_path = "res://scenes/units/PlayerVikingRaider.tscn"
	if ResourceLoader.exists(source_path):
		var base_scene = load(source_path).instantiate()
		
		# Tint them brownish/green to look like farmers
		base_scene.modulate = Color(0.6, 0.7, 0.5) 
		
		var packed = PackedScene.new()
		packed.pack(base_scene)
		ResourceSaver.save(packed, "res://scenes/units/Bondi.tscn")
		print("Saved Scene: res://scenes/units/Bondi.tscn")
		base_scene.queue_free()
	else:
		printerr("Could not find source scene to clone!")
		
	EditorInterface.get_resource_filesystem().scan()
