@tool
extends VBoxContainer

# --- Signals ---
signal settings_pressed
signal prompts_pressed
signal agent_pressed
signal export_pressed

# --- UI References ---
@onready var _settings_button: Button = $SettingsButton
@onready var _prompts_button: Button = $PromptsButton
@onready var _agent_button: Button = $AgentButton
@onready var _export_button: Button = $ExportButton

func _ready() -> void:
	_settings_button.pressed.connect(func(): emit_signal("settings_pressed"))
	_prompts_button.pressed.connect(func(): emit_signal("prompts_pressed"))
	_agent_button.pressed.connect(func(): emit_signal("agent_pressed"))
	_export_button.pressed.connect(func(): emit_signal("export_pressed"))
