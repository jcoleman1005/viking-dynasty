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

#Succession System ---
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []

#Raid Context & Results ---
# Stores the difficulty (Tier) of the active raid for reward calculation
var current_raid_difficulty: int = 1 

# Stores the raw outcome from the RTS layer before processing
# Format: { "outcome": "win", "gold_looted": 0, "buildings_destroyed": 0 }
var pending_raid_result: Dictionary = {} 
# -----------------------------------
# Path to the player's persistent Jarl data
const PLAYER_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_player_jarl()
	_load_legacy_upgrades_from_disk()
	EventBus.succession_choices_made.connect(_on_succession_choices_made)

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
						unique_upgrade.current_progress = unique_upgrade.required_progress
					
					loaded_legacy_upgrades.append(unique_upgrade)
					
			file_name = dir.get_next()
	print("DynastyManager: Loaded %d legacy upgrades." % loaded_legacy_upgrades.size())

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

# --- AUTHORITY & RENOWN ---

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
		return true
	
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
		print("DynastyManager: Failed to spend %d renown. %d available." % [cost, current_jarl.renown])
		return false
	
	current_jarl.renown -= cost
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func award_renown(amount: int) -> void:
	if not current_jarl:
		push_error("DynastyManager: Cannot award renown, current Jarl is null.")
		return
	
	current_jarl.award_renown(amount)
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("DynastyManager: Awarded %d renown. Total: %d" % [amount, current_jarl.renown])

# --- LEGACY & UNIFIER ---

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

func add_conquered_region(region_path: String) -> void:
	"""Adds a region's path to the Jarl's list of conquered territories."""
	if not current_jarl:
		return
	if not region_path in current_jarl.conquered_regions:
		current_jarl.conquered_regions.append(region_path)
		_save_jarl_data()
		print("DynastyManager: Region '%s' conquered and saved." % region_path)

func has_conquered_region(region_path: String) -> bool:
	"""Checks if a region has been conquered."""
	if not current_jarl:
		return false
	return region_path in current_jarl.conquered_regions

# --- PROGENITOR PILLAR (HEIRS) ---

func get_available_heir_count() -> int:
	if not current_jarl:
		return 0
	return current_jarl.get_available_heir_count()

func designate_heir(target_heir: JarlHeirData) -> void:
	if not current_jarl or not target_heir:
		return
	
	# 1. Cost Check
	var cost = 1
	if not can_spend_authority(cost):
		print("DynastyManager: Not enough Authority to designate heir.")
		return
		
	spend_authority(cost)
	
	# 2. Clear previous designation
	for heir in current_jarl.heirs:
		heir.is_designated_heir = false
		
	# 3. Set new designation
	target_heir.is_designated_heir = true
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("DynastyManager: %s is now the designated heir." % target_heir.display_name)

func start_heir_expedition(heir: JarlHeirData, expedition_duration: int = 3) -> void:
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
	
	# Add Legitimacy Boost
	current_jarl.legitimacy = min(100, current_jarl.legitimacy + 10) # +10 Legitimacy

	print("Heir %s married off to form alliance with %s" % [heir_to_marry.display_name, region_path])
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	return true

func is_allied_region(region_path: String) -> bool:
	"""Checks if a region is allied."""
	if not current_jarl:
		return false
	return region_path in current_jarl.allied_regions

func add_trait_to_heir(heir: JarlHeirData, trait_data: JarlTraitData) -> void:
	if not heir: return
	heir.traits.append(trait_data)
	print("EVENT: Added trait '%s' to heir '%s'." % [trait_data.display_name, heir.display_name])

# --- END OF YEAR LOGIC LOOP ---

func end_year() -> void:
	if not current_jarl:
		push_error("DynastyManager: Cannot end year, current Jarl is null.")
		return
	
	# 1. Jarl Aging & Death Check
	current_jarl.age_jarl(1)
	
	var jarl_died = _check_for_jarl_death()
	if jarl_died:
		# If Jarl died, the succession event fires. 
		# We STOP here. The Succession UI will handle the rest.
		return
	
	# 2. Reset Authority
	current_jarl.reset_authority()
	
	# 3. Process Heirs (Simulation Loop)
	_process_heir_simulation()
	
	# 4. Save and Update UI
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	
	print("DynastyManager: Year ended. Jarl is now %d." % current_jarl.age)
	year_ended.emit()

func _process_heir_simulation() -> void:
	"""Handles aging, expedition returns, births, and deaths."""
	var heirs_to_remove: Array[JarlHeirData] = []
	
	# A. Process Existing Heirs
	for heir in current_jarl.heirs:
		heir.age += 1
		
		# Expedition Logic
		if heir.status == JarlHeirData.HeirStatus.OnExpedition:
			heir.expedition_years_remaining -= 1
			if heir.expedition_years_remaining <= 0:
				_resolve_expedition(heir)
		
		# Natural Death Check (Simple version)
		# 5% chance to die if over 50
		if heir.age > 50 and randf() < 0.05: 
			print("EVENT: Heir %s died of natural causes." % heir.display_name)
			heirs_to_remove.append(heir)
			
	# Clean up dead heirs
	for dead_heir in heirs_to_remove:
		current_jarl.remove_heir(dead_heir)
		
	# B. Try for a new child (Births)
	_try_birth_event()

func _resolve_expedition(heir: JarlHeirData) -> void:
	# 70% Success Rate
	var roll = randf()
	
	if roll > 0.3:
		# SUCCESS
		heir.status = JarlHeirData.HeirStatus.Available
		var renown_gain = randi_range(100, 300)
		award_renown(renown_gain)
		print("EVENT: Heir %s returned safely with %d Renown!" % [heir.display_name, renown_gain])
		
		# Optional: Load/Add Seasoned trait here
		# var seasoned = load("res://data/traits/Trait_Seasoned.tres")
		# if seasoned: add_trait_to_heir(heir, seasoned)
	else:
		# FAILURE (Death/Lost)
		heir.status = JarlHeirData.HeirStatus.LostAtSea
		print("EVENT: Tragic news! Heir %s was lost at sea." % heir.display_name)

func _try_birth_event() -> void:
	# 1. Hard cap on children to prevent UI overflow
	if current_jarl.heirs.size() >= 6:
		return
		
	# 2. Fertility calculation
	var base_chance = 0.30 # 30% base chance per year
	
	# Age modifier (Lower chance as Jarl gets older)
	if current_jarl.age > 50: base_chance -= 0.20
	if current_jarl.age > 60: base_chance = 0.0
	
	# Roll the dice
	if randf() < base_chance:
		_generate_new_baby()

func _generate_new_baby() -> void:
	var baby = JarlHeirData.new()
	baby.age = 0 # Newborn
	
	# Random Gender
	baby.gender = "Male" if randf() > 0.5 else "Female"
	
	# Random Name (Hardcoded list for MVP)
	var male_names = ["Erik", "Olaf", "Knut", "Sven", "Torstein", "Leif", "Ragnar", "Bjorn"]
	var female_names = ["Astrid", "Freya", "Ingrid", "Sigrid", "Helga", "Ylva", "Lagertha", "Gunnhild"]
	
	if baby.gender == "Male":
		baby.display_name = male_names.pick_random()
	else:
		baby.display_name = female_names.pick_random()
		
	# Genetic Trait Inheritance (20% chance)
	if randf() < 0.2:
		var trait_data = JarlTraitData.new()
		trait_data.display_name = ["Strong", "Genius", "Giant", "Frail"].pick_random()
		baby.genetic_trait = trait_data
	
	# Add to family
	current_jarl.heirs.append(baby)
	print("EVENT: A new child, %s, was born to the Dynasty!" % baby.display_name)

# --- RAID UTILS ---

func set_current_raid_target(data: SettlementData) -> void:
	current_raid_target = data

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
		push_error("DynastyManager: Failed to save Jarl data to %s. Error: %s" % [current_jarl.resource_path, error])

# --- SUCCESSION SYSTEM ---

func debug_kill_jarl() -> void:
	"""Public-facing debug function to immediately trigger succession."""
	print("DEBUG: debug_kill_jarl() called. Forcing succession...")
	_trigger_succession()

func _check_for_jarl_death() -> bool:
	"""Rolls for Jarl's death. Returns true if Jarl died."""
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
	
	# 1. Try to find Designated Heir first
	var heir = null
	for h in current_jarl.heirs:
		if h.is_designated_heir and h.status == JarlHeirData.HeirStatus.Available:
			heir = h
			break
			
	# 2. Fallback to first available
	if not heir:
		heir = current_jarl.get_first_available_heir()
	
	if not heir:
		print("GAME OVER: The Jarl died with no available heir!")
		# TODO: Add game over logic
		return
	
	# Promote heir to Jarl
	var new_jarl = _promote_heir_to_jarl(heir, old_jarl)
	
	# Move old Jarl to ancestors
	var ancestor_entry = {
		"name": old_jarl.display_name,
		"portrait": old_jarl.portrait,
		"final_renown": old_jarl.renown,
		"death_reason": "Died of old age" # Simplify for now
	}
	new_jarl.ancestors.append(ancestor_entry)
	
	# Remove the promoted heir from the heir list
	new_jarl.heirs.erase(heir) 
	
	current_jarl = new_jarl
	
	# Trigger the event
	var succession_event_data = EventData.new() 
	succession_event_data.event_id = "succession_crisis"
	EventManager._trigger_event(succession_event_data)

func _promote_heir_to_jarl(heir: JarlHeirData, predecessor: JarlData) -> JarlData:
	"""Creates a new JarlData resource from an heir."""
	var new_jarl = JarlData.new()
	new_jarl.display_name = heir.display_name
	new_jarl.age = heir.age
	new_jarl.gender = heir.gender
	new_jarl.portrait = heir.portrait
	new_jarl.command = heir.command
	new_jarl.stewardship = heir.stewardship
	new_jarl.learning = heir.learning
	new_jarl.prowess = heir.prowess
	new_jarl.traits = heir.traits
	new_jarl.ancestors = predecessor.ancestors.duplicate() # Carry over ancestors
	new_jarl.heirs = predecessor.heirs.duplicate() # Siblings become heirs (simplified)
	
	# Calculate Legitimacy
	var new_legit = int(predecessor.legitimacy * 0.8) # Inherit 80%
	
	# Bonus if Designated
	if heir.is_designated_heir:
		new_legit += 20
	
	# Apply floor from Jelling Stone 
	new_legit = max(new_legit, minimum_inherited_legitimacy) 
	
	new_jarl.legitimacy = new_legit
	new_jarl.succession_debuff_years_remaining = 3 
	
	return new_jarl

func _on_succession_choices_made(renown_choice: String, gold_choice: String) -> void:
	"""Applies the consequences of the succession crisis choices."""
	if renown_choice == "refuse":
		# Apply Renown Tax Consequence
		var setback_applied = false
		for upgrade in loaded_legacy_upgrades:
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
	
	EventBus.event_system_finished.emit()
