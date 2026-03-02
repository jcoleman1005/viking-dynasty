# res://scenes/winter/HeirTrainingAction.gd
# Winter Hall Action: Train the Heir.
# Lists available training sources and applies a stat boost to the active heir.
# Costs 1 Hall Action on confirm.
extends PanelContainer

@onready var sources_container: VBoxContainer = $MarginContainer/VBoxContainer/SourcesContainer
@onready var confirm_btn: Button               = $MarginContainer/VBoxContainer/ConfirmButton
@onready var cancel_btn: Button                = $MarginContainer/VBoxContainer/CancelButton
@onready var preview_label: Label              = $MarginContainer/VBoxContainer/PreviewLabel

var _selected_source: Dictionary = {}  # {type, stat, amount, label}
var _source_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(queue_free)
	preview_label.text = ""
	_build_source_list()


func _build_source_list() -> void:
	var jarl := DynastyManager.current_jarl
	if not jarl:
		return

	var heir := jarl.get_first_available_heir()
	if not heir:
		preview_label.text = "No available heir to train."
		confirm_btn.disabled = true
		return

	var sources: Array[Dictionary] = []

	# --- Households as training sources ---
	var settlement := SettlementManager.current_settlement
	if settlement:
		for household in settlement.households:
			var boost := calculate_training_boost("household", household)
			if boost["amount"] > 0:
				sources.append({
					"type":   "household",
					"label":  "%s (Tradition: +%d %s)" % [household.household_name, boost["amount"], boost["stat"]],
					"stat":   boost["stat"],
					"amount": boost["amount"],
					"source": household,
				})

	# --- Jarl as training source ---
	var jarl_boost := calculate_training_boost("jarl", jarl)
	sources.append({
		"type":   "jarl",
		"label":  "Learn from %s (+%d %s)" % [jarl.display_name, jarl_boost["amount"], jarl_boost["stat"]],
		"stat":   jarl_boost["stat"],
		"amount": jarl_boost["amount"],
		"source": jarl,
	})

	# Build buttons
	for i in sources.size():
		var source_data := sources[i]
		var btn := Button.new()
		btn.text = source_data["label"]
		var idx := i
		btn.pressed.connect(func(): _on_source_selected(idx, sources[idx]))
		_source_buttons.append(btn)
		sources_container.add_child(btn)


## Calculates the training boost from a given source.
## Returns {stat: String, amount: int}
func calculate_training_boost(source_type: String, source_data) -> Dictionary:
	match source_type:
		"household":
			var tradition_multiplier :float = 1.0 + (source_data.consecutive_oath_years * 0.15)
			var stat_from_oath := _oath_to_stat(source_data.current_oath)
			if stat_from_oath == "":
				return {"stat": "command", "amount": 0}
			return {
				"stat":   stat_from_oath,
				"amount": int(2 * tradition_multiplier),
			}
		"jarl":
			var best_stat := _highest_stat(source_data)
			return {"stat": best_stat, "amount": 2}
		"tutor":
			return {"stat": source_data.get("tutor_stat", "command"), "amount": 4}
	return {"stat": "command", "amount": 0}


func _oath_to_stat(oath: int) -> String:
	match oath:
		HouseholdData.SeasonalOath.HARVEST: return "stewardship"
		HouseholdData.SeasonalOath.RAID:    return "command"
		HouseholdData.SeasonalOath.BUILD:   return "learning"
		HouseholdData.SeasonalOath.TIMBER:  return "stewardship"
	return ""


func _highest_stat(jarl: JarlData) -> String:
	var stats := {
		"command":     jarl.command,
		"diplomacy":   jarl.diplomacy,
		"stewardship": jarl.stewardship,
		"learning":    jarl.learning,
		"prowess":     jarl.prowess,
		"charisma":    jarl.charisma,
	}
	var best := "command"
	var best_val := 0
	for s in stats:
		if stats[s] > best_val:
			best_val = stats[s]
			best = s
	return best


func _on_source_selected(index: int, source_data: Dictionary) -> void:
	_selected_source = source_data

	for i in _source_buttons.size():
		_source_buttons[i].disabled = (i == index)

	preview_label.text = "Train %s: +%d %s" % [
		DynastyManager.current_jarl.get_first_available_heir().display_name if DynastyManager.current_jarl else "Heir",
		source_data["amount"],
		source_data["stat"].capitalize(),
	]
	confirm_btn.disabled = false


func _on_confirm_pressed() -> void:
	if _selected_source.is_empty():
		return

	var jarl := DynastyManager.current_jarl
	if not jarl:
		queue_free()
		return

	var heir := jarl.get_first_available_heir()
	if not heir:
		queue_free()
		return

	# Apply boost to heir
	var stat: String = _selected_source["stat"]
	var amount: int  = _selected_source["amount"]
	var current_val: int = heir.get(stat) if heir.get(stat) != null else 0
	heir.set(stat, current_val + amount)

	# Log Skald event
	var source_name: String = _selected_source.get("label", "unknown source").split("(")[0].strip_edges()
	EventManager._log_skald_event("heir_training", {
		"heir_name":   heir.display_name,
		"source_name": source_name,
		"stat":        stat,
		"amount":      amount,
	}, 1)

	# Spend Hall Action
	DynastyManager.perform_hall_action(1)

	Loggie.msg("HeirTraining: %s gained +%d %s from %s." % [heir.display_name, amount, stat, source_name]).domain(LogDomains.DYNASTY).info()

	queue_free()
