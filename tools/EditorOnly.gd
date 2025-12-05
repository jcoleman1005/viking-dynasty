# res://tools/FixUnitData.gd
@tool
extends EditorScript

const AI_SCENE_PATH = "res://scenes/components/AttackAI.tscn"

func _run() -> void:
	print("--- 🛠️ Repairing Unit Data ---")
	
	var ai_scene = load(AI_SCENE_PATH)
	if not ai_scene:
		printerr("CRITICAL: AttackAI scene not found at ", AI_SCENE_PATH)
		return

	var units_to_fix = [
		"res://data/units/Unit_Bondi.tres",
		"res://data/units/Unit_Drengr.tres"
	]
	
	for path in units_to_fix:
		if ResourceLoader.exists(path):
			var data = load(path) as UnitData
			var dirty = false
			
			# 1. Fix Missing AI
			if data.ai_component_scene == null:
				print(" > Fixing Missing AI for: ", data.display_name)
				data.ai_component_scene = ai_scene
				dirty = true
				
			# 2. Fix Zero Ranges (Safety Check)
			if data.building_attack_range <= 1.0:
				print(" > Fixing Zero Range for: ", data.display_name)
				data.building_attack_range = 45.0
				data.attack_range = 15.0
				dirty = true
			
			if dirty:
				ResourceSaver.save(data, path)
				print(" ✅ Saved repair for ", path.get_file())
			else:
				print(" 👍 ", data.display_name, " is already healthy.")
		else:
			print(" ⚠️ Skipped missing file: ", path)
			
	print("--- Repair Complete. Restart game to apply. ---")
