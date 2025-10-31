# res://addons/GodotAiSuite/agent/agent_window.gd
@tool
extends Window

# --- Constants ---
const TASK_CARD_SCENE: PackedScene = preload("res://addons/GodotAiSuite/agent/task_card.tscn")
const SETTINGS_FILE_PATH: String = "res://addons/GodotAiSuite/settings.cfg"

# --- UI Node References ---
@onready var _execution_plan_label: Label = $MarginContainer/MainVBox/ExecutionPlanLabel
@onready var _accept_all_hbox: HBoxContainer = $MarginContainer/MainVBox/ExecutionPlanScroll/ScrollContentContainer/AcceptAllHBox
@onready var _accept_all_button: Button = $MarginContainer/MainVBox/ExecutionPlanScroll/ScrollContentContainer/AcceptAllHBox/AcceptAllButton
@onready var _execution_plan_scroll: ScrollContainer = $MarginContainer/MainVBox/ExecutionPlanScroll
@onready var _execution_plan_container: VBoxContainer = $MarginContainer/MainVBox/ExecutionPlanScroll/ScrollContentContainer/ExecutionPlanContainer

# --- Git Commit UI ---
@onready var _commit_separator: HSeparator = $MarginContainer/MainVBox/CommitSeparator
@onready var _commit_hbox: HBoxContainer = $MarginContainer/MainVBox/CommitHBox
@onready var _commit_line_edit: LineEdit = $MarginContainer/MainVBox/CommitHBox/CommitLineEdit
@onready var _commit_copy_button: Button = $MarginContainer/MainVBox/CommitHBox/CommitCopyButton

# --- Internal State ---
var _main_plugin_instance: EditorPlugin
var _automated_tasks: Array[TaskCard] = []
var _pasted_json_text: String = ""

func _ready() -> void:
	if not is_node_ready():
		await ready
	
	_accept_all_button.pressed.connect(_on_accept_all_pressed)
	close_requested.connect(hide)
	_commit_copy_button.pressed.connect(_on_copy_commit_button_pressed)

# --- Public Methods ---
func set_main_plugin(plugin: EditorPlugin) -> void:
	_main_plugin_instance = plugin

func show_window() -> void:
	if not is_node_ready():
		await ready
	_clear_preview()
	_pasted_json_text = ""
	popup()

func paste_and_parse_from_clipboard() -> void:
	if not is_node_ready():
		await ready
	_pasted_json_text = DisplayServer.clipboard_get()
	if _pasted_json_text.is_empty():
		_show_error_dialog_and_close("Clipboard Empty", "The clipboard is empty. Please copy the instructions first.")
		return
	
	if not _parse_json_and_preview():
		_show_error_dialog_and_close("Parsing Failed", "Could not parse a valid execution plan from the clipboard content.")


# --- Signal Handlers ---

func _parse_json_and_preview() -> bool:
	_clear_preview()
	
	var raw_text: String = _pasted_json_text
	var start_index: int = raw_text.find("{")
	var end_index: int = raw_text.rfind("}")
	
	if start_index == -1 or end_index == -1 or end_index < start_index: return false
	
	var json_text: String = raw_text.substr(start_index, end_index - start_index + 1)
	if json_text.is_empty(): return false
	
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK: return false
	
	var data: Variant = json.data
	if not data is Dictionary: return false
		
	if not data.has("execution_plan") or not data.execution_plan is Array:
		return false
		
	var steps: Array = data.execution_plan
	
	if data.has("git_commit_message") and data.git_commit_message is String and not data.git_commit_message.is_empty():
		var commit_message: String = data.git_commit_message
		_commit_line_edit.text = commit_message
		_commit_separator.visible = true
		_commit_hbox.visible = true

		var devlog_path := "res://addons/GodotAiSuite/DevLog.txt"
		var devlog_content := ""
		if FileAccess.file_exists(devlog_path):
			devlog_content = FileAccess.get_file_as_string(devlog_path)
		
		if not devlog_content.is_empty() and not devlog_content.ends_with("\n"):
			devlog_content += "\n"
			
		var new_devlog_content: String = devlog_content + commit_message + "\n"

		var devlog_step: Dictionary = {
			"explanation": "Appends the generated git commit message to the project's DevLog.txt for tracking.",
			"task": {
				"type": "modify_text_file",
				"path": devlog_path,
				"content": new_devlog_content
			}
		}
		steps.append(devlog_step)

	if steps.is_empty():
		return false
		
	var has_automated_tasks: bool = false
	for step in steps:
		if step.task.get("type") != "manual_step":
			has_automated_tasks = true
			break

	_execution_plan_label.visible = true
	_execution_plan_scroll.visible = true
	if has_automated_tasks:
		_accept_all_hbox.visible = true
		
	for step_data in steps:
		if step_data is Dictionary and step_data.has("task"):
			_create_and_add_task_card(step_data)
	
	return true


func _on_copy_commit_button_pressed() -> void:
	DisplayServer.clipboard_set(_commit_line_edit.text)
	_commit_copy_button.text = "Copied!"
	var tween: Tween = create_tween()
	tween.tween_callback(func(): _commit_copy_button.text = "Copy").set_delay(1.5)


func _on_accept_all_pressed() -> void:
	_accept_all_button.disabled = true
	_accept_all_button.text = "Applying..."

	for card in _automated_tasks:
		var button: Button = card.get_primary_button()
		if is_instance_valid(button) and not button.disabled:
			# Directly call the task execution logic instead of waiting for a button press signal.
			# Pass the task data and the card instance itself, skipping confirmations.
			await _on_task_execution_requested(card._task_data, card, true)
			await get_tree().create_timer(0.1).timeout # A small delay for UI updates

	_accept_all_button.text = "All Applied"


func _on_task_execution_requested(task_data: Dictionary, card: TaskCard, p_skip_confirmation: bool = false) -> void:
	var task_type: String = task_data.get("type")
	
	var success: bool = true
	var message: String = ""
	var fs: EditorFileSystem = _main_plugin_instance.get_editor_interface().get_resource_filesystem()
	
	match task_type:
		"create_script", "create_resource", "create_scene", "modify_text_file", "modify_script", "modify_resource", "modify_scene":
			var path: String = task_data.get("path")
			var content = task_data.get("content")
			var new_content_str: String = content if content is String else JSON.stringify(content, "  ")
			message = await _save_file(path, new_content_str)
		"create_directory":
			var path: String = task_data.get("path")
			var global_path: String = ProjectSettings.globalize_path(path)
			var err: Error = DirAccess.make_dir_recursive_absolute(global_path)
			if err == OK: message = "Successfully created directory: %s" % path
			else: message = "[color=red]Error creating directory %s: %s[/color]" % [path, error_string(err)]
		"delete_file":
			var path: String = task_data.get("path")
			var accepted: bool = true
			if not p_skip_confirmation:
				accepted = await _show_confirmation("Delete Item?", "Are you sure you want to permanently delete:\n%s" % path)

			if accepted:
				fs.scan()
				await fs.filesystem_changed

				var global_path: String = ProjectSettings.globalize_path(path)
				# Use the correct `FileAccess.file_exists`, which works with absolute paths.
				if not DirAccess.dir_exists_absolute(global_path) and not FileAccess.file_exists(global_path):
					message = "[color=orange]Item to delete not found: %s[/color]" % path
				else:
					var err: Error = DirAccess.remove_absolute(global_path)
					if err == OK:
						message = "Successfully deleted: %s" % path
					else:
						message = "[color=red]Error deleting item %s: %s[/color]" % [path, error_string(err)]
			else: return
		"move_file":
			var old_path: String = task_data.get("old_path")
			var new_path: String = task_data.get("new_path")
			var accepted: bool = true
			if not p_skip_confirmation:
				accepted = await _show_confirmation("Move/Rename Item?", "Are you sure you want to move/rename:\n%s\n\nTo:\n%s" % [old_path, new_path])

			if accepted:
				var global_old_path: String = ProjectSettings.globalize_path(old_path)
				var global_new_path: String = ProjectSettings.globalize_path(new_path)
				var err: Error = DirAccess.rename_absolute(global_old_path, global_new_path)
				if err == OK: message = "Successfully moved item."
				else: message = "[color=red]Error moving item: %s[/color]" % error_string(err)
			else: return
		"modify_project_settings":
			var config := ConfigFile.new()
			var err := config.load("res://project.godot")
			if err != OK: message = "[color=red]Error loading project.godot: %s[/color]" % error_string(err)
			else:
				config.set_value(task_data.get("section"), task_data.get("key"), task_data.get("value"))
				err = config.save("res://project.godot")
				if err == OK: message = "Successfully modified project settings. A manual editor restart is recommended to apply changes."
				else: message = "[color=red]Error saving project.godot: %s[/color]" % error_string(err)
		"add_autoload":
			message = await _modify_autoload(task_data.get("name"), task_data.get("path"), true)
		"remove_autoload":
			message = await _modify_autoload(task_data.get("name"), null, false)
		_:
			success = false
			message = "[color=red]Execution logic for task type '%s' not implemented.[/color]" % task_type
			
	if message.begins_with("[color=red]"): success = false
	
	if success:
		fs.scan()
		await get_tree().create_timer(0.2).timeout
	
	card.show_feedback(message, success)

# --- Internal Logic ---
func _clear_preview() -> void:
	_automated_tasks.clear()
	for child in _execution_plan_container.get_children(): child.queue_free()
	
	_execution_plan_label.visible = false
	_execution_plan_scroll.visible = false
	_accept_all_hbox.visible = false
	
	_commit_separator.visible = false
	_commit_hbox.visible = false
	_commit_line_edit.text = ""
	_accept_all_button.disabled = false
	_accept_all_button.text = "Accept All Automated Tasks"

func _create_and_add_task_card(step_data: Dictionary) -> void:
	var card: TaskCard = TASK_CARD_SCENE.instantiate()
	var task_type: String = step_data.get("task", {}).get("type", "unknown")
	
	card.populate(step_data, _main_plugin_instance.get_editor_interface().get_editor_theme())

	if task_type != "manual_step":
		card.execute_task_requested.connect(_on_task_execution_requested)
		_automated_tasks.append(card)

	_execution_plan_container.add_child(card)

func _save_file(p_path: String, p_content: Variant) -> String:
	var file_content_str: String = p_content if p_content is String else JSON.stringify(p_content, "  ")
	var file: FileAccess = FileAccess.open(p_path, FileAccess.WRITE)
	if not file:
		return "[color=red]Error: Could not open file to write: %s[/color]" % p_path
	file.store_string(file_content_str)
	return "Successfully saved file: %s" % p_path


func _modify_autoload(singleton_name: String, path, add_or_enable: bool) -> String:
	var path_str: String = path if path is String else ""
	if singleton_name.is_empty() or (add_or_enable and path_str.is_empty()):
		return "[color=red]Invalid autoload data provided.[/color]"

	var config := ConfigFile.new()
	var err := config.load("res://project.godot")
	if err != OK: return "[color=red]Error loading project.godot: %s[/color]" % error_string(err)

	var key: String = singleton_name
	if add_or_enable:
		var value: String = "*" + path_str
		config.set_value("autoload", key, value)
	else: # Remove
		if not config.has_section_key("autoload", key):
			return "[color=orange]Autoload '%s' not found, nothing to remove.[/color]" % singleton_name
		config.erase_section_key("autoload", key)

	err = config.save("res://project.godot")
	if err == OK:
		return "Successfully updated autoloads. A manual editor restart is recommended to apply changes."
	else:
		return "[color=red]Error saving project.godot: %s[/color]" % error_string(err)

	
func _show_confirmation(title: String, text: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	add_child(dialog)

	var result: bool = await dialog.confirmed
	dialog.queue_free()
	return result

func _show_error_dialog_and_close(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free(); hide())
