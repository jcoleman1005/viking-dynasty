@tool
extends EditorScript

# =============================================================================
# GODOT AI CONTEXT GENERATOR (V3 - API MAP OPTIMIZED)
# =============================================================================
# Improvements:
# 1. Parsing: Now captures 'static', '@onready', and modifier keywords correctly.
# 2. Format: Outputs Markdown (.md) for superior Gemini navigation.
# 3. Size: Aggressively trims whitespace to save context tokens.
# =============================================================================

const OUTPUT_DIR = "res://_context_dumps"
const OUTPUT_FILENAME = "gemini_api_map.md" # Changed to .md

const IGNORE_DIRS = [
	"res://addons", "res://.godot", "res://.git", 
	"res://assets", "res://exports", "res://_context_dumps"
]

const INCLUDE_EXTENSIONS = ["gd", "tscn", "tres"]

# Max file size to parse (1MB)
const MAX_FILE_SIZE_BYTES = 1024 * 1024 

# FLUFF FILTER: Skip these resource types
const SKIP_RESOURCE_TYPES = [
	"TileSet", "NavigationPolygon", "Mesh", "ArrayMesh", 
	"CompressedTexture2D", "Image", "AudioStreamWAV", "AudioStreamMP3",
	"FontFile", "StyleBoxFlat", "StyleBoxTexture", "Theme", "GradientTexture2D"
]

var _preload_map = {} 

func _run() -> void:
	print("--- 🗺️ Starting Gemini API Map Generation (V3) ---")
	var time_start = Time.get_ticks_msec()
	
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	
	var out_path = OUTPUT_DIR + "/" + OUTPUT_FILENAME
	var file = FileAccess.open(out_path, FileAccess.WRITE)
	if not file:
		printerr("❌ Error: Could not open output file.")
		return

	# 1. Header
	file.store_line("# PROJECT API MAP")
	file.store_line("> **CONTEXT INSTRUCTION:** This file contains the STRUCTURE of the project. Implementation details are hidden to save space. Use this to understand available classes, functions, and signals.")
	file.store_line("> Generated: %s\n" % Time.get_datetime_string_from_system())

	# 2. Gather & Sort Files
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

	# 3. Build Content (Markdown Format)
	var buffer: Array[String] = []
	
	# -- Architecture Overview --
	buffer.append("## 🏛️ GLOBAL ARCHITECTURE")
	_write_architecture(buffer)
	
	# -- Scenes --
	buffer.append("\n## 🎬 SCENE STRUCTURES")
	for p in tscn_files:
		buffer.append(_parse_scene(p))

	# -- Scripts (The API) --
	buffer.append("\n## 📜 SCRIPT API (Logic Structures)")
	for p in gd_files:
		buffer.append(_parse_script(p))
		
	# -- Data --
	buffer.append("\n## 💾 GAME DATA (Resources)")
	for p in tres_files:
		var res_text = _parse_resource(p)
		if res_text != "": buffer.append(res_text)

	# -- Dependencies --
	if not _preload_map.is_empty():
		buffer.append("\n## 🔗 DEPENDENCY GRAPH")
		_write_dependencies(buffer)

	# 4. Save
	file.store_string("\n".join(buffer))
	file.close()
	
	var elapsed = (Time.get_ticks_msec() - time_start) / 1000.0
	print("✅ API Map Generated: %s" % out_path)
	print("⏱️ Time: %.2fs | Files: %d" % [elapsed, all_files.size()])
	
	OS.shell_open(ProjectSettings.globalize_path(OUTPUT_DIR))

# =============================================================================
# PARSERS
# =============================================================================

func _write_architecture(out: Array):
	out.append("### Autoloads (Singletons)")
	var found = false
	for prop in ProjectSettings.get_property_list():
		if prop.name.begins_with("autoload/"):
			var name = prop.name.trim_prefix("autoload/")
			var path = ProjectSettings.get_setting(prop.name).replace("*", "")
			out.append("- **%s**: `%s`" % [name, path])
			found = true
	if not found: out.append("(None)")
	
	out.append("\n### Physics Layers")
	for i in range(1, 33):
		var layer = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % i)
		if layer: out.append("- Layer %d: %s" % [i, layer])

func _parse_script(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return ""
	if f.get_length() > MAX_FILE_SIZE_BYTES: return "### %s\n(Skipped - Too Large)" % path

	var lines: Array[String] = []
	var local_preloads = []
	
	while not f.eof_reached():
		var line = f.get_line()
		var s = line.strip_edges()
		
		# Capture Preloads
		if "preload(" in line or "load(" in line:
			var dep = _extract_preload(line)
			if dep: local_preloads.append(dep)

		# SENIOR FIX: Robust Keyword Detection
		# We check if the line STARTS with these, OR if it's an onready/static var
		var is_structure = false
		
		if s.begins_with("extends") or s.begins_with("class_name"):
			is_structure = true
		elif s.begins_with("signal") or s.begins_with("enum"):
			is_structure = true
		elif s.begins_with("const"):
			is_structure = true
		
		# Variable Logic (Catch @onready and @export)
		elif s.begins_with("var") or s.begins_with("@"):
			# Only keep if it defines data, skip random annotations if they aren't variables
			if "var " in s or "@export" in s or "signal " in s:
				is_structure = true
		
		# Function Logic (Catch static func)
		elif "func " in s: 
			# We filter out indented lambdas if necessary, but usually top-level funcs are fine
			# This captures "static func", "func _ready():", etc.
			if not s.begins_with("#"): # Ignore commented out functions
				is_structure = true

		if is_structure:
			lines.append(line)

	f.close()
	
	if not local_preloads.is_empty():
		_preload_map[path] = local_preloads

	# Markdown Code Block
	return "\n### `%s`\n```gdscript\n%s\n```" % [path, "\n".join(lines)]

func _parse_scene(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return ""
	
	var nodes = {} 
	var connections = []
	var ext_res = {} 
	
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
			# Parse connection for readability: "signal='timeout' from='Timer' to='.'"
			var sig = _get_attr(line, "signal")
			var from = _get_attr(line, "from")
			var to = _get_attr(line, "to")
			var method = _get_attr(line, "method")
			connections.append("- `%s` -> `%s` :: %s()" % [from, to, method])

	f.close()
	
	# Build Tree
	var roots = []
	for p in nodes:
		var n = nodes[p]
		if n.parent == ".": roots.append(p)
		elif nodes.has(n.parent): nodes[n.parent].children.append(p)
	
	var out: Array[String] = []
	for r in roots: _print_tree(nodes, r, 0, out)
	
	var tree_str = "\n".join(out)
	var signal_str = ""
	if not connections.is_empty():
		signal_str = "\n**Signals:**\n" + "\n".join(connections)
		
	return "\n### `%s`\n%s%s" % [path, tree_str, signal_str]

func _print_tree(nodes: Dictionary, key: String, depth: int, out: Array):
	var n = nodes[key]
	var indent = "  ".repeat(depth)
	var s_info = " (`%s`)" % n.script if n.script else ""
	out.append("%s- **%s** [%s]%s" % [indent, n.name, n.type, s_info])
	for child in n.children: _print_tree(nodes, child, depth + 1, out)

func _parse_resource(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return ""
	
	# Check for filter
	var type_line = ""
	var content = []
	var is_filtered = false
	
	while not f.eof_reached():
		var line = f.get_line()
		content.append(line)
		if line.begins_with("[gd_resource"):
			var type = _get_attr(line, "type")
			if type in SKIP_RESOURCE_TYPES:
				is_filtered = true
				break
	f.close()
	
	if is_filtered: return ""
	
	# Compress output
	var clean_lines: Array[String] = []
	clean_lines.append(content[0]) # Header
	
	for i in range(1, content.size()):
		var s = content[i].strip_edges()
		if s == "": continue
		if s.begins_with("metadata/"): continue
		
		# Truncate arrays
		if s.length() > 150: 
			clean_lines.append(s.substr(0, 150) + "...")
		else:
			clean_lines.append(s)
			
	return "\n### `%s`\n```text\n%s\n```" % [path, "\n".join(clean_lines)]

func _write_dependencies(out: Array):
	for k in _preload_map:
		out.append("- `%s`" % k)
		for d in _preload_map[k]: 
			out.append("  - depends on: `%s`" % d)

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
