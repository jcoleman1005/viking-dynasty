extends Control

## SummerAllocation_UI
##
## Handles the distribution of villager labor during the Summer phase.
## Allows assigning peasants to Construction, Farming, and Raiding.
## Only visible when toggled via Storefront during "Summer".

# -- Configuration --
@export_group("Configuration")
@export var raider_template: UnitData ## The UnitData resource used for drafted peasants (e.g., Bondi).
@export var estimated_farm_yield: int = 100 ## Estimated yield per farmer if dynamic calculation fails.

# -- Constants --
const SEASONS_PER_YEAR: int = 4
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const WINTER_FOOD_PER_PEASANT: int = 1 # Used for live projection adjustments

# -- Nodes --
@onready var label_population: Label = %PopulationLabel
@onready var label_unassigned: Label = %UnassignedLabel

@onready var slider_construction: HSlider = %ConstructionSlider
@onready var slider_farming: HSlider = %FarmingSlider
@onready var slider_raiding: HSlider = %RaidingSlider

@onready var val_construction: Label = %ValConstruction
@onready var val_farming: Label = %ValFarming
@onready var val_raiding: Label = %ValRaiding

@onready var proj_construction: Label = %Proj_Construction
@onready var proj_food: Label = %Proj_Food
@onready var proj_raid: Label = %Proj_Raid

# Winter Forecast Nodes
@onready var lbl_current_stockpile: Label = %Lbl_Stockpile
@onready var lbl_winter_demand: Label = %Lbl_WinterDemand
@onready var lbl_winter_net: Label = %Lbl_WinterNet

@onready var btn_commit_raid: Button = %CommitRaidBtn
@onready var btn_confirm: Button = %ConfirmBtn

# -- State --
var total_peasants: int = 0
var total_construction_slots: int = 0
var total_farming_slots: int = 0
var allocations: Dictionary = {
	"construction": 0,
	"farming": 0,
	"raiding": 0
}

# Semaphore to prevent recursion during slider updates
var _updating_sliders: bool = false

func _ready() -> void:
	add_to_group("seasonal_ui")
	visible = false
	
	if not raider_template:
		Loggie.msg("SummerAllocation_UI: 'raider_template' is not assigned in Inspector!").domain(LogDomains.GAMEPLAY).error()
	
	_connect_signals()
	
	if DynastyManager.get_current_season_name() == "Summer":
		_initialize_data()

func _connect_signals() -> void:
	slider_construction.value_changed.connect(_on_allocation_changed)
	slider_farming.value_changed.connect(_on_allocation_changed)
	slider_raiding.value_changed.connect(_on_allocation_changed)
	
	btn_commit_raid.pressed.connect(_on_commit_raid_pressed)
	btn_confirm.pressed.connect(_on_confirm_pressed)
	
	EventBus.season_changed.connect(_on_season_changed)

func _on_season_changed(season_name: String) -> void:
	if season_name != "Summer":
		visible = false
	else:
		_initialize_data()

func toggle_interface(interface_name: String = "") -> void:
	if interface_name != "" and interface_name != "allocation": return
	if DynastyManager.get_current_season_name() != "Summer":
		Loggie.msg("Cannot open Summer Allocation: Wrong Season").domain(LogDomains.UI).warn()
		visible = false
		return
		
	visible = not visible
	if visible:
		_initialize_data()
		move_to_front()

func _initialize_data() -> void:
	if not SettlementManager.current_settlement: return
	
	total_peasants = SettlementManager.current_settlement.population_peasants
	
	# 2a. Construction Slots
	total_construction_slots = 0
	var pending = SettlementManager.current_settlement.pending_construction_buildings
	for entry in pending:
		if "resource_path" in entry:
			var b_data = load(entry["resource_path"]) as BuildingData
			if b_data:
				var cap = b_data.base_labor_capacity if "base_labor_capacity" in b_data else 3
				total_construction_slots += cap
				
	# 2b. Farming Slots
	total_farming_slots = 0
	var placed = SettlementManager.current_settlement.placed_buildings
	for entry in placed:
		if "resource_path" in entry:
			var b_data = load(entry["resource_path"])
			if b_data is EconomicBuildingData:
				total_farming_slots += b_data.peasant_capacity
	
	# Reset allocations to a safe state if opening fresh
	if allocations.construction == 0 and allocations.farming == 0 and allocations.raiding == 0:
		var initial_farm = min(int(total_farming_slots * 0.8), total_peasants)
		allocations.farming = initial_farm
		
		var remaining = total_peasants - initial_farm
		var initial_const = min(total_construction_slots, remaining)
		allocations.construction = initial_const
		
		allocations.raiding = 0
	
	# Force an update to sync sliders and set initial dynamic max values
	_sync_sliders_to_data()
	_recalculate_slider_limits()

func _sync_sliders_to_data() -> void:
	_updating_sliders = true
	slider_construction.set_value_no_signal(allocations.construction)
	slider_farming.set_value_no_signal(allocations.farming)
	slider_raiding.set_value_no_signal(allocations.raiding)
	_updating_sliders = false
	_update_ui()

# -- Logic --

func _on_allocation_changed(_value: float) -> void:
	if _updating_sliders: return
	
	allocations.construction = int(slider_construction.value)
	allocations.farming = int(slider_farming.value)
	allocations.raiding = int(slider_raiding.value)
	
	# Recalculate limits immediately to prevent over-allocation
	_recalculate_slider_limits()
	_update_ui()

func _recalculate_slider_limits() -> void:
	_updating_sliders = true
	
	var used = allocations.construction + allocations.farming + allocations.raiding
	var free_pop = total_peasants - used
	
	# Construction Limit
	var potential_const = allocations.construction + free_pop
	var final_max_const = min(potential_const, total_construction_slots)
	slider_construction.max_value = max(final_max_const, allocations.construction) 
	
	# Farming Limit
	var potential_farm = allocations.farming + free_pop
	var final_max_farm = min(potential_farm, total_farming_slots)
	slider_farming.max_value = max(final_max_farm, allocations.farming)
	
	# Raiding Limit (Only limit is total population)
	var potential_raid = allocations.raiding + free_pop
	slider_raiding.max_value = potential_raid
	
	_updating_sliders = false

func _update_ui() -> void:
	var used = allocations.construction + allocations.farming + allocations.raiding
	var unassigned = total_peasants - used
	
	label_population.text = "Available Villagers: %d" % total_peasants
	val_construction.text = str(allocations.construction)
	val_farming.text = str(allocations.farming)
	val_raiding.text = str(allocations.raiding)
	
	if unassigned < 0:
		label_unassigned.text = "OVER-ALLOCATED: %d" % unassigned
		label_unassigned.add_theme_color_override("font_color", Color.RED)
		btn_commit_raid.disabled = true
		btn_confirm.disabled = true
	else:
		label_unassigned.text = "Unassigned: %d" % unassigned
		label_unassigned.add_theme_color_override("font_color", Color.WHITE)
		btn_commit_raid.disabled = (allocations.raiding <= 0 or raider_template == null)
		btn_confirm.disabled = false 
	
	_update_projections()
	_update_winter_forecast()

func _update_projections() -> void:
	# 1. Construction Projection (Detailed List)
	var pending = SettlementManager.current_settlement.pending_construction_buildings
	if pending.is_empty():
		proj_construction.text = "No pending construction"
		proj_construction.add_theme_color_override("font_color", Color.GRAY)
	else:
		proj_construction.remove_theme_color_override("font_color")
		var report = ""
		
		# Get simulated assignment to predict speeds
		var assignments = _get_builder_distribution(allocations.construction)
		
		for i in range(pending.size()):
			var entry = pending[i]
			var b_data = load(entry["resource_path"]) as BuildingData
			var assigned_workers = assignments[i]
			var b_name = b_data.display_name if b_data else "Building"
			
			if assigned_workers == 0:
				report += "%s: Paused (0 workers)\n" % b_name
			else:
				var total_effort = 100 
				if b_data and "construction_effort_required" in b_data:
					total_effort = b_data.construction_effort_required
				
				var remaining_effort = max(0, total_effort - entry.get("progress", 0))
				var seasonal_progress = assigned_workers * EconomyManager.BUILDER_EFFICIENCY
				
				if seasonal_progress > 0:
					var turns_needed = ceil(float(remaining_effort) / float(seasonal_progress))
					var date_str = _calculate_completion_date(int(turns_needed))
					report += "%s: %s (%d Turns)\n" % [b_name, date_str, turns_needed]
				else:
					report += "%s: Stalled\n" % b_name
					
		proj_construction.text = report
	
	# 2. Food / Resource Projection
	if total_farming_slots == 0:
		proj_food.text = "No resource buildings"
		proj_food.add_theme_color_override("font_color", Color.RED)
	else:
		var yields = EconomyManager.calculate_hypothetical_yields(allocations.farming)
		var food_amt = yields.get("food", 0)
		var other_text = ""
		
		for k in yields:
			if k != "food" and yields[k] > 0:
				other_text += ", +%d %s" % [yields[k], k.capitalize()]
				
		proj_food.text = "~%d Food%s" % [food_amt, other_text]
		proj_food.remove_theme_color_override("font_color")
	
	# 3. Raid Projection
	var men = allocations.raiding
	var bands = ceil(men / 10.0)
	proj_raid.text = "%d Men (%d Warbands)" % [men, bands]

func _update_winter_forecast() -> void:
	if not SettlementManager.current_settlement: return
	
	# 1. Get Base Forecast (Current State)
	var forecast = EconomyManager.get_winter_forecast()
	var base_food_demand = forecast.get("food", 0)
	var wood_demand = forecast.get("wood", 0)
	
	# 2. Adjust for Allocated Raiders (Simulate them leaving)
	var raiders = allocations.raiding
	var adjusted_food_demand = max(0, base_food_demand - (raiders * WINTER_FOOD_PER_PEASANT))
	
	# 3. Get Stockpiles
	var treasury = SettlementManager.current_settlement.treasury
	var current_food = treasury.get("food", 0)
	var current_wood = treasury.get("wood", 0)
	
	# 4. Get Projected Yields from Farming Slider (UPDATED)
	var estimated_yields = EconomyManager.calculate_hypothetical_yields(allocations.farming)
	var projected_food_yield = estimated_yields.get(GameResources.FOOD, 0)
	var projected_wood_yield = estimated_yields.get(GameResources.WOOD, 0)
	
	# 5. Total Available Calculation
	var total_food_available = current_food + projected_food_yield
	var total_wood_available = current_wood + projected_wood_yield
	
	# 6. Display Stockpile Info (Stockpile + Yield)
	lbl_current_stockpile.text = "Available: %d Food (%d + %d), %d Wood" % [total_food_available, current_food, projected_food_yield, total_wood_available]
	
	# 7. Display Projected Demand
	lbl_winter_demand.text = "Proj. Winter Demand: %d Food, %d Wood" % [adjusted_food_demand, wood_demand]
	
	# 8. Net Calculation
	var food_net = total_food_available - adjusted_food_demand
	var wood_net = total_wood_available - wood_demand
	
	var status_text = ""
	var color = Color.DARK_GREEN
	
	if food_net < 0 or wood_net < 0:
		color = Color.RED
		status_text = "WARNING: Deficit Predicted ("
		if food_net < 0: status_text += "%d Food " % food_net
		if wood_net < 0: status_text += "%d Wood" % wood_net
		status_text += ")"
	else:
		status_text = "Winter Secure (Surplus: +%d Food)" % food_net
		
	lbl_winter_net.text = status_text
	lbl_winter_net.add_theme_color_override("font_color", color)

func _calculate_completion_date(turns_needed: int) -> String:
	# Fallback to 867 if missing
	var current_year = 867
	if "current_year" in DynastyManager:
		current_year = DynastyManager.current_year
	elif "year" in DynastyManager:
		current_year = DynastyManager.year
	
	var current_season_idx = DynastyManager.current_season # Enum (0-3)
	
	var absolute_current_turn = (current_year * SEASONS_PER_YEAR) + current_season_idx
	var absolute_completion_turn = absolute_current_turn + turns_needed
	
	var future_year = floor(absolute_completion_turn / float(SEASONS_PER_YEAR))
	var future_season_idx = absolute_completion_turn % SEASONS_PER_YEAR
	
	var season_name = "Unknown"
	if future_season_idx >= 0 and future_season_idx < SEASON_NAMES.size():
		season_name = SEASON_NAMES[future_season_idx]
		
	return "%s, Year %d" % [season_name, future_year]

func _on_confirm_pressed() -> void:
	_apply_builder_distribution(allocations.construction)
	_distribute_farmers(allocations.farming)
	
	Loggie.msg("Summer allocations confirmed | Allocations: %s" % str(allocations)).domain(LogDomains.GAMEPLAY).info()
	visible = false

# -- Distribution Logic --

func _get_builder_distribution(total_pool: int) -> Array:
	var results = []
	if not SettlementManager.current_settlement: return results
	
	var remaining = total_pool
	var pending = SettlementManager.current_settlement.pending_construction_buildings
	
	for entry in pending:
		var b_data = load(entry["resource_path"]) as BuildingData
		var capacity = 3
		if b_data and "base_labor_capacity" in b_data:
			capacity = b_data.base_labor_capacity
			
		var to_assign = min(remaining, capacity)
		results.append(to_assign)
		remaining -= to_assign
		
	return results

func _apply_builder_distribution(total_pool: int) -> void:
	if not SettlementManager.current_settlement: return
	
	var assignments = _get_builder_distribution(total_pool)
	var pending = SettlementManager.current_settlement.pending_construction_buildings
	
	for i in range(pending.size()):
		if i < assignments.size():
			pending[i]["peasant_count"] = assignments[i]
			
	SettlementManager.save_settlement()


func _distribute_farmers(total_farmers: int) -> void:
	if not SettlementManager.current_settlement: return
	
	var remaining = total_farmers
	var placed = SettlementManager.current_settlement.placed_buildings
	
	var food_buildings = []
	var other_buildings = []
	
	for entry in placed:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			entry["peasant_count"] = 0
			if b_data.resource_type == "food":
				food_buildings.append({"entry": entry, "cap": b_data.peasant_capacity})
			else:
				other_buildings.append({"entry": entry, "cap": b_data.peasant_capacity})
	
	for item in food_buildings:
		if remaining <= 0: break
		var to_assign = min(remaining, item.cap)
		item.entry["peasant_count"] = to_assign
		remaining -= to_assign
		
	for item in other_buildings:
		if remaining <= 0: break
		var to_assign = min(remaining, item.cap)
		item.entry["peasant_count"] = to_assign
		remaining -= to_assign

	SettlementManager.save_settlement()

func _on_commit_raid_pressed() -> void:
	if allocations.raiding <= 0: return
	if not raider_template: return
	
	var raid_count = allocations.raiding
	EconomyManager.draft_peasants_to_raiders(raid_count, raider_template)
	
	total_peasants -= raid_count
	allocations.raiding = 0
	
	_initialize_data() 
	_sync_sliders_to_data()
	_recalculate_slider_limits() # Force re-calc after pop change
	
	Loggie.msg("Summer allocation committed | Raiders: %d" % raid_count).domain(LogDomains.GAMEPLAY).info()
	EventBus.raid_committed.emit(raid_count)
