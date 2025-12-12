# res://scripts/ui/WinterCourt_UI.gd
class_name WinterCourtUI
extends Control

# --- Main UI References ---
@onready var action_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/LeftPanel/VBoxContainer/ActionPointsLabel
@onready var jarl_name_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/LeftPanel/VBoxContainer/JarlNameLabel
@onready var jarl_portrait: TextureRect = $MarginContainer/ScreenMargin/RootLayout/TopLayout/LeftPanel/VBoxContainer/JarlPortrait

@onready var upkeep_label: RichTextLabel = $MarginContainer/ScreenMargin/RootLayout/TopLayout/RightPanel/VBoxContainer/UpkeepLabel
@onready var fleet_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/RightPanel/VBoxContainer/FleetLabel
@onready var unrest_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/RightPanel/VBoxContainer/UnrestLabel

@onready var btn_thing: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Thing
@onready var btn_refit: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Refit
@onready var btn_feast: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Feast
@onready var btn_end_winter: Button = $MarginContainer/ScreenMargin/RootLayout/BottomPanel/Btn_EndWinter
@onready var btn_blot: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Blot

# --- Dispute/Crisis Overlay References ---
@onready var dispute_overlay: PanelContainer = $DisputeOverlay
@onready var dispute_title: RichTextLabel = $DisputeOverlay/MarginContainer/VBoxContainer/TitleLabel
@onready var dispute_desc: RichTextLabel = $DisputeOverlay/MarginContainer/VBoxContainer/DescriptionLabel
@onready var btn_resolve_1: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Gold
@onready var btn_resolve_2: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Force
@onready var btn_resolve_3: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Ignore

# --- Internal State ---
var current_dispute: DisputeEventData = null
var winter_start_acknowledged: bool = false

func _ready() -> void:
	btn_thing.pressed.connect(_on_thing_clicked)
	btn_feast.pressed.connect(_on_feast_clicked)
	btn_end_winter.pressed.connect(_on_end_winter_pressed)
	btn_blot.pressed.connect(_on_blot_clicked)
	
	# Reuse Refit button for Muster
	btn_refit.text = "Gather Warband" 
	btn_refit.pressed.connect(_on_gather_warband_clicked) 
	
	dispute_overlay.hide()
	
	# Initial UI Update
	_update_ui()

func _update_ui() -> void:
	var jarl = DynastyManager.current_jarl
	var settlement = SettlementManager.current_settlement
	
	if not jarl or not settlement: return

	# --- Left Panel ---
	jarl_name_label.text = jarl.display_name
	if jarl.portrait: jarl_portrait.texture = jarl.portrait
	
	action_label.text = "Hall Actions: %d / %d" % [jarl.current_hall_actions, jarl.max_hall_actions]
	action_label.modulate = Color.SALMON if jarl.current_hall_actions <= 0 else Color.WHITE

	# --- Right Panel ---
	var readiness_pct := int(settlement.fleet_readiness * 100)
	fleet_label.text = "Fleet Readiness: %d%%" % readiness_pct
	fleet_label.modulate = Color.GREEN if readiness_pct > 80 else Color.YELLOW
	if readiness_pct < 50: fleet_label.modulate = Color.RED

	unrest_label.text = "Unrest: %d/100" % settlement.unrest
	
	# --- Upkeep / Status Text ---
	# Priority 1: Crisis (Updated to check WinterManager)
	if WinterManager.winter_crisis_active:
		_show_crisis_state()
		
	# Priority 2: Winter Arrival Popup
	elif not winter_start_acknowledged:
		_show_winter_start_popup()
		
	# Priority 3: Normal Gameplay
	else:
		_show_normal_state()

func _show_winter_start_popup() -> void:
	btn_thing.disabled = true
	btn_refit.disabled = true
	btn_feast.disabled = true
	btn_end_winter.disabled = true
	
	# FIX: Get report from WinterManager
	var report = WinterManager.winter_consumption_report
	var severity = report.get("severity_name", "NORMAL")
	
	_disconnect_overlay_buttons()
	
	dispute_title.text = "Winter Has Arrived"
	
	var flavor = ""
	var color_tag = "white"
	
	match severity:
		"MILD":
			flavor = "The winds are gentle this year. The spirits are kind."
			color_tag = "green"
		"HARSH":
			flavor = "A biting frost grips the land. Survival will be costly."
			color_tag = "red"
		_:
			flavor = "Snow covers the land. The hearths are lit."
			color_tag = "white"
			
	var desc = "[center][color=%s][b]%s WINTER[/b][/color][/center]\n\n" % [color_tag, severity]
	desc += "[i]%s[/i]\n\n" % flavor
	desc += "Resources Consumed:\n"
	desc += "- Food: %d\n" % report.get("food_cost", 0)
	desc += "- Wood: %d\n" % report.get("wood_cost", 0)
	
	dispute_desc.text = desc.replace("[center]", "").replace("[/center]", "")
	
	btn_resolve_1.show()
	btn_resolve_1.text = "Enter Court"
	btn_resolve_1.disabled = false
	btn_resolve_1.pressed.connect(func():
		winter_start_acknowledged = true
		_close_overlay()
	)
	
	btn_resolve_2.hide()
	btn_resolve_3.hide()
	
	dispute_overlay.show()

func _show_crisis_state() -> void:
	btn_thing.disabled = true
	btn_refit.disabled = true
	btn_feast.disabled = true
	btn_end_winter.disabled = true
	btn_end_winter.text = "RESOLVE CRISIS FIRST"
	btn_end_winter.modulate = Color.RED
	
	# FIX: Get report from WinterManager
	var report = WinterManager.winter_consumption_report
	var text = "[center][color=red][b]CRISIS: SHORTAGES[/b][/color][/center]\n"
	text += "Deficit: %d Food, %d Wood\n" % [report["food_deficit"], report["wood_deficit"]]
	text += "You must resolve this before holding court."
	upkeep_label.text = text
	
	_display_crisis_overlay()

func _show_normal_state() -> void:
	btn_end_winter.disabled = false
	btn_end_winter.text = "The Ice Melts (Begin Summer)"
	btn_end_winter.modulate = Color.WHITE
	
	_update_button_states()
	
	# FIX: Get report from WinterManager
	var report = WinterManager.winter_upkeep_report
	var text = "[b]Winter Log:[/b]\n"
	if report.is_empty():
		text += "Waiting for report..."
	else:
		text += "Food Consumed: %d\n" % report.get("food_consumed", 0)
		text += "Wood Burned: %d\n" % report.get("wood_consumed", 0)
		text += "[color=green]Survival Secured.[/color]"
	upkeep_label.text = text

func _update_button_states() -> void:
	var has_actions := DynastyManager.current_jarl.current_hall_actions > 0
	var settlement = SettlementManager.current_settlement
	
	# 1. THING
	btn_thing.disabled = not has_actions
	btn_thing.tooltip_text = "COST: 1 Hall Action\nEFFECT: Resolve a dispute to prevent Unrest."
	if not has_actions: btn_thing.tooltip_text += "\n(LOCKED: No Hall Actions remaining)"

	# 2. FEAST
	var warband_count = settlement.warbands.size()
	var food_cost = max(100, warband_count * 50)
	var current_food = settlement.treasury.get("food", 0)
	var can_afford_feast = current_food >= food_cost
	
	btn_feast.text = "Host Yule Feast"
	var feast_tt = "COST: %d Food, 1 Hall Action\nEFFECT: +50 Renown, Maximize Loyalty." % food_cost
	
	if not has_actions:
		btn_feast.disabled = true
		feast_tt += "\n(LOCKED: No Hall Actions)"
	elif not can_afford_feast:
		btn_feast.disabled = true
		feast_tt += "\n(LOCKED: Not enough Food)"
	elif warband_count == 0:
		btn_feast.disabled = true
		feast_tt += "\n(LOCKED: No Warbands)"
	else:
		btn_feast.disabled = false
		
	btn_feast.tooltip_text = feast_tt
	
	# 3. GATHER WARBAND
	var gather_tt = "COST: 1 Hall Action\nEFFECT: Attract Seasonal Drengir."
	if not has_actions:
		btn_refit.disabled = true
		gather_tt += "\n(LOCKED: No Hall Actions)"
	else:
		btn_refit.disabled = false
	btn_refit.tooltip_text = gather_tt

func _disconnect_overlay_buttons() -> void:
	var buttons = [btn_resolve_1, btn_resolve_2, btn_resolve_3]
	for btn in buttons:
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])

func _display_crisis_overlay() -> void:
	_disconnect_overlay_buttons()
	
	# FIX: Report from WinterManager
	var report = WinterManager.winter_consumption_report
	var food_def = report["food_deficit"]
	var wood_def = report["wood_deficit"]
	var food_total = report.get("food_cost", 0)
	var wood_total = report.get("wood_cost", 0)
	
	var narrative_title = "HARDSHIP"
	var narrative_body = ""
	
	if food_def > 0 and wood_def > 0:
		narrative_title = "DESOLATION"
		narrative_body = "The gods have abandoned us. We lack both food and fire."
	elif food_def > 0:
		narrative_title = "FAMINE LOOMS"
		narrative_body = "The granaries are bare. The people cry out for bread."
	elif wood_def > 0:
		narrative_title = "THE DEEP FREEZE"
		narrative_body = "The woodpiles are exhausted. The frost creeps into the longhouse."
	
	dispute_title.text = narrative_title
	
	var text = "[center]%s[/center]\n\n" % narrative_body
	text += "[b]Survival Costs:[/b] %d Food, %d Wood\n" % [food_total, wood_total]
	text += "[color=red][b]MISSING:[/b] "
	
	var missing_items = []
	if food_def > 0: missing_items.append("%d Food" % food_def)
	if wood_def > 0: missing_items.append("%d Wood" % wood_def)
	
	text += ", ".join(missing_items) + "[/color]\n\n"
	text += "[i]Sacrifices must be made to survive the night.[/i]"
	
	dispute_desc.text = text
	
	btn_resolve_1.show()
	btn_resolve_2.show()
	btn_resolve_3.show()
	
	# OPTION 1: Gold
	var gold_cost = (food_def * 5) + (wood_def * 5)
	btn_resolve_1.text = "Import Supplies"
	btn_resolve_1.tooltip_text = "COST: %d Gold" % gold_cost
	btn_resolve_1.disabled = SettlementManager.current_settlement.treasury.get("gold", 0) < gold_cost
	
	btn_resolve_1.pressed.connect(func():
		# FIX: Call WinterManager
		if WinterManager.resolve_crisis_with_gold():
			winter_start_acknowledged = true 
			_close_overlay()
	)
	
	# OPTION 2 & 3: Sacrifice
	var has_action = DynastyManager.current_jarl.current_hall_actions > 0
	
	if food_def > 0:
		var deaths = max(1, int(food_def / 5))
		btn_resolve_2.text = "Deny Rations"
		btn_resolve_2.tooltip_text = "COST: 1 Hall Action\nSACRIFICE: %d Peasants" % deaths
		btn_resolve_2.disabled = not has_action
		
		btn_resolve_2.pressed.connect(func():
			# FIX: Call WinterManager
			if WinterManager.resolve_crisis_with_sacrifice("starve_peasants"):
				winter_start_acknowledged = true
				_close_overlay()
		)
		
		btn_resolve_3.text = "Disband Warband"
		btn_resolve_3.tooltip_text = "COST: 1 Hall Action\nSACRIFICE: 1 Military Unit"
		btn_resolve_3.disabled = not has_action or SettlementManager.current_settlement.warbands.is_empty()
		
		btn_resolve_3.pressed.connect(func():
			# FIX: Call WinterManager
			if WinterManager.resolve_crisis_with_sacrifice("disband_warband"):
				winter_start_acknowledged = true
				_close_overlay()
		)
		
	elif wood_def > 0:
		btn_resolve_2.text = "Burn the Longships"
		btn_resolve_2.tooltip_text = "COST: 1 Hall Action\nSACRIFICE: Fleet Readiness (0%)"
		btn_resolve_2.disabled = not has_action
		
		btn_resolve_2.pressed.connect(func():
			# FIX: Call WinterManager
			if WinterManager.resolve_crisis_with_sacrifice("burn_ships"):
				winter_start_acknowledged = true
				_close_overlay()
		)
		btn_resolve_3.hide()
	
	dispute_overlay.show()

func _on_end_winter_pressed() -> void:
	# FIX: Call WinterManager
	WinterManager.end_winter_phase()

# --- OTHER FUNCTIONS (Gather Warband, Disputes, Feast, Blot) UNCHANGED BUT INCLUDED ---
func _on_gather_warband_clicked() -> void:
	# Cost: 1 Hall Action
	if not DynastyManager.perform_hall_action(1): return
	
	var jarl = DynastyManager.get_current_jarl()
	
	# Logic: Base 1 + Luck(0-2) + Renown Bonus
	var total_squads_arrived = 1 + randi_range(0, 2) + int(jarl.renown / 100.0)
	
	var ship_cap = SettlementManager.get_total_ship_capacity_squads()
	var current_squads = SettlementManager.current_settlement.warbands.size()
	var open_slots = max(0, ship_cap - current_squads)
	
	var accepted = min(total_squads_arrived, open_slots)
	var rejected = total_squads_arrived - accepted
	
	if accepted > 0:
		var drengr = load("res://data/units/Unit_Drengr.tres")
		# [FIX] Use SettlementManager
		SettlementManager.queue_seasonal_recruit(drengr, accepted * WarbandData.MAX_MANPOWER)
	
	var result_text = "[color=green]Recruited: %d Squads[/color]" % accepted
	if rejected > 0:
		var renown_loss = rejected * 10
		DynastyManager.spend_renown(renown_loss)
		result_text += "\n[color=red]Turned Away: %d (-%d Renown)[/color]" % [rejected, renown_loss]
		
	_display_action_result("The Winter Muster", "Warriors answer your call.", result_text)
	_update_ui()

func _on_thing_clicked() -> void:
	if DynastyManager.perform_hall_action(1):
		# [FIX] Call EventManager instead of DynastyManager
		var card = EventManager.draw_dispute_card()
		_display_dispute(card)

func _display_dispute(card: DisputeEventData) -> void:
	_disconnect_overlay_buttons()
	current_dispute = card
	dispute_title.text = card.title
	dispute_desc.text = card.description
	
	btn_resolve_1.show()
	btn_resolve_1.text = "Pay Wergild (%d G)" % card.gold_cost
	btn_resolve_1.disabled = SettlementManager.current_settlement.treasury.get("gold", 0) < card.gold_cost
	btn_resolve_1.pressed.connect(_on_dispute_pay_gold)
	
	btn_resolve_2.show()
	if card.bans_unit:
		btn_resolve_2.text = "Banish Unit"
		btn_resolve_2.disabled = SettlementManager.current_settlement.warbands.is_empty()
	else:
		btn_resolve_2.text = "Force (%d Renown)" % card.renown_cost
		btn_resolve_2.disabled = DynastyManager.current_jarl.renown < card.renown_cost
	btn_resolve_2.pressed.connect(_on_dispute_pay_force)
	
	btn_resolve_3.show()
	btn_resolve_3.text = "Ignore"
	btn_resolve_3.pressed.connect(_on_dispute_ignore)
	dispute_overlay.show()

func _on_dispute_pay_gold() -> void:
	if SettlementManager.attempt_purchase({"gold": current_dispute.gold_cost}):
		_close_overlay()

func _on_dispute_pay_force() -> void:
	if current_dispute.bans_unit:
		var s = SettlementManager.current_settlement
		if not s.warbands.is_empty(): s.warbands.erase(s.warbands.pick_random())
	else:
		DynastyManager.spend_renown(current_dispute.renown_cost)
	_close_overlay()

func _on_dispute_ignore() -> void:
	DynastyManager.apply_year_modifier(current_dispute.penalty_modifier_key)
	_close_overlay()

func _on_feast_clicked() -> void:
	var s = SettlementManager.current_settlement
	var cost = max(100, s.warbands.size() * 50)
	if SettlementManager.attempt_purchase({"food": cost}):
		if DynastyManager.perform_hall_action(1):
			for wb in s.warbands: wb.loyalty = 100
			DynastyManager.award_renown(50)
			_display_action_result("Yule Feast", "The hall rejoices.", "[color=green]+50 Renown\nLoyalty Restored[/color]")
			_update_ui()

func _on_blot_clicked() -> void:
	if not DynastyManager.current_jarl.current_hall_actions > 0: return
	if not SettlementManager.attempt_purchase({"food": 50}): return
	_display_blot_options()

func _display_blot_options() -> void:
	_disconnect_overlay_buttons()
	dispute_title.text = "The Great Blót"
	dispute_desc.text = "To which god shall we sacrifice?\n[i](Paid: 50 Food)[/i]"
	
	btn_resolve_1.show()
	btn_resolve_1.text = "Odin (XP)"
	btn_resolve_1.pressed.connect(func(): _commit_blot("BLOT_ODIN", "Odin"))
	
	btn_resolve_2.show()
	btn_resolve_2.text = "Thor (Damage)"
	btn_resolve_2.pressed.connect(func(): _commit_blot("BLOT_THOR", "Thor"))
	
	btn_resolve_3.show()
	btn_resolve_3.text = "Freyr (Heir)"
	btn_resolve_3.pressed.connect(func(): _commit_blot("BLOT_FREYR", "Freyr"))
	
	dispute_overlay.show()

func _commit_blot(key: String, god: String) -> void:
	if DynastyManager.perform_hall_action(1):
		DynastyManager.apply_year_modifier(key)
		_display_action_result("Sacrifice Accepted", "%s is pleased." % god, "Modifier Active: %s" % key)
		_update_ui()

func _display_action_result(title: String, flavor: String, result: String) -> void:
	_disconnect_overlay_buttons()
	dispute_title.text = title
	dispute_desc.text = "%s\n\n[b]RESULT:[/b]\n%s" % [flavor, result]
	btn_resolve_1.show()
	btn_resolve_1.text = "Skål!"
	btn_resolve_1.disabled = false
	btn_resolve_1.pressed.connect(_close_overlay)
	btn_resolve_2.hide()
	btn_resolve_3.hide()
	dispute_overlay.show()

func _close_overlay() -> void:
	dispute_overlay.hide()
	_update_ui()
