@tool
extends EditorScript

# =============================================================================
# NOTEBOOKLM SOURCE GENERATOR (V3 - FULL DUMP)
# =============================================================================
# OBJECTIVE: Dump the ENTIRE source code of the project.
# DIFFERS FROM GEMINI SCRIPT: This does NOT filter function bodies. 
# It includes every line of logic so NotebookLM can analyze implementation.
# =============================================================================

# OUTPUT FILE - Distinct name to avoid mix-ups
const OUTPUT_PATH = "res://_context_dumps/_NBLM_FULL_SOURCE.txt" 

# Recursive directories to scan
const SCAN_DIRS = ["res://"]

# Ignore list (Technical noise)
const IGNORE_DIRS = [
	"res://addons", "res://.godot", "res://.git", 
	"res://assets", "res://exports", "res://_context_dumps"
]

# Files to include
const INCLUDE_EXTENSIONS = ["gd", "tscn", "tres"]

func _run() -> void:
	print("--- 📚 Starting NotebookLM Full Source Dump ---")
	var time_start = Time.get_ticks_msec()
	
	var file = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if not file:
		printerr("❌ Error: Could not open output file: %s" % OUTPUT_PATH)
		return

	# 1. Explicit Header for the AI
	file.store_line("PROJECT SOURCE CODE LIBRARY")
	file.store_line("===========================")
	file.store_line("CONTAINS: Full Implementation Logic, Scene Trees, and Resource Data.")
	file.store_line("INSTRUCTION: This is the raw source code. Use this to answer specific implementation questions.")
	file.store_line("GENERATED: %s" % Time.get_datetime_string_from_system())
	file.store_line("===========================\n")

	# 2. Gather Files
	var all_files = _get_all_files("res://")
	
	# Sort to keep folders together
	all_files.sort()

	# 3. Process
	for path in all_files:
		_process_file(path, file)

	file.close()
	
	var elapsed = (Time.get_ticks_msec() - time_start) / 1000.0
	print("✅ Full Source Saved: %s" % OUTPUT_PATH)
	print("⏱️ Time: %.2fs | Files Parsed: %d" % [elapsed, all_files.size()])
	
	# Auto-open the folder so you see the file
	OS.shell_open(ProjectSettings.globalize_path("res://_context_dumps"))

# =============================================================================
# FILE PROCESSORS
# =============================================================================

func _process_file(path: String, f: FileAccess):
	var ext = path.get_extension()
	
	# Standard separator
	f.store_line("\n" + "-".repeat(50))
	f.store_line("FILE: " + path)
	f.store_line("-".repeat(50))
	
	match ext:
		"gd": _write_script_content(path, f)
		"tscn": _write_scene_smart(path, f)
		"tres": _write_resource_content(path, f)

func _write_script_content(path: String, f: FileAccess):
	# CRITICAL: We use get_file_as_string to ensure we get THE WHOLE FILE.
	# We do NOT filter for "func" or "var". We want the logic.
	var content = FileAccess.get_file_as_string(path)
	f.store_line(content)

func _write_resource_content(path: String, f: FileAccess):
	var content = FileAccess.get_file_as_string(path)
	# Skip binary blobs
	if content.length() > 50000:
		f.store_line("[Skipped - File too large]")
		return
	f.store_line(content)

func _write_scene_smart(path: String, f: FileAccess):
	# We just dump the text. NotebookLM is smart enough to read raw .tscn
	# if we give it the whole file. 
	var content = FileAccess.get_file_as_string(path)
	f.store_line(content)

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
