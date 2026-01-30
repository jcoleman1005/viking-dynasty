extends Node
class_name SpringUIDiagnostic

## A passive observer for the SpringCouncil_UI.
## specialized to handle dynamic card spawning and seasonal logic validation.

@export var target_ui: SpringCouncil_UI
@export var audit_interval: float = 1.0

var _timer: float = 0.0

func _ready() -> void:
	# Wait for parent setup
	await get_tree().process_frame
	
	if not target_ui:
		printerr("[DIAGNOSTIC CRITICAL] No Target UI assigned to SpringUIDiagnostic!")
		return

	Loggie.msg("--- STARTING SPRING UI DIAGNOSTICS ---").domain(LogDomains.UI).info()
	
	_validate_configuration()
	_hook_global_signals()
	_hook_container()
	_check_initial_state()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= audit_interval:
		_timer = 0.0
		_run_periodic_audit()

# --- 1. Startup Validation ---

func _validate_configuration() -> void:
	# Check References
	if not target_ui.card_container:
		_log_error("card_container is NOT assigned.")
	elif not target_ui.card_container.is_inside_tree():
		_log_error("card_container is assigned but not in Scene Tree.")
		
	if not target_ui.card_prefab:
		_log_error("card_prefab is missing.")
		
	# Check Data
	if target_ui.available_advisor_cards.is_empty():
		_log_warn("Deck Configuration is empty! No cards available to deal.")

func _check_initial_state() -> void:
	if not target_ui.visible and DynastyManager.current_season == DynastyManager.Season.SPRING:
		_log_warn("Logic Mismatch: Season IS Spring, but UI is Hidden.")

# --- 2. Dynamic Hooking (The Card Spy) ---

func _hook_container() -> void:
	if target_ui.card_container:
		# Watch for cards being added dynamically
		target_ui.card_container.child_entered_tree.connect(_on_card_spawned)

func _on_card_spawned(node: Node) -> void:
	# Verify it's a card and hook its input signal
	if node is SeasonalCard_UI:
		_log_info("Card Spawned: %s" % node.name)
		
		# Hook the signal to spy on clicks
		if node.has_signal("card_clicked"):
			node.card_clicked.connect(func(card): _log_input("Card Selected: %s (Gold: %d, Renown: %d)" % [
				card.display_name if "display_name" in card else "Unknown",
				card.grant_gold if "grant_gold" in card else 0,
				card.grant_renown if "grant_renown" in card else 0
			]))
		else:
			_log_error("Spawned object %s is missing 'card_clicked' signal!" % node.name)
	else:
		_log_warn("Non-Card object added to Container: %s" % node.name)

# --- 3. Global Flow Spying ---

func _hook_global_signals() -> void:
	# Monitor Season Changes
	EventBus.season_changed.connect(func(s): _log_info("Season Changed Signal Received: %s" % s))
	
	# Monitor the Output Signal
	EventBus.advance_season_requested.connect(func(): _log_info(">> OUTPUT: Advance Season Requested (Commit Successful)"))

# --- 4. Periodic Audit ---

func _run_periodic_audit() -> void:
	if not target_ui.visible: return

	# Validate Season Consistency
	if DynastyManager.current_season != DynastyManager.Season.SPRING:
		_log_error("CRITICAL: Spring UI is Visible, but Season is %s" % str(DynastyManager.current_season))

	# Validate Container State
	var child_count = target_ui.card_container.get_child_count()
	if child_count == 0 and target_ui._has_activated:
		# If we activated but have no cards, something failed in _deal_cards
		_log_error("UI Active but Card Container is Empty.")
		_debug_deck_failure() # TRIGGER DEEP DEBUG

func _debug_deck_failure() -> void:
	print_rich("[color=orange]--- [SPRING DEBUG] DECK ANALYSIS ---[/color]")
	
	# 1. Check Hand Size
	if target_ui.hand_size <= 0:
		print_rich("[color=red]FAIL: 'hand_size' is %d. No cards will ever spawn.[/color]" % target_ui.hand_size)
		return

	# 2. Check Prefab Instantiation
	if target_ui.card_prefab:
		var test_inst = target_ui.card_prefab.instantiate()
		if not test_inst:
			print_rich("[color=red]FAIL: 'card_prefab' failed to instantiate (Returned Null). Check the Scene file.[/color]")
		elif not (test_inst is SeasonalCard_UI):
			print_rich("[color=red]FAIL: 'card_prefab' root node is type '%s', expected 'SeasonalCard_UI'.[/color]" % test_inst.get_class())
		else:
			print_rich("[color=green]PASS: Prefab instantiates correctly.[/color]")
		test_inst.queue_free()
	
	# 3. Check Enum Matching & Stale Data
	var expected_enum = SeasonalCardResource.SeasonType.SPRING
	print_rich("[color=cyan]INFO: Target Season Enum is: %d (SPRING)[/color]" % expected_enum)
	print("Array Size: %d" % target_ui.available_advisor_cards.size())
	
	var valid_cards = 0
	for i in range(target_ui.available_advisor_cards.size()):
		var card = target_ui.available_advisor_cards[i]
		
		# Check for Null
		if not card:
			print_rich("[color=red]Slot %d: NULL RESOURCE[/color]" % i)
			continue
			
		# Check for Stale/Built-in Resources
		var is_external = card.resource_path != "" and not "::" in card.resource_path
		if not is_external:
			print_rich("[color=yellow]Slot %d WARN: Resource is internal/built-in. Inspector changes to file won't update this![/color]" % i)
			
		var card_season = card.season
		if card_season == expected_enum:
			valid_cards += 1
			print("Slot %d: MATCH (Int %d) - %s" % [i, card_season, card.resource_path.get_file()])
		else:
			# PRINT THE MISMATCHED VALUE
			print_rich("[color=pink]Slot %d: MISMATCH (Card has Int %d, Expected %d) - %s[/color]" % [i, card_season, expected_enum, card.resource_path.get_file()])

	if valid_cards == 0:
		print_rich("[color=red]FAIL: 0 cards matched. See Mismatches above.[/color]")
		print_rich("[color=yellow]TIP: If you see 'MISMATCH', the card property is wrong. If you see 'Resource is internal', clear the array in the Inspector and drag the files in again.[/color]")
	else:
		print_rich("[color=yellow]WARN: %d cards matched. If Prefab is OK, check for immediate queue_free() in 'setup()'.[/color]" % valid_cards)

# --- Helpers ---

func _log_info(msg: String) -> void:
	print_rich("[color=cyan][SPRING DIAG] %s[/color]" % msg)

func _log_warn(msg: String) -> void:
	print_rich("[color=yellow][SPRING WARN] %s[/color]" % msg)
	Loggie.msg(msg).domain(LogDomains.UI).warn()

func _log_error(msg: String) -> void:
	print_rich("[color=red][SPRING FAIL] %s[/color]" % msg)
	Loggie.msg(msg).domain(LogDomains.UI).error()

func _log_input(msg: String) -> void:
	print_rich("[color=green][SPRING INPUT] %s[/color]" % msg)
