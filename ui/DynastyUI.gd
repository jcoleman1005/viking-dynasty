# res://ui/DynastyUI.gd
#
# Manages the "Dynasty" UI panel, which allows the player
# to spend heirs as a resource for the "Progenitor" pillar.
class_name DynastyUI
extends PanelContainer

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var heirs_container: VBoxContainer = $Margin/VBox/HeirsContainer
@onready var close_button: Button = $Margin/VBox/CloseButton

# Expedition cost from proposal 
const EXPEDITION_GOLD_COST = 500

func _ready() -> void:
	close_button.pressed.connect(hide)
	
	# Connect to the DynastyManager to refresh when Jarl data changes
	DynastyManager.jarl_stats_updated.connect(_on_jarl_stats_updated)
	
	# Initial population
	if DynastyManager.current_jarl:
		_on_jarl_stats_updated(DynastyManager.get_current_jarl())
	
	hide() # Start hidden by default

func _on_jarl_stats_updated(jarl: JarlData) -> void:
	"""Refreshes all UI elements with the latest Jarl data."""
	if not jarl:
		return
		
	title_label.text = "%s's Dynasty" % jarl.display_name
	
	# Clear existing heirs
	for child in heirs_container.get_children():
		child.queue_free()
		
	# Populate heirs list
	if jarl.heirs.is_empty():
		var label = Label.new()
		label.text = "No valid heirs."
		heirs_container.add_child(label)
		return

	# Check current gold for button disabling
	var current_gold = 0
	if SettlementManager.current_settlement:
		current_gold = SettlementManager.current_settlement.treasury.get("gold", 0)

	for heir in jarl.heirs:
		if not heir: continue
		
		var heir_row = HBoxContainer.new()
		heir_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = "• %s (%d)" % [heir.display_name, heir.age]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heir_row.add_child(name_label)

		match heir.status:
			JarlHeirData.HeirStatus.Available:
				var expedition_button = Button.new()
				expedition_button.text = "Send on Expedition"
				expedition_button.tooltip_text = "Cost: 1 Heir, %d Gold" % EXPEDITION_GOLD_COST
				
				if current_gold < EXPEDITION_GOLD_COST:
					expedition_button.disabled = true
					expedition_button.tooltip_text += "\n(Not enough Gold)"
				
				expedition_button.pressed.connect(_on_expedition_pressed.bind(heir))
				heir_row.add_child(expedition_button)
				
				# TODO: Add "Marry for Alliance" button here
			
			JarlHeirData.HeirStatus.OnExpedition:
				var status_label = Label.new()
				status_label.text = "On Expedition (%d years)" % heir.expedition_years_remaining
				status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				heir_row.add_child(status_label)
				
			JarlHeirData.HeirStatus.MarriedOff:
				var status_label = Label.new()
				status_label.text = "Married Away"
				status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				heir_row.add_child(status_label)
			
			_:
				var status_label = Label.new()
				status_label.text = "Unavailable"
				status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				heir_row.add_child(status_label)

		heirs_container.add_child(heir_row)


func _on_expedition_pressed(heir: JarlHeirData) -> void:
	"""Called when an 'Send on Expedition' button is pressed."""
	
	var cost = {"gold": EXPEDITION_GOLD_COST}
	
	# 1. Attempt to spend the gold
	if SettlementManager.attempt_purchase(cost):
		# 2. If gold spend is successful, spend the heir
		print("DynastyUI: Spent %d gold. Sending heir %s on expedition." % [EXPEDITION_GOLD_COST, heir.display_name])
		DynastyManager.start_heir_expedition(heir)
		
		# UI will refresh automatically via the jarl_stats_updated signal
	else:
		# This shouldn't happen if the button is disabled, but as a fallback.
		print("DynastyUI: Expedition failed. Not enough gold.")
		EventBus.purchase_failed.emit("Not enough Gold")
