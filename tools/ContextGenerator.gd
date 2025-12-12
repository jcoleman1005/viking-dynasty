@tool
extends EditorScript

# Configuration
const OUTPUT_DIR = "res://_context_dumps"
const OUTPUT_FILENAME = "project_context.txt"
const OUTPUT_PATH = OUTPUT_DIR + "/" + OUTPUT_FILENAME

const IGNORE_DIRS = ["res://addons", "res://.godot"]
const INCLUDE_EXTENSIONS = ["gd"] 

func _run() -> void:
	print("--- Starting Context Generation ---")
	
	# 1. Create the directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		var err = DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		if err != OK:
			printerr("ERROR: Could not create folder " + OUTPUT_DIR)
			return
	
	var context_content = "PROJECT CONTEXT SKELETON\n"
	context_content += "Generated: " + Time.get_datetime_string_from_system() + "\n"
	context_content += "========================================\n\n"
	
	var files = _get_all_files("res://")
	
	for file_path in files:
		context_content += _parse_script(file_path)
		context_content += "\n\n"
	
	var file = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(context_content)
		file.close()
		print("SUCCESS: Context saved to " + OUTPUT_PATH)
		print("Total files scanned: " + str(files.size()))
		
		# 2. Open the specific folder in your OS File Explorer
		var global_path = ProjectSettings.globalize_path(OUTPUT_DIR)
		OS.shell_open(global_path)
		
		# Refresh Godot's filesystem so the new folder/file shows up in the editor
		EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("ERROR: Could not write to " + OUTPUT_PATH)

func _get_all_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = path + "/" + file_name
			if path == "res://":
				full_path = "res://" + file_name
			
			if dir.current_is_dir():
				if not (file_name == "." or file_name == ".."):
					var skip = false
					for ignore in IGNORE_DIRS:
						if full_path.begins_with(ignore):
							skip = true
							break
					if not skip:
						files.append_array(_get_all_files(full_path))
			else:
				if file_name.get_extension() in INCLUDE_EXTENSIONS:
					files.append(full_path)
			
			file_name = dir.get_next()
	
	return files

func _parse_script(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
		
	var output = "### FILE: " + path + " ###\n"
	
	while not file.eof_reached():
		var line = file.get_line()
		var stripped = line.strip_edges()
		
		if stripped.begins_with("#") or stripped == "":
			continue
			
		if stripped.begins_with("class_name") or \
		   stripped.begins_with("extends") or \
		   stripped.begins_with("signal") or \
		   stripped.begins_with("enum") or \
		   stripped.begins_with("const") or \
		   stripped.begins_with("var") or \
		   stripped.begins_with("@export"):
			output += line + "\n"
			
		elif stripped.begins_with("func"):
			output += line + "\n"
			output += "\tpass # (Body Omitted)\n"
			
	return output
