# res://autoload/DynastyManager.gd
#
# A global Singleton (Autoload) that acts as a pure data manager
# for the player's Jarl and dynasty state.
# This is the "Core Pacing Engine" as defined in the GDD.
# It is the single source of truth for all Jarl data.

extends Node

## Emitted when Jarl data changes (e.g., spent Authority, ended year)
signal jarl_stats_updated(jarl_data: JarlData)

var current_jarl: JarlData
var current_raid_target: SettlementData

# Path to the player's persistent Jarl data
const PLAYER_JARL_PATH = "res://data/characters/PlayerJarl.tres"

func _ready() -> void:
	_load_player_jarl()

func _load_player_jarl() -> void:
	if ResourceLoader.exists(PLAYER_JARL_PATH):
		current_jarl = load(PLAYER_JARL_PATH)
		print("DynastyManager: PlayerJarl.tres loaded successfully.")
	else:
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
	return current_jarl.can_take_action(cost) #

func spend_authority(cost: int) -> bool:
	if not current_jarl:
		return false
		
	if current_jarl.spend_authority(cost):
		_save_jarl_data()
		jarl_stats_updated.emit(current_jarl) #
		print("DynastyManager: Spent %d authority. %d remaining." % [cost, current_jarl.current_authority])
		return true
	
	print("DynastyManager: Failed to spend %d authority. %d remaining." % [cost, current_jarl.current_authority])
	return false

func end_year() -> void:
	if not current_jarl:
		return
		
	current_jarl.reset_authority() #
	# TODO: Hook in Renown Decay and other end-of-year events here
	
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("DynastyManager: Year ended. Authority reset to %d." % current_jarl.max_authority)

func set_current_raid_target(data: SettlementData) -> void:
	current_raid_target = data #
	print("DynastyManager: Raid target set to %s" % data.resource_path)

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
	else:
		print("DynastyManager: Jarl data saved to %s" % current_jarl.resource_path)

func award_renown(amount: int) -> void:
	if not current_jarl:
		return
	
	current_jarl.award_renown(amount) #
	_save_jarl_data()
	jarl_stats_updated.emit(current_jarl)
	print("DynastyManager: Awarded %d renown. Total: %d" % [amount, current_jarl.renown])
