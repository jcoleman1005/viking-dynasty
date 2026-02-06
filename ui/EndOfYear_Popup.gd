#res://ui/EndOfYear_Popup.gd
# res://ui/EndOfYear_Popup.gd
extends PanelContainer

signal collect_button_pressed(payout: Dictionary)

@onready var payout_label: RichTextLabel = $MarginContainer/VBoxContainer/PayoutLabel
@onready var collect_button: Button = $MarginContainer/VBoxContainer/CollectButton
@onready var loot_panel: PanelContainer = %LootDistributionPanel
@onready var loot_slider: HSlider = %LootSlider
@onready var result_label: Label = %DistributionResultLabel

var _base_payout: Dictionary = {}
var _final_payout: Dictionary = {}
var _total_loot_gold: int = 0

func _ready() -> void:
	# --- FIX: Allow this node to run while game is paused ---
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# -------------------------------------------------------
	
	collect_button.pressed.connect(_on_collect_pressed)
	if loot_slider:
		loot_slider.value_changed.connect(_update_distribution_preview)
	
	# Ensure hidden and not blocking input at start
	hide() 

func display_payout(payout: Dictionary, title: String = "Welcome home!") -> void:
	_base_payout = payout.duplicate()
	_final_payout = payout.duplicate()
	
	var is_raid = title.contains("Raid") or title.contains("Victory")
	_total_loot_gold = payout.get("gold", 0)
	
	# Logic to show/hide slider
	if is_raid and _total_loot_gold > 0:
		if loot_panel: loot_panel.show()
		if loot_slider: 
			loot_slider.value = 0 
			_update_distribution_preview(0)
	else:
		if loot_panel: loot_panel.hide()
	
	_update_text_display(title)
	
	# --- FIX: PAUSE THE GAME ---
	get_tree().paused = true
	# ---------------------------
	
	show()
	# Force layout update to prevent squashed UI
	queue_sort()

func _update_distribution_preview(percent_shared: float) -> void:
	var share_pct = percent_shared / 100.0
	var gold_shared = int(_total_loot_gold * share_pct)
	var gold_kept = _total_loot_gold - gold_shared
	
	var renown_change = 0
	if percent_shared < 20: renown_change = -50
	elif percent_shared < 50: renown_change = 0
	elif percent_shared < 80: renown_change = 20
	else: renown_change = 100
		
	if result_label:
		var sign_str = "+" if renown_change > 0 else ""
		result_label.text = "Keep: %d G  |  Share: %d G\nRenown: %s%d" % [gold_kept, gold_shared, sign_str, renown_change]
		
		# Use brighter colors for readability
		result_label.modulate = Color.WHITE
		if renown_change < 0: result_label.modulate = Color(1, 0.4, 0.4) # Bright Salmon
		elif renown_change > 0: result_label.modulate = Color(0.4, 1, 0.4) # Bright Green
	
	_final_payout = _base_payout.duplicate()
	_final_payout["gold"] = gold_kept
	_final_payout["renown"] = renown_change

func _update_text_display(title: String) -> void:
	var text: String = "[b]%s[/b]\n\n" % title
	if _base_payout.has("_messages"):
		text += "[b]Incidents:[/b]\n"
		for msg in _base_payout["_messages"]: text += "%s\n" % msg
		text += "\n"
	text += "[b]Resources:[/b]\n"
	for key in _base_payout:
		if key.begins_with("_") or key == "population_growth": continue
		var val = _base_payout[key]
		if val != 0:
			var col = "green" if val > 0 else "salmon" # Brighter red
			text += "- %s: [color=%s]%d[/color]\n" % [key.capitalize(), col, val]
	payout_label.text = text

func _on_collect_pressed() -> void:
	# --- FIX: UNPAUSE THE GAME ---
	get_tree().paused = false
	# -----------------------------
	
	collect_button_pressed.emit(_final_payout)
	hide()
