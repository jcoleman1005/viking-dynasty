@tool
extends AcceptDialog

# --- UI Node References ---
@onready var _main_tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var _sub_tab_container: TabContainer = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer
@onready var _total_tokens_label: Label = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/TotalTokensLabel

# General Tab
@onready var include_system_prompt_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeSystemPromptButton
@onready var include_gdd_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeGDDButton
@onready var include_devlog_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeDevlogButton
@onready var include_project_settings_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeProjectSettingsButton
@onready var include_assets_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeAssetsButton
@onready var include_resources_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeResourcesButton
@onready var include_scenes_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeScenesButton
@onready var include_code_button: CheckButton = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/General/MarginContainer/VBoxContainer/IncludeCodeButton

# Scenes Tab
@onready var _scene_exclusion_tree: Tree = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScenes/MarginContainer/VBoxContainer/SceneTree
@onready var _scene_select_all_button: Button = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScenes/MarginContainer/VBoxContainer/HBoxContainer/SelectAllButton
@onready var _scene_select_none_button: Button = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScenes/MarginContainer/VBoxContainer/HBoxContainer/SelectNoneButton
@onready var _scene_search_bar: LineEdit = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScenes/MarginContainer/VBoxContainer/HBoxContainer/SearchBar

# Scripts Tab
@onready var _script_exclusion_tree: Tree = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScripts/MarginContainer/VBoxContainer/ScriptTree
@onready var _script_select_all_button: Button = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScripts/MarginContainer/VBoxContainer/HBoxContainer/SelectAllButton
@onready var _script_select_none_button: Button = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScripts/MarginContainer/VBoxContainer/HBoxContainer/SelectNoneButton
@onready var _script_search_bar: LineEdit = $VBoxContainer/TabContainer/MasterpromptSettings/MarginContainer/VBoxContainer/SubTabContainer/SelectScripts/MarginContainer/VBoxContainer/HBoxContainer/SearchBar

# --- API UI References ---
@onready var _api_key_env_var_input: LineEdit = $VBoxContainer/TabContainer/API/MarginContainer/VBoxContainer/ApiKeyEnvVarInput
@onready var _api_url_input: LineEdit = $VBoxContainer/TabContainer/API/MarginContainer/VBoxContainer/ApiUrlInput
@onready var _model_name_input: LineEdit = $VBoxContainer/TabContainer/API/MarginContainer/VBoxContainer/ModelNameInput
@onready var _temperature_spinbox: SpinBox = $VBoxContainer/TabContainer/API/MarginContainer/VBoxContainer/HBoxContainer/TemperatureSpinBox
@onready var _max_tokens_spinbox: SpinBox = $VBoxContainer/TabContainer/API/MarginContainer/VBoxContainer/HBoxContainer/MaxTokensSpinBox

# --- Internal State ---
var _main_plugin_instance: EditorPlugin
var _system_prompt_token_count: int = 0
var _gdd_token_count: int = 0
var _devlog_token_count: int = 0
var _project_settings_token_count: int = 0
var _assets_token_count: int = 0
var _resources_token_count: int = 0

# --- Constants ---
const SETTINGS_FILE_PATH: String = "res://addons/GodotAiSuite/settings.cfg"
const GDD_FILE_PATH: String =  "res://addons/GodotAiSuite/GDD.txt"
const DEVLOG_FILE_PATH: String = "res://addons/GodotAiSuite/DevLog.txt"
const SYSTEM_PROMPT_AGENT_FILE_PATH: String = "res://addons/GodotAiSuite/system_prompt_agent.txt"

# Token Ratios
const TOKEN_RATIO_TEXT: float = 0.25   # For prose-like text (GDD, DevLog)
const TOKEN_RATIO_SCRIPT: float = 0.303 # For GDScript, C#, Shaders
const TOKEN_RATIO_SCENE: float = 0.4125 # For TSCN, TRES, and other structured data

func _ready() -> void:
	if not is_node_ready():
		await ready
	
	# Connect General Tab signals
	include_system_prompt_button.toggled.connect(_on_setting_changed)
	include_gdd_button.toggled.connect(_on_setting_changed)
	include_devlog_button.toggled.connect(_on_setting_changed)
	include_project_settings_button.toggled.connect(_on_setting_changed)
	include_assets_button.toggled.connect(_on_setting_changed)
	include_resources_button.toggled.connect(_on_setting_changed)
	include_scenes_button.toggled.connect(_on_setting_changed)
	include_code_button.toggled.connect(_on_setting_changed)
	
	# Connect Scene Tab signals
	_scene_select_all_button.pressed.connect(_on_select_all_pressed.bind(_scene_exclusion_tree))
	_scene_select_none_button.pressed.connect(_on_select_none_pressed.bind(_scene_exclusion_tree))
	_scene_exclusion_tree.item_edited.connect(_on_tree_item_edited.bind(_scene_exclusion_tree))
	_scene_search_bar.text_changed.connect(_on_file_filter_changed.bind(_scene_exclusion_tree))
	
	# Connect Script Tab signals
	_script_select_all_button.pressed.connect(_on_select_all_pressed.bind(_script_exclusion_tree))
	_script_select_none_button.pressed.connect(_on_select_none_pressed.bind(_script_exclusion_tree))
	_script_exclusion_tree.item_edited.connect(_on_tree_item_edited.bind(_script_exclusion_tree))
	_script_search_bar.text_changed.connect(_on_file_filter_changed.bind(_script_exclusion_tree))
	
	# Connect API Tab signals
	_api_key_env_var_input.text_changed.connect(_on_setting_changed)
	_api_url_input.text_changed.connect(_on_setting_changed)
	_model_name_input.text_changed.connect(_on_setting_changed)
	_temperature_spinbox.value_changed.connect(_on_setting_changed)
	_max_tokens_spinbox.value_changed.connect(_on_setting_changed)


func set_main_plugin(plugin: EditorPlugin) -> void:
	_main_plugin_instance = plugin
	if not is_node_ready():
		await ready
	
	# Populate trees and load settings once the plugin reference is set
	_populate_file_tree(_scene_exclusion_tree, ["tscn"])
	_populate_file_tree(_script_exclusion_tree, ["gd", "cs"])
	_load_settings()


# --- Signal Handlers ---
func _on_setting_changed(_value = null) -> void:
	_save_settings()
	_update_ui_and_token_counts()

func _on_tree_item_edited(p_tree: Tree) -> void:
	var edited_item: TreeItem = p_tree.get_edited()
	if not is_instance_valid(edited_item):
		return
	
	var metadata: Variant = edited_item.get_metadata(0)
	if metadata is Dictionary and metadata.get("is_folder", false):
		_set_children_checked_recursive(edited_item, edited_item.is_checked(0))
		# A folder was edited, so its own stats need recalculating.
		_update_folder_stats_recursive(edited_item)
	
	_update_parent_checked_state_recursive(edited_item)
	_update_ancestor_folder_texts(edited_item)
	
	_save_settings()
	_update_ui_and_token_counts()

func _on_select_all_pressed(p_tree: Tree) -> void:
	_set_all_tree_items_checked(p_tree, true)

func _on_select_none_pressed(p_tree: Tree) -> void:
	_set_all_tree_items_checked(p_tree, false)
	
func _set_all_tree_items_checked(p_tree: Tree, p_checked: bool) -> void:
	var root: TreeItem = p_tree.get_root()
	if not is_instance_valid(root): return
	
	var item: TreeItem = root.get_first_child()
	while is_instance_valid(item):
		item.set_checked(0, p_checked)
		_set_children_checked_recursive(item, p_checked)
		item = item.get_next()
	
	# Perform a full recursive update starting from the root to refresh all folder texts.
	_update_folder_stats_recursive(root)
	_save_settings()
	_update_ui_and_token_counts()

func _on_file_filter_changed(p_query: String, p_tree: Tree) -> void:
	var root := p_tree.get_root()
	if not is_instance_valid(root): return
	_filter_tree_items_recursive(root, p_query.to_lower())

# --- Settings Persistence --- 
func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_FILE_PATH)
	
	config.set_value("General", "include_system_prompt", include_system_prompt_button.button_pressed)
	config.set_value("General", "include_gdd", include_gdd_button.button_pressed)
	config.set_value("General", "include_devlog", include_devlog_button.button_pressed)
	config.set_value("General", "include_project_settings", include_project_settings_button.button_pressed)
	config.set_value("General", "include_assets", include_assets_button.button_pressed)
	config.set_value("General", "include_resources", include_resources_button.button_pressed)
	config.set_value("General", "include_scenes", include_scenes_button.button_pressed)
	config.set_value("General", "include_code", include_code_button.button_pressed)
	
	config.set_value("Exclusions", "excluded_scenes", _get_excluded_files_from_tree(_scene_exclusion_tree))
	config.set_value("Exclusions", "excluded_scripts", _get_excluded_files_from_tree(_script_exclusion_tree))
	
	config.set_value("API", "api_key_env_var", _api_key_env_var_input.text)
	config.set_value("API", "api_url", _api_url_input.text)
	config.set_value("API", "model_name", _model_name_input.text)
	config.set_value("API", "temperature", _temperature_spinbox.value)
	config.set_value("API", "max_tokens", _max_tokens_spinbox.value)
	
	config.save(SETTINGS_FILE_PATH)

func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_FILE_PATH) != OK:
		include_system_prompt_button.button_pressed = true
		include_gdd_button.button_pressed = true
		include_devlog_button.button_pressed = true
		include_project_settings_button.button_pressed = true
		include_assets_button.button_pressed = true
		include_resources_button.button_pressed = true
		include_scenes_button.button_pressed = true
		include_code_button.button_pressed = true
		_save_settings()
	else:
		include_system_prompt_button.button_pressed = config.get_value("General", "include_system_prompt", true)
		include_gdd_button.button_pressed = config.get_value("General", "include_gdd", true)
		include_devlog_button.button_pressed = config.get_value("General", "include_devlog", true)
		include_project_settings_button.button_pressed = config.get_value("General", "include_project_settings", true)
		include_assets_button.button_pressed = config.get_value("General", "include_assets", true)
		include_resources_button.button_pressed = config.get_value("General", "include_resources", true)
		include_scenes_button.button_pressed = config.get_value("General", "include_scenes", true)
		include_code_button.button_pressed = config.get_value("General", "include_code", true)

		var excluded_scenes: Array[String] = config.get_value("Exclusions", "excluded_scenes", []) as Array[String]
		var excluded_scripts: Array[String] = config.get_value("Exclusions", "excluded_scripts", []) as Array[String]
		_apply_exclusions_to_tree(_scene_exclusion_tree, excluded_scenes)
		_apply_exclusions_to_tree(_script_exclusion_tree, excluded_scripts)

		_api_key_env_var_input.text = config.get_value("API", "api_key_env_var", "GOOGLE_GEMINI_API_KEY")
		_api_url_input.text = config.get_value("API", "api_url", "https://generativelanguage.googleapis.com/v1beta/models/")
		_model_name_input.text = config.get_value("API", "model_name", "gemini-1.5-pro-latest")
		_temperature_spinbox.value = config.get_value("API", "temperature", 1.0)
		_max_tokens_spinbox.value = config.get_value("API", "max_tokens", 4096)

	_update_category_token_counts()
	_update_ui_and_token_counts()

func _apply_exclusions_to_tree(p_tree: Tree, p_exclusions: Array[String]) -> void:
	if not p_tree or p_exclusions.is_empty(): return
	_apply_exclusions_recursive(p_tree.get_root(), p_exclusions)
	_update_all_parent_folders_state(p_tree)

func _apply_exclusions_recursive(p_item: TreeItem, p_exclusions: Array[String]) -> void:
	if not is_instance_valid(p_item): return
	
	var metadata: Variant = p_item.get_metadata(0)
	if metadata is Dictionary and not metadata.get("is_folder", false):
		if metadata.has("path") and metadata.path in p_exclusions:
			p_item.set_checked(0, false)
	
	var child: TreeItem = p_item.get_first_child()
	while is_instance_valid(child):
		_apply_exclusions_recursive(child, p_exclusions)
		child = child.get_next()

func _update_all_parent_folders_state(p_tree: Tree) -> void:
	var root: TreeItem = p_tree.get_root()
	if not is_instance_valid(root): return
	
	var child: TreeItem = root.get_first_child()
	while is_instance_valid(child):
		_update_parent_checked_state_recursive(child)
		child = child.get_next()

# --- UI & Token Calculation --- 

func _populate_file_tree(p_tree: Tree, p_extensions: Array[String]) -> void:
	p_tree.clear()
	var root: TreeItem = p_tree.create_item()
	var folder_items: Dictionary = {}
	
	var files: Array = _main_plugin_instance._find_files_by_extension(p_extensions)
	var valid_files: Array = files.filter(func(p): return not p in _main_plugin_instance.IGNORED_FILE_PATHS)
	valid_files.sort()
	
	for file_path in valid_files:
		var dir_path: String = file_path.get_base_dir()
		var parent_item: TreeItem = _ensure_folder_path_exists(p_tree, root, dir_path, folder_items)
		
		var item: TreeItem = p_tree.create_item(parent_item)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, true)
		
		var file_content: String = FileAccess.get_file_as_string(file_path)
		var ratio: float = TOKEN_RATIO_SCENE if file_path.get_extension() == "tscn" else TOKEN_RATIO_SCRIPT
		var token_count: int = _calculate_tokens(file_content.length(), ratio)
		
		item.set_text(0, "%s (~%d tokens)" % [file_path.get_file(), token_count])
		item.set_metadata(0, { "path": file_path, "tokens": token_count, "is_folder": false })

	_update_folder_stats_recursive(root)

func _ensure_folder_path_exists(p_tree: Tree, p_root: TreeItem, p_path: String, p_folder_items: Dictionary) -> TreeItem:
	if p_folder_items.has(p_path):
		return p_folder_items[p_path]

	var parent_path: String = p_path.get_base_dir()
	var current_folder_name: String = p_path.get_file()

	if parent_path == p_path or p_path == "res:" or parent_path == ".":
		return p_root
	
	var parent_item: TreeItem = _ensure_folder_path_exists(p_tree, p_root, parent_path, p_folder_items)

	var folder_item: TreeItem = p_tree.create_item(parent_item)
	folder_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	folder_item.set_editable(0, true)
	folder_item.set_checked(0, true)
	folder_item.set_text(0, current_folder_name)
	folder_item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
	folder_item.set_metadata(0, {"is_folder": true, "path": p_path})
	
	p_folder_items[p_path] = folder_item
	return folder_item

func _calculate_tokens(p_content_length: int, p_ratio: float) -> int:
	return ceili(float(p_content_length) * p_ratio)

func _update_category_token_counts() -> void:
	if FileAccess.file_exists(SYSTEM_PROMPT_AGENT_FILE_PATH):
		_system_prompt_token_count = _calculate_tokens(FileAccess.get_file_as_string(SYSTEM_PROMPT_AGENT_FILE_PATH).length(), TOKEN_RATIO_TEXT)
	else:
		_system_prompt_token_count = 0

	if FileAccess.file_exists(GDD_FILE_PATH):
		_gdd_token_count = _calculate_tokens(FileAccess.get_file_as_string(GDD_FILE_PATH).length(), TOKEN_RATIO_TEXT)
	include_gdd_button.text = "Include GDD.txt (~%d tokens)" % _gdd_token_count

	if FileAccess.file_exists(DEVLOG_FILE_PATH):
		_devlog_token_count = _calculate_tokens(FileAccess.get_file_as_string(DEVLOG_FILE_PATH).length(), TOKEN_RATIO_TEXT)
	include_devlog_button.text = "Include DevLog.txt (~%d tokens)" % _devlog_token_count

	if FileAccess.file_exists("res://project.godot"):
		_project_settings_token_count = _calculate_tokens(FileAccess.get_file_as_string("res://project.godot").length(), TOKEN_RATIO_SCENE)
	include_project_settings_button.text = "Include Project Settings (~%d tokens)" % _project_settings_token_count
	
	var uid_map_string: String = ""
	var uid_map: Dictionary = _main_plugin_instance._build_asset_uid_map()
	for file_path in uid_map: uid_map_string += "%s = %s\n" % [file_path, uid_map[file_path]]
	_assets_token_count = _calculate_tokens(uid_map_string.length(), TOKEN_RATIO_SCENE)
	include_assets_button.text = "Include Asset UID Map (~%d tokens)" % _assets_token_count
	
	_resources_token_count = 0
	var resource_files: Array = _main_plugin_instance._find_files_by_extension(["tres", "gdshader"])
	for file_path in resource_files:
		var ratio: float = TOKEN_RATIO_SCRIPT if file_path.get_extension() == "gdshader" else TOKEN_RATIO_SCENE
		_resources_token_count += _calculate_tokens(FileAccess.get_file_as_string(file_path).length(), ratio)
	include_resources_button.text = "Include Resource Files (.tres, .gdshader) (~%d tokens)" % _resources_token_count
	
func _get_excluded_files_from_tree(p_tree: Tree) -> Array[String]:
	var excluded_files: Array[String] = []
	var root: TreeItem = p_tree.get_root()
	if not is_instance_valid(root): return excluded_files
	_find_unchecked_files_recursive(root, excluded_files)
	return excluded_files

func _find_unchecked_files_recursive(p_item: TreeItem, p_excluded_list: Array) -> void:
	if not is_instance_valid(p_item): return
	
	var metadata: Variant = p_item.get_metadata(0)
	if metadata is Dictionary and not metadata.get("is_folder", false):
		if not p_item.is_checked(0):
			p_excluded_list.append(metadata.path)
	
	var child: TreeItem = p_item.get_first_child()
	while is_instance_valid(child):
		_find_unchecked_files_recursive(child, p_excluded_list)
		child = child.get_next()

func _update_ui_and_token_counts() -> void:
	_update_category_token_counts()
		
	var selected_scene_tokens: int = _get_checked_token_sum_from_tree(_scene_exclusion_tree)
	var excluded_scene_count: int = _get_unchecked_item_count_from_tree(_scene_exclusion_tree)
	var scene_label: String = "Include Scene Files (.tscn) (~%d tokens selected" % selected_scene_tokens
	scene_label += ", %d files excluded)" % excluded_scene_count if excluded_scene_count > 0 else ")"
	include_scenes_button.text = scene_label
	
	var selected_code_tokens: int = _get_checked_token_sum_from_tree(_script_exclusion_tree)
	var excluded_code_count: int = _get_unchecked_item_count_from_tree(_script_exclusion_tree)
	var code_label: String = "Include Codebase (.gd, .cs) (~%d tokens selected" % selected_code_tokens
	code_label += ", %d files excluded)" % excluded_code_count if excluded_code_count > 0 else ")"
	include_code_button.text = code_label
	
	include_system_prompt_button.text = "Include System Prompt (~%d tokens)" % _system_prompt_token_count

	_sub_tab_container.set_tab_disabled(1, not include_scenes_button.button_pressed)
	_sub_tab_container.set_tab_disabled(2, not include_code_button.button_pressed)

	_calculate_and_display_total_tokens()

func _get_checked_token_sum_from_tree(p_tree: Tree) -> int:
	return _get_checked_token_sum_recursive(p_tree.get_root())

func _get_checked_token_sum_recursive(p_item: TreeItem) -> int:
	if not is_instance_valid(p_item): return 0
	
	var token_sum: int = 0
	var metadata: Variant = p_item.get_metadata(0)
	
	if metadata is Dictionary and not metadata.get("is_folder", false):
		if p_item.is_checked(0) and metadata.has("tokens"):
			token_sum += int(metadata.tokens)
	
	var child: TreeItem = p_item.get_first_child()
	while is_instance_valid(child):
		token_sum += _get_checked_token_sum_recursive(child)
		child = child.get_next()
	
	return token_sum

func _get_unchecked_item_count_from_tree(p_tree: Tree) -> int:
	return _get_unchecked_item_count_recursive(p_tree.get_root())

func _get_unchecked_item_count_recursive(p_item: TreeItem) -> int:
	if not is_instance_valid(p_item): return 0
	
	var count: int = 0
	var metadata: Variant = p_item.get_metadata(0)
	
	if metadata is Dictionary and not metadata.get("is_folder", false):
		if not p_item.is_checked(0):
			count += 1
	
	var child: TreeItem = p_item.get_first_child()
	while is_instance_valid(child):
		count += _get_unchecked_item_count_recursive(child)
		child = child.get_next()
	
	return count

func _calculate_and_display_total_tokens() -> void:
	var total_tokens: int = 0
	if include_system_prompt_button.button_pressed: total_tokens += _system_prompt_token_count
	if include_gdd_button.button_pressed: total_tokens += _gdd_token_count
	if include_devlog_button.button_pressed: total_tokens += _devlog_token_count
	if include_project_settings_button.button_pressed: total_tokens += _project_settings_token_count
	if include_assets_button.button_pressed: total_tokens += _assets_token_count
	if include_resources_button.button_pressed: total_tokens += _resources_token_count
	if include_scenes_button.button_pressed:
		total_tokens += _get_checked_token_sum_from_tree(_scene_exclusion_tree)
	if include_code_button.button_pressed:
		total_tokens += _get_checked_token_sum_from_tree(_script_exclusion_tree)
	
	_total_tokens_label.text = "Estimated Masterprompt Tokens: ~%d" % total_tokens

# --- Tree Helper Functions ---

func _update_folder_stats_recursive(p_item: TreeItem) -> Dictionary:
	var stats := { "selected_tokens": 0, "total_files": 0, "excluded_files": 0 }
	var metadata: Variant = p_item.get_metadata(0)
	
	# Base case: it's a file
	if metadata is Dictionary and not metadata.get("is_folder", false):
		stats.total_files = 1
		if p_item.is_checked(0):
			stats.selected_tokens = metadata.get("tokens", 0)
		else:
			stats.excluded_files = 1
		return stats
	
	# Recursive step: it's a folder (or the invisible root)
	var child: TreeItem = p_item.get_first_child()
	while is_instance_valid(child):
		var child_stats: Dictionary = _update_folder_stats_recursive(child)
		stats.selected_tokens += child_stats.selected_tokens
		stats.total_files += child_stats.total_files
		stats.excluded_files += child_stats.excluded_files
		child = child.get_next()
		
	# After summing up children, update this folder's text (if it's a real folder)
	if metadata is Dictionary and metadata.get("is_folder", false):
		var folder_name: String = metadata.get("path", "").get_file()
		var text: String = "%s (~%d tokens selected" % [folder_name, stats.selected_tokens]
		if stats.excluded_files > 0:
			text += ", %d files excluded)" % stats.excluded_files
		else:
			text += ")"
		p_item.set_text(0, text)
		
	return stats


func _update_ancestor_folder_texts(p_item: TreeItem) -> void:
	var parent: TreeItem = p_item.get_parent()
	while is_instance_valid(parent) and parent != parent.get_tree().get_root():
		_update_folder_stats_recursive(parent)
		parent = parent.get_parent()


func _set_children_checked_recursive(p_parent_item: TreeItem, p_checked: bool) -> void:
	var child: TreeItem = p_parent_item.get_first_child()
	while is_instance_valid(child):
		child.set_checked(0, p_checked)
		_set_children_checked_recursive(child, p_checked)
		child = child.get_next()

func _update_parent_checked_state_recursive(p_item: TreeItem) -> void:
	var parent: TreeItem = p_item.get_parent()
	if not is_instance_valid(parent) or not is_instance_valid(parent.get_parent()): # Stop at invisible root
		return

	# A folder is considered 'checked' if at least one of its children is checked.
	# This provides a more intuitive state representation than requiring all children to be checked.
	var any_child_checked: bool = false
	var child: TreeItem = parent.get_first_child()
	while is_instance_valid(child):
		if child.is_checked(0):
			any_child_checked = true
			break
		child = child.get_next()
	
	# Only update and recurse if the state has actually changed.
	if parent.is_checked(0) != any_child_checked:
		parent.set_checked(0, any_child_checked)
		_update_parent_checked_state_recursive(parent)

func _filter_tree_items_recursive(p_item: TreeItem, p_query: String) -> bool:
	if not is_instance_valid(p_item): return false

	var is_visible: bool = false
	var metadata: Variant = p_item.get_metadata(0)
	
	if metadata is Dictionary: # Check if it's not the invisible root
		var is_folder: bool = metadata.get("is_folder", false)
		var text_to_check: String = p_item.get_text(0).to_lower() if is_folder else metadata.get("path", "").to_lower()
		
		if p_query.is_empty() or text_to_check.contains(p_query):
			is_visible = true

	var any_child_is_visible: bool = false
	var child: TreeItem = p_item.get_first_child()
	while is_instance_valid(child):
		if _filter_tree_items_recursive(child, p_query):
			any_child_is_visible = true
		child = child.get_next()
	
	if any_child_is_visible:
		is_visible = true
	
	if metadata is Dictionary: # Don't try to set visibility on the invisible root
		p_item.set_visible(is_visible)
	
	return is_visible
