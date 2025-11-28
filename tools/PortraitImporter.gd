# res://tools/PortraitImporter.gd
@tool
extends EditorScript

# --- CONFIGURATION ---
# 1. Put your AI generated PNGs here
const SOURCE_DIR = "res://art/portraits/"
# 2. The script will save .tres files here
const TARGET_DIR = "res://data/portraits/parts/"

func _run() -> void:
	print("--- 🎨 STARTING PORTRAIT BATCH IMPORT ---")
	
	# 1. Ensure Directories
	_ensure_dir(SOURCE_DIR)
	_ensure_dir(TARGET_DIR)
	
	var dir = DirAccess.open(SOURCE_DIR)
	if not dir:
		printerr("Error accessing source directory: ", SOURCE_DIR)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg")):
			_process_image(file_name)
			count += 1
		file_name = dir.get_next()
		
	print("--- Import Complete. Processed %d images. ---" % count)
	# Refresh editor to show new files
	EditorInterface.get_resource_filesystem().scan()

func _process_image(file_name: String) -> void:
	var id = file_name.get_basename()
	var target_path = TARGET_DIR + id + ".tres"
	
	# Skip if already exists (prevent overwriting manual edits)
	if ResourceLoader.exists(target_path):
		print("Skipping existing: ", id)
		return
		
	# 1. Load Texture
	var tex_path = SOURCE_DIR + file_name
	var texture = load(tex_path)
	if not texture:
		printerr("Failed to load texture: ", tex_path)
		return
		
	# 2. Create Resource
	var data = PortraitPartData.new()
	data.texture = texture
	
	# 3. Parse Filename for Metadata
	# Format expected: type_desc_id.png (e.g., "head_male_01.png")
	var parts = id.split("_")
	var type_str = parts[0].to_lower()
	
	match type_str:
		"head":
			data.part_type = "HEAD"
			data.color_category = "skin"
		"body":
			data.part_type = "BODY"
			data.color_category = "clothing"
		"hair":
			data.part_type = "HAIR_FRONT" # Default to front, can change manually
			data.color_category = "hair"
		"beard":
			data.part_type = "BEARD"
			data.color_category = "hair"
		"acc":
			data.part_type = "ACCESSORY"
			data.color_category = "none"
		_:
			data.part_type = "ACCESSORY"
			data.color_category = "none"
			printerr("Unknown type prefix '%s' in %s. Defaulting to ACCESSORY." % [type_str, file_name])

	# 4. Save
	var error = ResourceSaver.save(data, target_path)
	if error == OK:
		print("✅ Imported: %s as %s" % [id, data.part_type])
	else:
		printerr("❌ Failed to save resource: ", target_path)

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
		print("Created directory: ", path)
