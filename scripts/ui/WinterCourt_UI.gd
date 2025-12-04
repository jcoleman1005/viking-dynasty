# res://ui/WinterCourt_UI.gd
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
# We reuse the DisputeOverlay for the Winter Crisis to save resources/time.
@onready var dispute_overlay: PanelContainer = $DisputeOverlay
@onready var dispute_title: RichTextLabel = $DisputeOverlay/MarginContainer/VBoxContainer/TitleLabel
@onready var dispute_desc: RichTextLabel = $DisputeOverlay/MarginContainer/VBoxContainer/DescriptionLabel
@onready var btn_resolve_1: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Gold
@onready var btn_resolve_2: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Force
@onready var btn_resolve_3: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Ignore
@onready var btn_muster: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Refit # Repurposing 'Refit' for this example, or create a new one.
# --- Internal State ---
var current_dispute: DisputeEventData = null
var winter_start_acknowledged: bool = false

func _ready() -> void:
	# 1. Main Action Connections
	btn_thing.pressed.connect(_on_thing_clicked)
	btn_refit.pressed.connect(_on_refit_clicked)
	btn_feast.pressed.connect(_on_feast_clicked)
	btn_end_winter.pressed.connect(_on_end_winter_pressed)
	btn_blot.pressed.connect(_on_blot_clicked)
	btn_refit.text = "Gather Warband" 
	btn_refit.pressed.disconnect(_on_refit_clicked) # Disconnect old logic
	btn_refit.pressed.connect(_on_gather_warband_clicked) # Connect new logic
	
	dispute_overlay.hide()
	
	# 2. Initial UI Update
	_update_ui()
func _on_gather_warband_clicked() -> void:
	if not DynastyManager.perform_hall_action(1):
		return
		
	var jarl = DynastyManager.get_current_jarl()
	
	# 1. Calculate MUSTER (Who shows up?)
	# Formula: Base (1) + Random(0-2) + (Renown / 100)
	var base_recruits = 1 
	var wanderers = randi_range(0, 2)
	var fame_bonus = int(jarl.renown / 100.0)
	
	var total_squads_arrived = base_recruits + wanderers + fame_bonus
	
	# 2. Calculate CAPACITY (Do we have seats?)
	var ship_cap = SettlementManager.get_total_ship_capacity_squads()
	var current_squads = SettlementManager.current_settlement.warbands.size()
	var open_slots = max(0, ship_cap - current_squads)
	
	# 3. The Overflow Logic
	var accepted_squads = min(total_squads_arrived, open_slots)
	var rejected_squads = total_squads_arrived - accepted_squads
	
	# 4. Execute
	var drengr_data = load("res://data/units/Unit_Drengr.tres")
	
	# Add Accepted
	DynastyManager.queue_seasonal_recruit(drengr_data, accepted_squads * WarbandData.MAX_MANPOWER)
	
	# Handle Rejected (The Consequence)
	var flavor = ""
	var result = ""
	
	if rejected_squads > 0:
		# Option A: Send them home (Renown Hit)
		# For simplicity in this step, we just turn them away automatically.
		# In a polished version, this would be a popup choice.
		var renown_loss = rejected_squads * 10
		DynastyManager.spend_renown(renown_loss)
		
		flavor = "The hall is packed. %d squads arrived, but your ships are full.\n" % total_squads_arrived
		flavor += "You turn away %d squads. They grumble and leave." % rejected_squads
		result = "[color=green]Recruited: %d Squads[/color]\n[color=red]Turned Away: %d (-%d Renown)[/color]" % [accepted_squads, rejected_squads, renown_loss]
	else:
		flavor = "Your call is answered. %d squads of Drengir swear to your ship." % accepted_squads
		result = "[color=green]Recruited: %d Squads[/color]" % accepted_squads

	_display_action_result("The Winter Muster", flavor, result)
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
	# Priority 1: Crisis (Overrides everything)
	if DynastyManager.winter_crisis_active:
		_show_crisis_state()
		
	# Priority 2: Winter Arrival Popup (If not seen yet)
	elif not winter_start_acknowledged:
		_show_winter_start_popup()
		
	# Priority 3: Normal Gameplay (Court Actions)
	else:
		_show_normal_state()
func _show_winter_start_popup() -> void:
	# 1. Lock Background Buttons
	btn_thing.disabled = true
	btn_refit.disabled = true
	btn_feast.disabled = true
	btn_end_winter.disabled = true
	
	# 2. Prepare Data
	var report = DynastyManager.winter_consumption_report
	var severity = report.get("severity", "NORMAL")
	
	# 3. Configure Overlay
	_disconnect_overlay_buttons()
	
	dispute_title.text = "Winter Has Arrived"
	
	# Build Flavor Text
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
	
	# Note: We rely on RichTextLabel parsing bbcode. 
	# If DescriptionLabel is a standard Label, remove the tags or swap it to RichTextLabel in scene.
	dispute_desc.text = desc.replace("[center]", "").replace("[/center]", "") # Strip center if standard label
	
	# 4. Configure "Continue" Button
	btn_resolve_1.show()
	btn_resolve_1.text = "Enter Court"
	btn_resolve_1.disabled = false
	btn_resolve_1.pressed.connect(func():
		winter_start_acknowledged = true
		_close_overlay()
	)
	
	# Hide unused buttons
	btn_resolve_2.hide()
	btn_resolve_3.hide()
	
	dispute_overlay.show()

func _show_crisis_state() -> void:
	# Lock Normal Actions
	btn_thing.disabled = true
	btn_refit.disabled = true
	btn_feast.disabled = true
	btn_end_winter.disabled = true
	btn_end_winter.text = "RESOLVE CRISIS FIRST"
	btn_end_winter.modulate = Color.RED
	
	var report = DynastyManager.winter_consumption_report
	var text = "[center][color=red][b]CRISIS: SHORTAGES[/b][/color][/center]\n"
	text += "Deficit: %d Food, %d Wood\n" % [report["food_deficit"], report["wood_deficit"]]
	text += "You must resolve this before holding court."
	upkeep_label.text = text
	
	# Trigger Overlay automatically or wait for user? 
	# Let's force it open so they can't miss it.
	_display_crisis_overlay()

func _show_normal_state() -> void:
	btn_end_winter.disabled = false
	btn_end_winter.text = "The Ice Melts (Begin Summer)"
	btn_end_winter.modulate = Color.WHITE
	
	_update_button_states()
	
	# Standard Report
	var report = DynastyManager.winter_upkeep_report
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
	
	# --- 1. THING BUTTON ---
	btn_thing.disabled = not has_actions
	btn_thing.tooltip_text = "COST: 1 Hall Action\nEFFECT: Resolve a dispute to prevent Unrest."
	if not has_actions:
		btn_thing.tooltip_text += "\n(LOCKED: No Hall Actions remaining)"

	# --- 2. FEAST BUTTON ---
	var warband_count = settlement.warbands.size()
	var food_cost = max(100, warband_count * 50)
	var current_food = settlement.treasury.get("food", 0)
	var can_afford_feast = current_food >= food_cost
	
	btn_feast.text = "Host Yule Feast"
	
	var feast_tt = "COST: %d Food, 1 Hall Action\n" % food_cost
	feast_tt += "EFFECT: +50 Renown, Maximize Loyalty of all Warbands."
	
	if not has_actions:
		btn_feast.disabled = true
		feast_tt += "\n(LOCKED: No Hall Actions remaining)"
	elif not can_afford_feast:
		btn_feast.disabled = true
		feast_tt += "\n(LOCKED: Not enough Food! Need %d)" % food_cost
	elif warband_count == 0:
		btn_feast.disabled = true
		feast_tt += "\n(LOCKED: No Warbands to feed)"
	else:
		btn_feast.disabled = false
		
	btn_feast.tooltip_text = feast_tt
	
	# --- 3. GATHER WARBAND BUTTON (The Winter Muster) ---
	# Replaces the old "Refit" logic
	btn_refit.text = "Gather Warband"
	
	var gather_tt = "COST: 1 Hall Action\n"
	gather_tt += "EFFECT: Proclaim the raid! Attract Seasonal Drengir based on your Renown & Luck."
	
	if not has_actions:
		btn_refit.disabled = true
		gather_tt += "\n(LOCKED: No Hall Actions remaining)"
	else:
		btn_refit.disabled = false
		
	btn_refit.tooltip_text = gather_tt

func _disconnect_overlay_buttons() -> void:
	# Clean slate for signals
	var buttons = [btn_resolve_1, btn_resolve_2, btn_resolve_3]
	for btn in buttons:
		if btn.pressed.is_connected(_on_dispute_pay_gold): btn.pressed.disconnect(_on_dispute_pay_gold)
		if btn.pressed.is_connected(_on_dispute_pay_force): btn.pressed.disconnect(_on_dispute_pay_force)
		if btn.pressed.is_connected(_on_dispute_ignore): btn.pressed.disconnect(_on_dispute_ignore)
		# Also disconnect anonymous lambdas if we used them previously (requires care, better to use named funcs or one-shot rebuild)
		# For this implementation, we only use named functions for Disputes and Lambdas for Crisis.
		# Since we can't easily disconnect lambdas by name, we ensure we only connect one set at a time
		# or use a centralized handler. 
		# **Optimization**: We will simply recreate the connections fresh every time.
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])

func _display_crisis_overlay() -> void:
	_disconnect_overlay_buttons()
	
	var report = DynastyManager.winter_consumption_report
	var food_def = report["food_deficit"]
	var wood_def = report["wood_deficit"]
	var food_total = report.get("food_cost", 0)
	var wood_total = report.get("wood_cost", 0)
	
	# --- 1. Dynamic Narrative Title & Body (Existing Logic) ---
	var narrative_title = ""
	var narrative_body = ""
	
	if food_def > 0 and wood_def > 0:
		narrative_title = "DESOLATION"
		narrative_body = "The gods have abandoned us. We lack both food and fire. Without aid, the clan will perish in the dark."
	elif food_def > 0:
		narrative_title = "FAMINE LOOMS"
		narrative_body = "The granaries are bare. The people cry out for bread, but we have none to give."
	elif wood_def > 0:
		narrative_title = "THE DEEP FREEZE"
		narrative_body = "The woodpiles are exhausted. The frost creeps into the longhouse, and the old ones grow weak."
	else:
		narrative_title = "HARDSHIP"
	
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
	
	# --- 2. Button Configuration ---
	
	btn_resolve_1.show()
	btn_resolve_2.show()
	btn_resolve_3.show()
	
	# OPTION 1: PAY GOLD (Imports)
	var gold_cost = (food_def * 5) + (wood_def * 5)
	
	# Flavor Text
	btn_resolve_1.text = "Import Supplies"
	# Mechanical Tooltip
	btn_resolve_1.tooltip_text = "COST: %d Gold\nEFFECT: Resolves all shortages immediately via emergency trade." % gold_cost
	
	btn_resolve_1.disabled = SettlementManager.current_settlement.treasury.get("gold", 0) < gold_cost
	btn_resolve_1.pressed.connect(func():
		if DynastyManager.resolve_crisis_with_gold():
			winter_start_acknowledged = true 
			_close_overlay()
	)
	
	# OPTION 2 & 3: SACRIFICE
	var has_action = DynastyManager.current_jarl.current_hall_actions > 0
	
	if food_def > 0:
		# Choice A: Starvation
		var deaths = max(1, int(food_def / 5))
		
		btn_resolve_2.text = "Deny Rations"
		btn_resolve_2.tooltip_text = "COST: 1 Hall Action\nSACRIFICE: %d Peasants (Die of Starvation)\nEFFECT: Reduces Food demand to match supply." % deaths
		
		btn_resolve_2.disabled = not has_action
		btn_resolve_2.pressed.connect(func():
			if DynastyManager.resolve_crisis_with_sacrifice("starve_peasants"):
				winter_start_acknowledged = true
				_close_overlay()
		)
		
		# Choice B: Disband Army
		btn_resolve_3.text = "Disband Warband"
		btn_resolve_3.tooltip_text = "COST: 1 Hall Action\nSACRIFICE: 1 Military Unit (Returns to populace)\nEFFECT: Significantly reduces Food demand."
		
		btn_resolve_3.disabled = not has_action or SettlementManager.current_settlement.warbands.is_empty()
		btn_resolve_3.pressed.connect(func():
			if DynastyManager.resolve_crisis_with_sacrifice("disband_warband"):
				winter_start_acknowledged = true
				_close_overlay()
		)
		
	elif wood_def > 0:
		# Choice A: Burn Ships
		btn_resolve_2.text = "Burn the Longships"
		btn_resolve_2.tooltip_text = "COST: 1 Hall Action\nSACRIFICE: Fleet Readiness (Sets to 0%)\nEFFECT: Provides emergency firewood for the season."
		
		btn_resolve_2.disabled = not has_action
		btn_resolve_2.pressed.connect(func():
			if DynastyManager.resolve_crisis_with_sacrifice("burn_ships"):
				winter_start_acknowledged = true
				_close_overlay()
		)
		
		btn_resolve_3.hide()
	
	dispute_overlay.show()

func _display_dispute(card: DisputeEventData) -> void:
	_disconnect_overlay_buttons()
	current_dispute = card
	
	dispute_title.text = card.title
	dispute_desc.text = card.description
	
	btn_resolve_1.show()
	btn_resolve_2.show()
	btn_resolve_3.show()
	
	# Configure Wergild
	btn_resolve_1.text = "Pay Wergild (%d G)" % card.gold_cost
	var can_afford_gold = SettlementManager.current_settlement.treasury.get("gold", 0) >= card.gold_cost
	btn_resolve_1.disabled = not can_afford_gold
	btn_resolve_1.pressed.connect(_on_dispute_pay_gold)
	
	# Configure Force
	if card.bans_unit:
		btn_resolve_2.text = "Banish Unit"
		btn_resolve_2.disabled = SettlementManager.current_settlement.warbands.is_empty()
	else:
		btn_resolve_2.text = "Force (%d Renown)" % card.renown_cost
		btn_resolve_2.disabled = DynastyManager.current_jarl.renown < card.renown_cost
	btn_resolve_2.pressed.connect(_on_dispute_pay_force)
	
	# Configure Ignore
	btn_resolve_3.text = "Ignore"
	btn_resolve_3.pressed.connect(_on_dispute_ignore)
	
	dispute_overlay.show()

func _close_overlay() -> void:
	dispute_overlay.hide()
	_update_ui()

# --- DISPUTE HANDLERS ---
func _on_dispute_pay_gold() -> void:
	if SettlementManager.attempt_purchase({"gold": current_dispute.gold_cost}):
		Loggie.msg("Dispute settled via Wergild.").domain("UI").info()
		_close_overlay()

func _on_dispute_pay_force() -> void:
	if current_dispute.bans_unit:
		var s = SettlementManager.current_settlement
		if not s.warbands.is_empty():
			var v = s.warbands.pick_random()
			s.warbands.erase(v)
			Loggie.msg("Unit banished: %s" % v.custom_name).domain("UI").warn()
			_close_overlay()
	else:
		if DynastyManager.spend_renown(current_dispute.renown_cost):
			_close_overlay()

func _on_dispute_ignore() -> void:
	DynastyManager.apply_year_modifier(current_dispute.penalty_modifier_key)
	_close_overlay()

# --- STANDARD ACTIONS ---
func _on_refit_clicked() -> void:
	if SettlementManager.attempt_purchase({"wood": 50}):
		if DynastyManager.perform_hall_action(1):
			SettlementManager.current_settlement.fleet_readiness = 1.0
			_update_ui()

func _on_feast_clicked() -> void:
	var settlement = SettlementManager.current_settlement
	var food_cost = max(100, settlement.warbands.size() * 50)
	
	# 1. Attempt Purchase
	if SettlementManager.attempt_purchase({"food": food_cost}):
		# 2. Spend Action
		if DynastyManager.perform_hall_action(1):
			# 3. Apply Effects
			for wb in settlement.warbands:
				wb.loyalty = 100
				wb.add_history("Feasted at Yule (Year %d)" % DynastyManager.current_jarl.age)
			
			DynastyManager.award_renown(50)
			
			Loggie.msg("Yule Feast held! Loyalty restored.").domain(LogDomains.UI).info()
			
			# 4. Show Result Popup
			var flavor = "The mead flows freely, and the bards sing tales of your ancestors. The warriors clash mugs and swear oaths of loyalty to your name."
			var result = "[color=green]+50 Renown\nWarband Loyalty Restored[/color]"
			_display_action_result("The Yule Feast", flavor, result)
			
			_update_ui()

func _on_thing_clicked() -> void:
	if DynastyManager.perform_hall_action(1):
		var card = DynastyManager.draw_dispute_card()
		_display_dispute(card)

func _on_end_winter_pressed() -> void:
	DynastyManager.end_winter_phase()

func _display_action_result(title: String, flavor_text: String, result_text: String) -> void:
	_disconnect_overlay_buttons()
	
	dispute_title.text = title
	
	var full_text = "%s\n\n[b]RESULT:[/b]\n%s" % [flavor_text, result_text]
	dispute_desc.text = full_text
	
	# Configure single "Continue" button
	btn_resolve_1.show()
	btn_resolve_1.text = "Skål!"
	btn_resolve_1.disabled = false
	btn_resolve_1.pressed.connect(_close_overlay)
	
	# Hide others
	btn_resolve_2.hide()
	btn_resolve_3.hide()
	
	dispute_overlay.show()

func _on_blot_clicked() -> void:
	# 1. Validation (Cost: 50 Food + 1 Action)
	var food_cost = 50
	var settlement = SettlementManager.current_settlement
	
	if not DynastyManager.current_jarl.current_hall_actions > 0:
		Loggie.msg("Not enough Hall Actions.").domain(LogDomains.UI).warn()
		return
		
	if not SettlementManager.attempt_purchase({"food": food_cost}):
		Loggie.msg("Not enough Food for the sacrifice (Need 50).").domain(LogDomains.UI).warn()
		return

	# 2. Open Selection Window
	_display_blot_options()

func _display_blot_options() -> void:
	_disconnect_overlay_buttons()
	
	dispute_title.text = "The Great Blót"
	dispute_desc.text = "The altars are prepared. To which god shall we offer this sacrifice?\n\n[i](Cost paid: 50 Food, 1 Hall Action)[/i]"
	
	btn_resolve_1.show()
	btn_resolve_2.show()
	btn_resolve_3.show()
	
	# --- OPTION 1: ODIN (XP) ---
	btn_resolve_1.text = "Odin (Wisdom)"
	btn_resolve_1.tooltip_text = "EFFECT: All units gain +50% Experience from battles next year.\n\n\"The Allfather demands we learn from every strike.\""
	btn_resolve_1.disabled = false
	btn_resolve_1.pressed.connect(func():
		_commit_blot("BLOT_ODIN", "Odin")
	)
	
	# --- OPTION 2: THOR (Strength) ---
	btn_resolve_2.text = "Thor (Might)"
	btn_resolve_2.tooltip_text = "EFFECT: +10% Attack Damage for all units next year.\n\n\"Let Mjolnir guide our blows!\""
	btn_resolve_2.disabled = false
	btn_resolve_2.pressed.connect(func():
		_commit_blot("BLOT_THOR", "Thor")
	)
	
	# --- OPTION 3: FREYR (Fertility) ---
	btn_resolve_3.text = "Freyr (Prosperity)"
	btn_resolve_3.tooltip_text = "EFFECT: Greatly increased chance of obtaining an Heir.\n\n\"May the lineage remain strong.\""
	btn_resolve_3.disabled = false
	btn_resolve_3.pressed.connect(func():
		_commit_blot("BLOT_FREYR", "Freyr")
	)
	
	dispute_overlay.show()

func _commit_blot(modifier_key: String, god_name: String) -> void:
	# 1. Pay Action (Food already paid to enter menu, but we finalize action here)
	if DynastyManager.perform_hall_action(1):
		
		# 2. Apply Effect
		DynastyManager.apply_year_modifier(modifier_key)
		
		# 3. Flavor Text
		var flavor = ""
		var result = ""
		
		match god_name:
			"Odin":
				flavor = "The ravens Huginn and Muninn are seen circling the longhouse. The Allfather is pleased."
				result = "[color=cyan]Modifier Active: Raven's Wisdom (+XP)[/color]"
			"Thor":
				flavor = "Thunder rolls across the clear winter sky. Thor grants us his strength."
				result = "[color=red]Modifier Active: Thunder's Wrath (+Damage)[/color]"
			"Freyr":
				flavor = "A golden boar is spotted in the forest. It is a sign of great vitality."
				result = "[color=green]Modifier Active: Freyr's Blessing (+Heir Chance)[/color]"
		
		_display_action_result("Sacrifice Accepted", flavor, result)
		_update_ui()
