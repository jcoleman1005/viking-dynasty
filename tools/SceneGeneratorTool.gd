# res://tools/MakeDrengrMelee.gd
@tool
extends EditorScript

func _run() -> void:
	print("--- Converting Units to Melee ---")
	
	var paths = [
		"res://data/units/Unit_Drengr.tres",
		"res://data/units/Unit_Bondi.tres"
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			var data = load(path) as UnitData
			
			# 1. Remove Projectile (Enables Melee Mode)
			data.projectile_scene = null
			
			# 2. Ensure Attack Range is Short
			data.attack_range = 15.0
			
			# 3. Save
			ResourceSaver.save(data, path)
			print("✅ Converted %s to Melee Mode." % path.get_file())
		else:
			print("Skipping %s (Not found)" % path)
			
	print("--- Done. Re-run game. ---")
