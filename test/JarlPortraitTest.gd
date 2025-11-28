@tool
extends EditorScript

# INSTRUCTIONS FOR JUNIOR CODER:
# 1. Implement the system as described.
# 2. Create at least 3 dummy PortraitPartData resources (e.g. 1 Head, 1 Beard, 1 Body) 
#    and put them in "res://data/portraits/parts/".
# 3. Run this script. If it prints "TEST PASSED", you are ready to merge.

func _run():
	print("--- STARTING PORTRAIT SYSTEM SMOKE TEST ---")
	
	# 1. Test Resource Loading
	var parts_dir = "res://data/portraits/parts/"
	var dir = DirAccess.open(parts_dir)
	if not dir:
		_fail("Could not open directory: " + parts_dir + ". Did you create the folder structure?")
		return
		
	print("Directory found. Scanning for parts...")
	
	# 2. Test Generator Scene Instantiation
	var generator_scene = load("res://scenes/ui/PortraitGenerator.tscn")
	if not generator_scene:
		_fail("Could not load PortraitGenerator.tscn")
		return
		
	var generator = generator_scene.instantiate()
	if not generator.has_method("build_portrait"):
		_fail("PortraitGenerator.gd is missing the 'build_portrait()' function.")
		generator.free()
		return
		
	# 3. Test Configuration Injection
	var test_config = {
		"skin_color": Color.BISQUE,
		"hair_color": Color.ORANGE_RED,
		"head_id": "head_01", # Ensure you created a dummy resource with this ID
		"body_id": "body_01"
	}
	
	print("Attempting to build portrait with config: ", test_config)
	
	# We wrap this in a try/catch block equivalent (Godot doesn't have strict try/catch, 
    # so we rely on the function not crashing).
	generator.build_portrait(test_config)
	
	# 4. Verify Visuals (Logic Check)
	var head_node = generator.get_node_or_null("Head")
	if not head_node:
		_fail("PortraitGenerator scene is missing 'Head' TextureRect.")
		generator.free()
		return
		
	if head_node.self_modulate != test_config.skin_color:
		_fail("Color application failed. Head color does not match config.")
		generator.free()
		return

	print("✅ VISUAL CHECK PASSED: Color applied correctly.")
	print("✅ INSTANTIATION PASSED: Scene loaded.")
	print("---------------------------------------------")
	print("SMOKE TEST PASSED: System is functional.")
	
	generator.free()

func _fail(reason: String):
	printerr("❌ TEST FAILED: " + reason)
