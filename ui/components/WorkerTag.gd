#res://ui/components/WorkerTag.gd
# res://ui/components/WorkerTag.gd
class_name WorkerTag
extends Control

var building_index: int = -1
var is_pending: bool = false # NEW FLAG
var caps = {"peasant": 0, "thrall": 0}

@onready var lbl_peasant = $Panel/VBox/HBox_Peasant/CountLabel
@onready var lbl_thrall = $Panel/VBox/HBox_Thrall/CountLabel

func _ready() -> void:
	# --- FIX: Allow mouse to pass through the empty root control ---
	# This ensures we don't block clicks for other tags or the map.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("Panel"):
		$Panel.mouse_filter = Control.MOUSE_FILTER_STOP

# Update signature to accept is_pending
func setup(idx: int, p_count: int, p_cap: int, t_count: int, t_cap: int, _pending: bool = false) -> void:
	building_index = idx
	is_pending = _pending
	caps["peasant"] = p_cap
	caps["thrall"] = t_cap
	
	_update_labels(p_count, t_count)
	
	# Disconnect old connections if reused (safety)
	# Since we instantiate new tags every time, fresh connection is fine.
	
	$Panel/VBox/HBox_Peasant/Btn_Minus.pressed.connect(_on_mod.bind("peasant", -1))
	$Panel/VBox/HBox_Peasant/Btn_Plus.pressed.connect(_on_mod.bind("peasant", 1))
	$Panel/VBox/HBox_Thrall/Btn_Minus.pressed.connect(_on_mod.bind("thrall", -1))
	$Panel/VBox/HBox_Thrall/Btn_Plus.pressed.connect(_on_mod.bind("thrall", 1))

func _on_mod(type: String, amount: int) -> void:
	# --- FIX: Route to correct manager function ---
	if is_pending:
		SettlementManager.assign_construction_worker(building_index, type, amount)
	else:
		SettlementManager.assign_worker(building_index, type, amount)
	# ----------------------------------------------

func _update_labels(p_val: int, t_val: int) -> void:
	lbl_peasant.text = "Citizens: %d / %d" % [p_val, caps["peasant"]]
	lbl_thrall.text = "Thralls: %d / %d" % [t_val, caps["thrall"]]
