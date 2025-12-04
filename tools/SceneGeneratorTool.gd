# res://tools/GenerateThrallScene.gd
@tool
extends EditorScript

func _run() -> void:
	print("--- Generating Thrall Unit Scene ---")
	
	var source_path = "res://scenes/units/PlayerVikingRaider.tscn"
	var target_path = "res://scenes/units/ThrallUnit.tscn"
	var script_path = "res://scripts/units/ThrallUnit.gd"
	
	if not ResourceLoader.exists(source_path):
		printerr("Source scene not found!")
		return
		
	var base_scene = load(source_path).instantiate()
	
	# 1. Swap Script
	var thrall_script = load(script_path)
	base_scene.set_script(thrall_script)
	
	# 2. Modify Visuals (Optional default tint)
	base_scene.modulate = Color(0.8, 0.8, 0.7) # Drab clothing
	
	# 3. Remove incompatible children if any (like specific weapons)
	# For now we assume the base scene is generic enough.
	
	# 4. Save
	var packed = PackedScene.new()
	packed.pack(base_scene)
	var err = ResourceSaver.save(packed, target_path)
	
	if err == OK:
		print("✅ Thrall Scene Saved: ", target_path)
	else:
		printerr("❌ Failed to save scene: ", err)
		
	base_scene.queue_free()
	EditorInterface.get_resource_filesystem().scan()
