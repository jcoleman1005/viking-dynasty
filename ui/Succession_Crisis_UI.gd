#res://ui/Succession_Crisis_UI.gd
# res://ui/Succession_Crisis_UI.gd
extends CanvasLayer

# --- Node Refs ---
@onready var panel_container: PanelContainer = $PanelContainer # Added for centering logic
@onready var desc_label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var legit_label = $PanelContainer/MarginContainer/VBoxContainer/LegitimacyLabel
@onready var renown_desc = $PanelContainer/MarginContainer/VBoxContainer/RenownTaxDescription
@onready var gold_desc = $PanelContainer/MarginContainer/VBoxContainer/GoldTaxDescription
@onready var pay_renown_btn = $PanelContainer/MarginContainer/VBoxContainer/RenownTaxButtons/PayRenownButton
@onready var refuse_renown_btn = $PanelContainer/MarginContainer/VBoxContainer/RenownTaxButtons/RefuseRenownButton
@onready var pay_gold_btn = $PanelContainer/MarginContainer/VBoxContainer/GoldTaxButtons/PayGoldButton
@onready var refuse_gold_btn = $PanelContainer/MarginContainer/VBoxContainer/GoldTaxButtons/RefuseGoldButton
@onready var confirm_btn = $PanelContainer/MarginContainer/VBoxContainer/ConfirmButton

# --- State ---
var renown_tax: int = 0
var gold_tax: int = 0
var renown_choice: String = "pay"
var gold_choice: String = "pay"

func _ready() -> void:
	# --- NEW: Pause and Center Logic ---
	# 1. Ensure this UI continues running while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. Pause the Game
	get_tree().paused = true
	Loggie.msg("Succession Crisis Started. Game Paused.").domain("UI").info()
	
	# 3. Force Centering
	if panel_container:
		panel_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# -----------------------------------

	# Create ButtonGroups
	var renown_group = ButtonGroup.new()
	pay_renown_btn.button_group = renown_group
	refuse_renown_btn.button_group = renown_group
	
	var gold_group = ButtonGroup.new()
	pay_gold_btn.button_group = gold_group
	refuse_gold_btn.button_group = gold_group
	
	pay_renown_btn.pressed.connect(_on_renown_choice.bind("pay"))
	refuse_renown_btn.pressed.connect(_on_renown_choice.bind("refuse"))
	pay_gold_btn.pressed.connect(_on_gold_choice.bind("pay"))
	refuse_gold_btn.pressed.connect(_on_gold_choice.bind("refuse"))
	confirm_btn.pressed.connect(_on_confirm)

func display_crisis(jarl: JarlData, settlement: SettlementData) -> void:
	var legitimacy = jarl.legitimacy
	legit_label.text = "New Legitimacy: %d/100" % legitimacy
	
	# --- Calculate Taxes (Higher legitimacy = lower taxes) ---
	var tax_multiplier = 1.0 - (legitimacy / 100.0) # 100 legit = 0x, 20 legit = 0.8x
	
	# Renown Tax
	renown_tax = int(max(50, DynastyManager.get_current_jarl().renown * 0.2) * tax_multiplier)
	pay_renown_btn.text = "Pay %d Renown" % renown_tax
	refuse_renown_btn.text = "Refuse (Risk Project Setbacks)"
	
	renown_desc.text = "Pay %d Renown to protect your legacy, or refuse and risk setbacks." % renown_tax

	# Gold Tax
	gold_tax = int(max(200, settlement.treasury.get("gold", 0) * 0.3) * tax_multiplier)
	pay_gold_btn.text = "Pay %d Gold" % gold_tax
	refuse_gold_btn.text = "Refuse (Risk Instability)"
	
	gold_desc.text = "Pay %d Gold to ensure loyalty, or refuse and risk instability." % gold_tax

	# Check affordability
	if jarl.renown < renown_tax:
		pay_renown_btn.disabled = true
		refuse_renown_btn.button_pressed = true
		renown_choice = "refuse"
	else:
		pay_renown_btn.button_pressed = true
		renown_choice = "pay"
	
	if settlement.treasury.get("gold", 0) < gold_tax:
		pay_gold_btn.disabled = true
		refuse_gold_btn.button_pressed = true
		gold_choice = "refuse"
	else:
		pay_gold_btn.button_pressed = true
		gold_choice = "pay"
	
	show()

func _on_renown_choice(choice: String) -> void:
	renown_choice = choice

func _on_gold_choice(choice: String) -> void:
	gold_choice = choice

func _on_confirm() -> void:
	# 1. Apply costs
	if renown_choice == "pay":
		DynastyManager.spend_renown(renown_tax)
	if gold_choice == "pay":
		SettlementManager.attempt_purchase({"gold": gold_tax})
	
	# 2. Emit choices to EventManager/DynastyManager for consequences
	EventBus.succession_choices_made.emit(renown_choice, gold_choice)
	
	# --- NEW: Unpause Game ---
	get_tree().paused = false
	# -------------------------
	
	# 3. Close the window
	queue_free()
