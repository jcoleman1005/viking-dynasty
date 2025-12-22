@tool
extends EditorScript

# =============================================================================
# GODOT AI CONTEXT GENERATOR (V6.1 FIX)
# =============================================================================
# Fixes: Replaced PackedStringArray with Array[String] to fix .join() errors.
# =============================================================================

# --- CONFIGURATION ---
const OUTPUT_DIR = "res://_context_dumps"
const OUTPUT_FILENAME = "project_context.txt"

# Skip these folders completely
const IGNORE_DIRS = ["res://addons", "res://.godot", "res://.git", "res://assets", "res://exports"]

# Files to parse
const INCLUDE_EXTENSIONS = ["gd", "tscn", "tres"]

# Safety: Skip individual files larger than this (e.g. 1MB)
const MAX_FILE_SIZE_BYTES = 1024 * 1024 

# FLUFF FILTER: Skip these resource types to prevent massive bloat
const SKIP_RESOURCE_TYPES = [
	"TileSet", "NavigationPolygon", "Mesh", "ArrayMesh", 
	"CompressedTexture2D", "Image", "AudioStreamWAV", "AudioStreamMP3",
	"FontFile", "StyleBoxFlat", "StyleBoxTexture", "Theme"
]

var _preload_map = {} 

func _run() -> void:
	print("--- Starting AI Context Generation (V6.1) ---")
	var time_start = Time.get_ticks_msec()
	
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	
	var out_path = OUTPUT_DIR + "/" + OUTPUT_FILENAME
	var file = FileAccess.open(out_path, FileAccess.WRITE)
	if not file:
		printerr("❌ Error: Could not open output file.")
		return

	# 1. Gather Files
	var all_files = _get_all_files("res://")
	var gd_files: Array[String] = []
	var tscn_files: Array[String] = []
	var tres_files: Array[String] = []
	
	for p in all_files:
		match p.get_extension():
			"gd": gd_files.append(p)
			"tscn": tscn_files.append(p)
			"tres": tres_files.append(p)
	
	gd_files.sort()
	tscn_files.sort()
	tres_files.sort()

	# 2. Build Content (Using Array[String] for safety)
	var buffer: Array[String] = []
	
	_write_header(buffer, gd_files.size(), tscn_files.size(), tres_files.size())
	_write_architecture(buffer)
	
	buffer.append("\n" + "=".repeat(60))
	buffer.append("SCENE STRUCTURES")
	buffer.append("=".repeat(60) + "\n")
	for p in tscn_files:
		buffer.append(_parse_scene(p))
		buffer.append("")

	buffer.append("\n" + "=".repeat(60))
	buffer.append("GAME DATA (RESOURCES)")
	buffer.append("=".repeat(60) + "\n")
	for p in tres_files:
		var res_text = _parse_resource(p)
		if res_text != "": # Only append if not filtered
			buffer.append(res_text)
			buffer.append("")

	buffer.append("\n" + "=".repeat(60))
	buffer.append("SCRIPT LOGIC")
	buffer.append("=".repeat(60) + "\n")
	for p in gd_files:
		buffer.append(_parse_script(p))
		buffer.append("")
		
	if not _preload_map.is_empty():
		buffer.append("\n" + "=".repeat(60))
		buffer.append("DEPENDENCY MAP")
		buffer.append("=".repeat(60) + "\n")
		_write_dependencies(buffer)

	# 3. Save
	file.store_string("\n".join(buffer))
	file.close()
	
	var elapsed = (Time.get_ticks_msec() - time_start) / 1000.0
	print("✅ Complete! Saved to: %s" % out_path)
	print("⏱️ Time: %.2fs | Files Parsed: %d" % [elapsed, all_files.size()])
	
	OS.shell_open(ProjectSettings.globalize_path(OUTPUT_DIR))

# =============================================================================
# LOGIC PARSERS
# =============================================================================

func _write_header(out: Array, n_gd: int, n_tscn: int, n_tres: int):
	out.append("GODOT PROJECT CONTEXT")
	out.append("Generated: %s" % Time.get_datetime_string_from_system())
	out.append("Version: Godot %s" % Engine.get_version_info().string)
	out.append("Stats: %d Scripts, %d Scenes, %d Resources\n" % [n_gd, n_tscn, n_tres])

func _write_architecture(out: Array):
	out.append("=== ARCHITECTURE ===\n")
	out.append("-- Autoloads --")
	var found = false
	for prop in ProjectSettings.get_property_list():
		if prop.name.begins_with("autoload/"):
			var name = prop.name.trim_prefix("autoload/")
			var path = ProjectSettings.get_setting(prop.name).replace("*", "")
			out.append("%s: %s" % [name, path])
			found = true
	if not found: out.append("(None)")
	out.append("")
	
	out.append("-- Physics Layers --")
	for i in range(1, 33):
		var layer = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % i)
		if layer: out.append("Layer %d: %s" % [i, layer])
	out.append("")

func _parse_script(path: String) -> String:
	# Reads script and extracts dependencies, keeping comments and full code.
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return "// ERROR reading " + path
	if f.get_length() > MAX_FILE_SIZE_BYTES: return "// FILE: %s (Skipped - Too Large)" % path

	var lines = []
	var local_preloads = []
	
	while not f.eof_reached():
		var line = f.get_line()
		lines.append(line)
		if "preload(" in line or "load(" in line:
			var dep = _extract_preload(line)
			if dep: local_preloads.append(dep)
	f.close()
	
	if not local_preloads.is_empty():
		_preload_map[path] = local_preloads

	# Simple join - we WANT the full source.
	return "// FILE: " + path + "\n" + "\n".join(lines)

func _parse_scene(path: String) -> String:
	# Reconstructs scene tree from .tscn file text
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return ""
	
	var nodes = {} # path -> {name, type, script, parent, children}
	var connections = []
	var ext_res = {} # id -> path
	
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		
		if line.begins_with("[ext_resource"):
			var id = _get_attr(line, "id")
			var p = _get_attr(line, "path")
			if id and p: ext_res[id] = p
			
		elif line.begins_with("[node"):
			var name = _get_attr(line, "name")
			var type = _get_attr(line, "type")
			var parent = _get_attr(line, "parent")
			var script_id = _extract_res_id(line)
			var script_path = ""
			if script_id and ext_res.has(script_id): script_path = ext_res[script_id].get_file()
			if parent == "": parent = "."
			
			var full_path = name if parent == "." else parent + "/" + name
			nodes[full_path] = {"name": name, "type": type, "script": script_path, "parent": parent, "children": []}
			
		elif line.begins_with("[connection"):
			connections.append(line)

	f.close()
	
	# Build parent-child links
	var roots = []
	for p in nodes:
		var n = nodes[p]
		if n.parent == ".": roots.append(p)
		elif nodes.has(n.parent): nodes[n.parent].children.append(p)
	
	var out: Array[String] = []
	out.append("SCENE: " + path)
	for r in roots: _print_tree(nodes, r, 0, out)
	
	if not connections.is_empty():
		out.append("  SIGNALS:")
		for c in connections: out.append("  " + c)
		
	return "\n".join(out)

func _print_tree(nodes: Dictionary, key: String, depth: int, out: Array):
	var n = nodes[key]
	var indent = "  ".repeat(depth)
	var s_info = " (%s)" % n.script if n.script else ""
	out.append("%s- %s [%s]%s" % [indent, n.name, n.type, s_info])
	for child in n.children: _print_tree(nodes, child, depth + 1, out)

func _parse_resource(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return ""
	
	# Pass 1: Check type to see if we should filter it
	var type_line = ""
	var content = []
	var is_filtered = false
	
	while not f.eof_reached():
		var line = f.get_line()
		content.append(line)
		if line.begins_with("[gd_resource"):
			type_line = line
			var type = _get_attr(line, "type")
			if type in SKIP_RESOURCE_TYPES:
				is_filtered = true
				break
				
	f.close()
	
	if is_filtered: return "" # Skip entirely
	
	# Pass 2: Clean up output (remove huge arrays if any slipped through)
	var out: Array[String] = []
	out.append("RESOURCE: " + path)
	out.append(type_line)
	
	for line in content:
		var s = line.strip_edges()
		if s.begins_with("[") or s.begins_with("script=") or s.begins_with("resource_name="):
			out.append(line)
		elif s != "" and not s.begins_with("metadata/") and not s.begins_with("[gd_resource"):
			# Truncate extremely long lines (data arrays)
			if s.length() > 200: out.append(s.substr(0, 200) + "... (truncated)")
			else: out.append(line)
			
	return "\n".join(out)

func _write_dependencies(out: Array):
	for k in _preload_map:
		out.append(k)
		for d in _preload_map[k]: out.append("  -> " + d)
		out.append("")

# =============================================================================
# UTILS
# =============================================================================

func _get_all_files(path: String) -> Array:
	var res = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var n = dir.get_next()
		while n != "":
			if dir.current_is_dir():
				if n not in [".", ".."]:
					var full = path + "/" + n
					var skip = false
					for i in IGNORE_DIRS: if full.begins_with(i): skip = true
					if not skip: res.append_array(_get_all_files(full))
			else:
				if n.get_extension() in INCLUDE_EXTENSIONS: res.append(path + "/" + n)
			n = dir.get_next()
	return res

func _get_attr(line: String, attr: String) -> String:
	var start = line.find(attr + "=")
	if start == -1: return ""
	start += attr.length() + 1
	var quote = '"'
	if start < line.length() and line[start] == "'": quote = "'"
	var end = line.find(quote, start + 1)
	if end != -1: return line.substr(start + 1, end - start - 1)
	return ""

func _extract_res_id(line: String) -> String:
	var i = line.find("ExtResource(")
	if i == -1: return ""
	var sub = line.substr(i)
	var quote = '"'
	if "'" in sub: quote = "'"
	var start = sub.find(quote) + 1
	var end = sub.find(quote, start)
	return sub.substr(start, end - start)

func _extract_preload(line: String) -> String:
	var i = line.find("preload(")
	if i == -1: i = line.find("load(")
	if i == -1: return ""
	var sub = line.substr(i)
	var quote = '"'
	if "'" in sub: quote = "'"
	var start = sub.find(quote) + 1
	var end = sub.find(quote, start)
	if start > 0 and end > start: return sub.substr(start, end - start)
	return ""
