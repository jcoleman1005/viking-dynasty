# res://autoload/DynastyManager.gd
#
# A global Singleton (Autoload) that acts as a pure data manager
# for the player's Jarl and dynasty state.
# This is the "Core Pacing Engine" as defined in the GDD.
# It is the single source of truth for all Jarl data.
extends Node

## Emitted when Jarl data changes (e.g., spent Authority, ended year)
signal jarl_stats_updated(jarl_data: JarlData)
signal year_ended

var current_jarl: JarlData
var current_raid_target: SettlementData

var is_defensive_raid: bool = false

# --- NEW: Succession System ---
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []
# --- END NEW ---

# Path to the player's persistent Jarl data
const PLAYER_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_player_jarl()
	_load_legacy_upgrades_from_disk() # <-- THIS IS THE FIX
	EventBus.succession_choices_made.connect(_on_succession_choices_made) # Connect to UI

# --- THIS IS THE NEW FUNCTION ---
func _load_legacy_upgrades_from_disk() -> void:
	"""
	Scans res://data/legacy/ for .tres files and loads them.
	This manager is now the single source of truth for this data.
	"""
	loaded_legacy_upgrades.clear()
	
	var dir = DirAccess.open("res://data/legacy/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path = "res://data/legacy/" + file_name
				var upgrade_data = load(path) as LegacyUpgradeData
				
				if upgrade_data:
					# We create a local instance/duplicate of the resource.
					# This prevents cost changes from modifying the .tres file.
					var unique_upgrade = upgrade_data.duplicate()
					
					# Check if already purchased
					if has_purchased_upgrade(unique_upgrade.effect_key):
						# This logic needs to be based on progress, not just key
						# We will need to load progress from JarlData in the future.
						# For now, this is fine, but we need to load progress *from* jarl data.
						pass
					
					loaded_legacy_upgrades.append(unique_upgrade)
					
			file_name = dir.get_next()
	print("DynastyManager: Loaded %d legacy upgrades." % loaded_legacy_upgrades.size())
# --- END NEW FUNCTION ---

func _load_player_jarl() -> void:
	if ResourceLoader.exists(PLAYER_JARL_PATH):
		current_jarl = load(PLAYER_JARL_PATH)
		print("DynastyManager: PlayerJarl.tres loaded successfully.")
	else:
		# Use push_error for missing persistent files
		push_error("DynastyManager: Failed to load Jarl data from %s. File not found!" % PLAYER_JARL_PATH)
		# Create a fallback in-memory Jarl to prevent crashes
		current_jarl = JarlData.new()
		current_jarl.display_name = "Fallback Jarl"
		current_jarl.current_authority = 3
		current_jarl.max_authority = 3
		
	# Emit initial stats
	jarl_stats_updated.emit(current_jarl)

func get_current_jarl() -> JarlData:
	if not current_jarl:
		_load_player_jarl()
	return current_jarl

func can_spend_authority(cost: int) -> bool:
	if not current_jarl:
		return false
	return current_jarl.can_take_action(cost)

func spend_authority(cost: int) -> bool:
	if not current_jarl:
		return false
		
	if current_jarl.spend_authority(cost):
		_save_jarl_data()
		jarl_stats_updated.emit(current_jarl)
		# REMOVED: print("DynastyManager: Spent %d authority. %d remaining." % [cost, current_jarl.current_authority])
		return true
	
	# RETAINED: Failure is important
	print("DynastyManager: Failed to spend %d authority. %d remaining." % [cost, current_jarl.current_authority])
	return false

func can_spend_renown(cost: int) -> bool:
	"""Check if the Jarl has enough Renown."""
	if not current_jarl:
		return false
	return current_jarl.renown >= cost

func spend_renown(cost: int) -> bool:
	"""Spend the Jarl's Renown."""
	if not can_spend_renown(cost):
		# RETAINED: Failure is important
		print("DynastyManager: Failed to spend %d renown. %d available." % [cost, current_jarl.renown])
		return false
	
	current_jarl.renown -= cost
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	# REMOVED: print("DynastyManager: Spent %d renown. %d remaining." % [cost, current_jarl.renown])
	return true

func purchase_legacy_upgrade(upgrade_key: String) -> void:
	"""Mark a legacy upgrade as purchased on the Jarl's data."""
	if not current_jarl:
		return
	if not upgrade_key in current_jarl.purchased_legacy_upgrades:
		current_jarl.purchased_legacy_upgrades.append(upgrade_key)
		_save_jarl_data()
		print("DynastyManager: Legacy upgrade '%s' purchased and saved." % upgrade_key)

func has_purchased_upgrade(upgrade_key: String) -> bool:
	"""Check if a legacy upgrade has already been purchased."""
	if not current_jarl:
		return false
	return upgrade_key in current_jarl.purchased_legacy_upgrades

# --- NEW: Unifier Pillar Functions ---
func add_conquered_region(region_path: String) -> void:
	"""Adds a region's path to the Jarl's list of conquered territories."""
	if not current_jarl:
		return
	if not region_path in current_jarl.conquered_regions:
		current_jarl.conquered_regions.append(region_path)
		_save_jarl_data()
		# RETAINED: This is a major game state change
		print("DynastyManager: Region '%s' conquered and saved." % region_path)
		# We don't emit jarl_stats_updated here because spending authority
		# will have already triggered the UI refresh.

func has_conquered_region(region_path: String) -> bool:
	"""Checks if a region has been conquered."""
	if not current_jarl:
		return false
	return region_path in current_jarl.conquered_regions

# --- NEW: Progenitor Pillar Functions ---

func get_available_heir_count() -> int:
	if not current_jarl:
		return 0
	return current_jarl.get_available_heir_count()

func start_heir_expedition(heir: JarlHeirData, expedition_duration: int = 5) -> void:
	"""
	Sends an heir on an expedition.
	This marks them as unavailable and starts a timer.
	"""
	if not current_jarl or not heir in current_jarl.heirs:
		push_error("DynastyManager: Tried to send an invalid heir on expedition.")
		return
	
	heir.status = JarlHeirData.HeirStatus.OnExpedition
	heir.expedition_years_remaining = expedition_duration
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("Heir %s sent on expedition for %d years." % [heir.display_name, expedition_duration])

func process_heir_expeditions() -> Array[String]:
	"""
	Called at the End of Year.
	Processes all heirs on expedition, returning results.
	"""
	if not current_jarl:
		return []

	var results: Array[String] = []
	var heirs_to_remove: Array[JarlHeirData] = []
	
	for heir in current_jarl.heirs:
		if heir.status == JarlHeirData.HeirStatus.OnExpedition:
			heir.expedition_years_remaining -= 1
			
			if heir.expedition_years_remaining <= 0:
				# Expedition is over, run probability check
				var roll = randf()
				if roll <= 0.7: # 70% success 
					var renown_gain = randi_range(100, 300)
					award_renown(renown_gain)
					results.append("Heir %s returned from their expedition with %d Renown!" % [heir.display_name, renown_gain])
					heir.status = JarlHeirData.HeirStatus.Available
					
					# --- NEW: Add Trait to Heir ---
					var seasoned_trait = load("res://data/traits/Trait_Seasoned.tres") # Load the trait we created
					if seasoned_trait:
						heir.traits.append(seasoned_trait)
					# --- END NEW ---
					
					# --- NEW: Add Legitimacy Boost ---
					current_jarl.legitimacy = min(100, current_jarl.legitimacy + 5) # +5 Legitimacy for successful expedition
					# --- END NEW ---
				else: # 30% failure 
					results.append("Tragic news!
Heir %s was lost at sea during their expedition." % heir.display_name)
					heir.status = JarlHeirData.HeirStatus.LostAtSea
					heirs_to_remove.append(heir) # Queue for removal
	
	# Remove lost heirs
	for heir in heirs_to_remove:
		current_jarl.remove_heir(heir)

	if not results.is_empty():
		_save_jarl_data()
		jarl_stats_updated.emit(current_jarl)
		
	return results

# --- NEW: Marry for Alliance ---
func marry_heir_for_alliance(region_path: String) -> bool:
	"""
	Spends the first available heir to form an alliance with a region.
	Returns true on success, false if no heir is available.
	"""
	if not current_jarl:
		return false
		
	var heir_to_marry = current_jarl.get_first_available_heir()
	if not heir_to_marry:
		print("DynastyManager: Marriage failed. No available heir.")
		return false
	
	# "Spend" the heir
	heir_to_marry.status = JarlHeirData.HeirStatus.MarriedOff
	
	# Add the alliance
	if not region_path in current_jarl.allied_regions:
		current_jarl.allied_regions.append(region_path)
	
	# --- NEW: Add Legitimacy Boost ---
	current_jarl.legitimacy = min(100, current_jarl.legitimacy + 10) # +10 Legitimacy
	# --- END NEW ---

	print("Heir %s married off to form alliance with %s" % [heir_to_marry.display_name, region_path])
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func is_allied_region(region_path: String) -> bool:
	"""Checks if a region is allied."""
	if not current_jarl:
		return false
	return region_path in current_jarl.allied_regions
# --- END NEW ---
func add_trait_to_heir(heir: JarlHeirData, trait_data: JarlTraitData) -> void:
	"""
	Placeholder function to add a trait to an heir.
	Currently, JarlHeirData does not store traits.
	This function will just log for now.
	"""
	# Using push_warning to flag this missing feature for development
	push_warning("EVENT: (TODO) Would add trait '%s' to heir '%s'." % [trait_data.display_name, heir.display_name])


func end_year() -> void:
	if not current_jarl:
		push_error("DynastyManager: Cannot end year, current Jarl is null.")
		return
	
	# --- MODIFIED: Death check happens *before* reset ---
	var jarl_died = _check_for_jarl_death()
	if jarl_died:
		# Succession crisis is triggered, which will emit 'event_system_finished'
		# when it's done. We stop 'end_year' here.
		return
	# --- END MODIFIED ---
	
	# Jarl did not die, proceed as normal
	current_jarl.reset_authority() # This now contains the debuff logic
	
	var expedition_results = process_heir_expeditions()
	if not expedition_results.is_empty():
		print("Expedition Results: %s" % expedition_results)
		# TODO: We will need a way to show these results to the player,
		# likely by modifying the EndOfYear_Popup.
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("DynastyManager: Year ended. Authority reset to %d." % current_jarl.max_authority)
	
	# Emit the signal so the EventManager can hear it.
	year_ended.emit()
	
func set_current_raid_target(data: SettlementData) -> void:
	current_raid_target = data
	# REMOVED: print("DynastyManager: Raid target set to %s" % data.resource_path)

func get_current_raid_target() -> SettlementData:
	var target = current_raid_target
	current_raid_target = null # Clear the target after getting it
	return target

func _save_jarl_data() -> void:
	if not current_jarl:
		push_error("DynastyManager: Cannot save, current_jarl is null.")
		return
		
	if current_jarl.resource_path.is_empty():
		current_jarl.resource_path = PLAYER_JARL_PATH
		
	var error = ResourceSaver.save(current_jarl, current_jarl.resource_path)
	if error != OK:
		# Using push_error to alert to critical save file failures
		push_error("DynastyManager: Failed to save Jarl data to %s. Error: %s" % [current_jarl.resource_path, error])
	# No success print needed for every save, keeps log clean

func award_renown(amount: int) -> void:
	if not current_jarl:
		push_error("DynastyManager: Cannot award renown, current Jarl is null.")
		return
	
	current_jarl.award_renown(amount)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("DynastyManager: Awarded %d renown.
Total: %d" % [amount, current_jarl.renown])

# --- NEW: Succession System Functions ---
func debug_kill_jarl() -> void:
	"""
	Public-facing debug function to immediately trigger succession.
	Bypasses all age and 'end_year' checks.
	"""
	print("DEBUG: debug_kill_jarl() called. Forcing succession...")
	_trigger_succession()


func _check_for_jarl_death() -> bool:
	"""Rolls for Jarl's death.
Returns true if Jarl died."""
	var jarl = get_current_jarl()
	var death_chance = 0.0
	
	if jarl.age > 80:
		death_chance = 0.5
	elif jarl.age > 65:
		death_chance = 0.25
	elif jarl.age > 50:
		death_chance = 0.1
	
	if randf() < death_chance:
		print("The Jarl has died at age %d!" % jarl.age)
		_trigger_succession()
		return true
	
	return false

func _trigger_succession() -> void:
	"""Manages the promotion of an heir and triggers the crisis event."""
	var old_jarl = current_jarl
	var heir = current_jarl.get_first_available_heir()
	
	if not heir:
		print("GAME OVER: The Jarl died with no available heir!")
		# TODO: Add game over logic
		get_tree().quit() # Placeholder
		return
	
	# Promote heir to Jarl
	var new_jarl = _promote_heir_to_jarl(heir, old_jarl)
	current_jarl.heirs.erase(heir) # Remove heir from list
	current_jarl = new_jarl
	
	# Trigger the event
	var succession_event_data = EventData.new() # Create a dummy event
	succession_event_data.event_id = "succession_crisis"
	EventManager._trigger_event(succession_event_data)

func _promote_heir_to_jarl(heir: JarlHeirData, predecessor: JarlData) -> JarlData:
	"""Creates a new JarlData resource from an heir."""
	var new_jarl = JarlData.new()
	new_jarl.display_name = heir.display_name
	new_jarl.age = heir.age
	new_jarl.command = heir.command
	new_jarl.stewardship = heir.stewardship
	new_jarl.learning = heir.learning
	new_jarl.prowess = heir.prowess
	new_jarl.traits = heir.traits
	
	# Calculate Legitimacy
	var new_legit = int(predecessor.legitimacy * 0.8) # Inherit 80%
	
	# Apply trait/skill penalties
	var penalty = (10 - new_jarl.get_effective_skill("stewardship")) * 2 # Example
	penalty += (10 - new_jarl.get_effective_skill("prowess")) # Example
	
	new_legit = max(0, new_legit - penalty)
	
	# Apply floor from Jelling Stone 
	new_legit = max(new_legit, minimum_inherited_legitimacy) 
	
	new_jarl.legitimacy = new_legit
	new_jarl.succession_debuff_years_remaining = 3 # Start the 3-year debuff
	
	return new_jarl

func _on_succession_choices_made(renown_choice: String, gold_choice: String) -> void:
	"""Applies the consequences of the succession crisis choices."""
	if renown_choice == "refuse":
		# Apply Renown Tax Consequence
		var setback_applied = false
		
		# --- THIS IS THE FIX ---
		# We iterate over our own 'loaded_legacy_upgrades' array,
		# not one from another scene.
		for upgrade in loaded_legacy_upgrades:
		# --- END FIX ---
			if not upgrade.is_purchased and upgrade.current_progress > 0:
				upgrade.current_progress = max(0, upgrade.current_progress - 2) # -2 Progress
				setback_applied = true
				break
		if setback_applied:
			print("A legacy project has lost progress!")
	
	if gold_choice == "refuse":
		# Apply Gold Tax Consequence 
		if SettlementManager.current_settlement:
			SettlementManager.current_settlement.has_stability_debuff = true
			print("Settlement instability debuff applied!")
	
	# This is the "all-clear" signal
	EventBus.event_system_finished.emit()

# --- END NEW ---
