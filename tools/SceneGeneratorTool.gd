# res://tools/GenerateDrengr.gd
@tool
extends EditorScript

func _run():
	print("--- Generating Drengr Unit (Historical Update) ---")
	
	# 1. Create Unit Data
	var data = UnitData.new()
	data.display_name = "Drengr" 
	
	# STATS: High Risk / High Reward
	data.max_health = 45 
	data.attack_damage = 12 
	data.attack_speed = 1.4 
	data.move_speed = 85.0 
	data.spawn_cost = {"food": 0} 
	
	# Link to Scene
	data.scene_path = "res://scenes/units/Drengr.tscn"
	
	# Load Icon (Reuse existing)
	if ResourceLoader.exists("res://textures/units/viking_raider_sprite.png"):
		data.icon = load("res://textures/units/viking_raider_sprite.png")
		data.visual_texture = data.icon
	
	# Save Data
	ResourceSaver.save(data, "res://data/units/Unit_Drengr.tres")
	print("Saved Data: res://data/units/Unit_Drengr.tres")
	
	# 2. Create Visual Scene
	var source_path = "res://scenes/units/PlayerVikingRaider.tscn"
	if ResourceLoader.exists(source_path):
		var base_scene = load(source_path).instantiate()
		base_scene.modulate = Color(0.9, 0.4, 0.4) # Reddish tint
		
		var packed = PackedScene.new()
		packed.pack(base_scene)
		ResourceSaver.save(packed, "res://scenes/units/Drengr.tscn")
		print("Saved Scene: res://scenes/units/Drengr.tscn")
		base_scene.queue_free()
	else:
		printerr("Could not find source scene to clone!")
		
	EditorInterface.get_resource_filesystem().scan()
