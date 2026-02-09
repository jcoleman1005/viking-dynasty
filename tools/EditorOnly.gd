#res://tools/EditorOnly.gd
# res://tools/UpdateRegionNames.gd
@tool
extends EditorScript

const SCENE_PATH = "res://scenes/world_map/MacroMap.tscn"

# The Historical Mapping provided by your consultant
const NAME_MAP = {
	"Region_Southern_Sweden": "Geatland",
	"Region_Southern_Norway": "Viken",
	"Region_Northern_Sweden": "Swealand",
	"Region_Northern_Norway": "Halogaland",
	"Region_Denmark": "Denmark",
	"Region_Finland": "Kvenland",
	"Region_Estonia": "Estland",
	"Region_Northern_Baltics": "Courland",
	"Region_Southern_Baltics": "Samland",
	"Region_10": "Bjarmaland",
	"Region_Germany_East": "Wendland",
	"Region_Germany_West": "Saxony",
	"Region_Francia": "Frankland",
	"Region_Brittain": "Britland"
}

func _run():
	print("--- 📜 Updating Historical Region Names ---")
	
	# 1. Load the Scene
	var scene = load(SCENE_PATH).instantiate()
	var regions_root = scene.get_node_or_null("Regions")
	
	if not regions_root:
		printerr("Error: Could not find 'Regions' node in MacroMap.tscn")
		scene.free()
		return
		
	var count = 0
	
	# 2. Iterate through our map
	for node_name in NAME_MAP:
		var region_node = regions_root.get_node_or_null(node_name)
		
		if region_node:
			var new_name = NAME_MAP[node_name]
			
			# Ensure Data Exists
			if not region_node.data:
				region_node.data = WorldRegionData.new()
				print(" > Created missing data for %s" % node_name)
			
			# CRITICAL: Make Unique
			# Many regions currently share "Resource_seg4e". 
			# We must duplicate it so changing one doesn't change them all.
			region_node.data = region_node.data.duplicate()
			
			# Update Name
			region_node.data.display_name = new_name
			print(" > Renamed [%s] -> %s" % [node_name, new_name])
			count += 1
		else:
			printerr(" ⚠️ Node not found: ", node_name)
			
	# 3. Save Changes
	if count > 0:
		var packed = PackedScene.new()
		packed.pack(scene)
		var err = ResourceSaver.save(packed, SCENE_PATH)
		
		if err == OK:
			print("✅ Success! %d regions updated." % count)
			print("   Scene saved to: ", SCENE_PATH)
			EditorInterface.get_resource_filesystem().scan()
		else:
			printerr("❌ Failed to save scene. Error: ", err)
	
	scene.free()
