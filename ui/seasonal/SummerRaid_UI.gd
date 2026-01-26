class_name SummerRaid_UI
extends Control

## The Summer Overlay.
## Manages assigning villagers to Raids vs Farming.

# --- Configuration ---
@export_group("Raid Settings")
@export var raider_template: Resource 
@export var gold_per_raider_estimate: int = 15

# --- Nodes ---
@onready var total_pop_label: Label = %TotalPopLabel
@onready var farm_count_label: Label = %FarmCountLabel
@onready var raid_count_label: Label = %RaidCountLabel
@onready var allocation_slider: HSlider = %AllocationSlider
@onready var loot_label: Label = %LootLabel
@onready var launch_button: Button = %LaunchButton

# --- State ---
var _total_peasants: int = 0

func _ready() -> void:
	# 1. VISIBILITY CHECK (The Fix)
	# Check season immediately to prevent showing up in Spring/Winter
	if DynastyManager.current_season == DynastyManager.Season.SUMMER:
		visible = true
		_init_summer_logic()
	else:
		visible = false
	
	# 2. Listen for changes
	EventBus.season_changed.connect(_on_season_changed)

func _on_season_changed(season_name: String) -> void:
	if season_name.to_lower() == "summer":
		Loggie.msg("Opening Summer UI").domain(LogDomains.UI).info()
		visible = true
		_init_summer_logic()
	else:
		visible = false

func _init_summer_logic() -> void:
	# Wait one frame to ensure SettlementManager is ready if just loaded
	await get_tree().process_frame
	_refresh_population_data()

func _refresh_population_data() -> void:
	if not SettlementManager or not SettlementManager.current_settlement:
		Loggie.msg("No active settlement found for Summer UI").domain(LogDomains.GAMEPLAY).error()
		return
		
	_total_peasants = SettlementManager.get_idle_peasants()
	total_pop_label.text = "Total Available Villagers: %d" % _total_peasants
	
	# Configure Slider
	allocation_slider.min_value = 0
	allocation_slider.max_value = _total_peasants
	allocation_slider.value = 0 
	
	# Connect controls safely
	if not allocation_slider.value_changed.is_connected(_on_slider_changed):
		allocation_slider.value_changed.connect(_on_slider_changed)
	if not launch_button.pressed.is_connected(_on_launch_pressed):
		launch_button.pressed.connect(_on_launch_pressed)
	
	_update_labels(0)

func _on_slider_changed(value: float) -> void:
	_update_labels(int(value))

func _update_labels(raid_count: int) -> void:
	var farm_count = _total_peasants - raid_count
	
	farm_count_label.text = "Assigned to Farming: %d (Safe)" % farm_count
	raid_count_label.text = "Assigned to Raid: %d (Risk)" % raid_count
	
	if raid_count == 0:
		farm_count_label.modulate = Color.GREEN
		raid_count_label.modulate = Color.WHITE
		launch_button.text = "Stand Down (Skip Raid)"
	else:
		farm_count_label.modulate = Color.WHITE
		raid_count_label.modulate = Color(1, 0.5, 0.5)
		launch_button.text = "Launch Raid (%d Men)" % raid_count

	var min_gold = raid_count * (gold_per_raider_estimate / 2)
	var max_gold = raid_count * gold_per_raider_estimate
	loot_label.text = "Est. Loot: %d - %d Gold" % [min_gold, max_gold]

func _on_launch_pressed() -> void:
	var raid_count = int(allocation_slider.value)
	
	# FIX: Added string formatting for raid_count
	Loggie.msg("Summer Decision: %d Raiders Sent" % raid_count).domain(LogDomains.GAMEPLAY).info()
	
	if raid_count > 0:
		_commit_raid_force(raid_count)
	
	EventBus.raid_launched.emit(null, raid_count)
	
	# Request next season (Autumn)
	EventBus.advance_season_requested.emit()
	
	visible = false
	# We don't queue_free() here because Summer UI might be reused next year.
	# The _on_season_changed logic will keep it hidden until then.

func _commit_raid_force(count: int) -> void:
	if not raider_template:
		Loggie.msg("CRITICAL: No Raider Template assigned in SummerRaid_UI").domain(LogDomains.GAMEPLAY).error()
		return

	var new_warband = WarbandData.new(raider_template)
	new_warband.custom_name = "Summer Raiders"
	new_warband.current_manpower = count
	new_warband.is_seasonal = true
	
	RaidManager.outbound_raid_force.append(new_warband)
	
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.population_peasants -= count
		Loggie.msg("Deducted %d peasants from settlement" % count).domain(LogDomains.GAMEPLAY).info()
