# res://addons/GodotAiSuite/agent/task_card.gd
@tool
extends PanelContainer
class_name TaskCard

signal execute_task_requested(task_data: Dictionary, card: TaskCard)

# --- Constants ---
const DIFF_VIEW_SCENE: PackedScene = preload("res://addons/GodotAiSuite/agent/diff_view.tscn")

# --- UI References ---
@onready var _icon: TextureRect = $MarginContainer/VBox/Header/Icon
@onready var _title: Label = $MarginContainer/VBox/Header/Title
@onready var _buttons_container: HBoxContainer = $MarginContainer/VBox/Header/Buttons
@onready var _explanation: Label = $MarginContainer/VBox/Explanation
@onready var _content_container: VBoxContainer = $MarginContainer/VBox/ContentContainer
@onready var _feedback_panel: PanelContainer = $MarginContainer/VBox/FeedbackPanel
@onready var _feedback_label: RichTextLabel = $MarginContainer/VBox/FeedbackPanel/FeedbackMargin/FeedbackLabel

# --- State ---
var _task_data: Dictionary

func _ready() -> void:
	if not is_node_ready():
		await ready
	var editor_theme := EditorInterface.get_editor_theme()
	var panel_stylebox: StyleBox = editor_theme.get_stylebox("panel", "Tree")
	add_theme_stylebox_override("panel", panel_stylebox)
	
	var feedback_stylebox: StyleBox = editor_theme.get_stylebox("normal", "LineEdit")
	_feedback_panel.add_theme_stylebox_override("panel", feedback_stylebox)


func populate(p_step_data: Dictionary, p_editor_theme: Theme) -> void:
	if not is_node_ready(): await ready
	
	_task_data = p_step_data.get("task", {})
	var task_type: String = _task_data.get("type", "unknown")
	var is_manual: bool = task_type == "manual_step"
	
	_explanation.text = p_step_data.get("explanation", "No explanation provided.")
	_icon.texture = _get_icon_for_task_type(task_type, p_editor_theme)

	var action_button: Button

	if is_manual:
		var details: String = _task_data.get("details", "No details provided.")
		_title.text = details
		action_button = Button.new()
		action_button.text = "Mark as Done"
		action_button.pressed.connect(func(): action_button.disabled = true; action_button.text = "Done"; modulate = Color(0.8, 1.0, 0.8))
		_buttons_container.add_child(action_button)
		return

	var path: String = _task_data.get("path", "")
	match task_type:
		"create_script", "create_scene", "create_resource", "create_directory":
			_title.text = "[%s] %s" % [task_type.to_upper().replace("_", " "), path]
			action_button = Button.new()
			action_button.text = "Create"
		"build_scene":
			_title.text = "[BUILD SCENE] %s" % path
			action_button = Button.new()
			action_button.text = "Build"
		"modify_text_file", "modify_script", "modify_scene", "modify_resource":
			_title.text = "[%s] %s" % [task_type.to_upper().replace("_", " "), path]
			var view_button := Button.new()
			view_button.text = "View Diff"
			_buttons_container.add_child(view_button)
			action_button = Button.new()
			action_button.text = "Accept"
			_create_diff_panel(path, _task_data.get("content"), view_button)
		"move_file":
			var old_path: String = _task_data.get("old_path", "?")
			var new_path: String = _task_data.get("new_path", "?")
			_title.text = "[MOVE] %s -> %s" % [old_path, new_path]
			action_button = Button.new()
			action_button.text = "Move"
		"delete_file":
			_title.text = "[DELETE] %s" % path
			action_button = Button.new()
			action_button.text = "Delete"
			action_button.add_theme_color_override("font_color", Color.RED)
		"modify_project_settings":
			var section: String = _task_data.get("section", "?")
			var key: String = _task_data.get("key", "?")
			var value = _task_data.get("value", "?")
			_title.text = "[SETTING] Set '%s/%s' to %s" % [section, key, str(value)]
			action_button = Button.new()
			action_button.text = "Apply"
		"add_autoload":
			var name: String = _task_data.get("name", "?")
			_title.text = "[AUTOLOAD] Add '%s' from %s" % [name, _task_data.get("path", "?")]
			action_button = Button.new()
			action_button.text = "Add"
		"remove_autoload":
			var name_to_remove: String = _task_data.get("name", "?")
			_title.text = "[AUTOLOAD] Remove '%s'" % name_to_remove
			action_button = Button.new()
			action_button.text = "Remove"
			action_button.add_theme_color_override("font_color", Color.RED)
		_:
			_title.text = "[color=orange]Unknown task type: %s[/color]" % task_type

	if is_instance_valid(action_button):
		_buttons_container.add_child(action_button)
		action_button.pressed.connect(func(): emit_signal("execute_task_requested", _task_data, self))


func show_feedback(message: String, success: bool) -> void:
	_feedback_panel.visible = true
	_feedback_label.text = message
	modulate = Color(0.8, 1.0, 0.8) if success else Color(1.0, 0.8, 0.8)
	var button: Button = _buttons_container.get_child(_buttons_container.get_child_count() - 1)
	if is_instance_valid(button):
		button.disabled = true
		button.text = "Applied"


func get_primary_button() -> Button:
	if _buttons_container.get_child_count() > 0:
		return _buttons_container.get_child(_buttons_container.get_child_count() - 1)
	return null


func _create_diff_panel(path: String, content: Variant, view_button: Button) -> void:
	_content_container.add_child(HSeparator.new())
	var diff_panel: PanelContainer = DIFF_VIEW_SCENE.instantiate()
	var old_content: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var new_content: String = content if content is String else JSON.stringify(content, "  ")
	diff_panel.show_diff(old_content, new_content)
	_content_container.add_child(diff_panel)
	diff_panel.visible = false
	view_button.pressed.connect(func():
		diff_panel.visible = not diff_panel.visible
		view_button.text = "View Diff" if not diff_panel.visible else "Hide Diff"
	)


func _get_icon_for_task_type(task_type: String, theme: Theme) -> Texture2D:
	if not theme: return null
	match task_type:
		"modify_script":
			return theme.get_icon("Script", "EditorIcons")		
		"create_script":
			return theme.get_icon("ScriptCreate", "EditorIcons")
		"modify_scene":
			return theme.get_icon("PackedScene", "EditorIcons")
		"create_scene", "build_scene":
			return theme.get_icon("CreateNewSceneFrom", "EditorIcons")
		"create_resource":
			return theme.get_icon("New", "EditorIcons")
		"modify_resource", "modify_text_file":
			return theme.get_icon("File", "EditorIcons")
		"create_directory":
			return theme.get_icon("FolderCreate", "EditorIcons")
		"move_file":
			return theme.get_icon("DirAccess", "EditorIcons")
		"delete_file", "remove_autoload":
			return theme.get_icon("Remove", "EditorIcons")
		"manual_step":
			return theme.get_icon("ToolPan", "EditorIcons")
		"modify_project_settings":
			return theme.get_icon("Modifiers", "EditorIcons")
		"add_autoload":
			return theme.get_icon("Environment", "EditorIcons")
		_:
			return theme.get_icon("Unknown", "EditorIcons")
