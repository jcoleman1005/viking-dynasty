extends PanelContainer

## Inspector for building details and worker management.

# Refs - Unique names used for portability
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var worker_count_label: Label = %WorkerCountLabel
@onready var btn_add: Button = %BtnAdd
@onready var btn_remove: Button = %BtnRemove

const SUMMER_TOOLTIP = "Workers are managed via Summer Allocation Council."

var current_building: BaseBuilding
var current_entry: Dictionary 

func _ready() -> void:
	hide()
	# Connect to core selection and loading events
	EventBus.building_selected.connect(_on_building_selected)
	EventBus.building_deselected.connect(hide)
	EventBus.settlement_loaded.connect(func(_s): _refresh_data())
	
	# Connect to season changes to refresh UI state immediately
	EventBus.season_changed.connect(_on_season_changed)
	
	# Initial button signal connections
	btn_add.pressed.connect(_on_add_worker)
	btn_remove.pressed.connect(_on_remove_worker)

func _on_season_changed(_name: String, _data: Dictionary) -> void:
	_refresh_data()

func _on_building_selected(building: BaseBuilding) -> void:
	if not building:
		hide()
		return
	
	current_building = building
	_refresh_data()
	show()

func _refresh_data() -> void:
	if not is_instance_valid(current_building): 
		hide()
		return
		
	var data = current_building.data
	if not data: return
	
	current_entry = SettlementManager._find_entry_for_building(current_building)
	
	if current_entry.is_empty():
		hide()
		return
	
	# 1. Determine Current & Max Workers
	var p_count = current_entry.get("peasant_count", 0)
	var capacity = 0
	
	if current_building.current_state == BaseBuilding.BuildingState.ACTIVE:
		if data is EconomicBuildingData:
			capacity = (data as EconomicBuildingData).peasant_capacity
		else:
			capacity = 0 # Defensive buildings usually don't have workers
	else:
		# Construction / Blueprint
		capacity = data.base_labor_capacity

	# 2. Update Headers & Counts
	name_label.text = data.display_name
	if data.icon: icon_rect.texture = data.icon
	
	# Display "Current / Max"
	worker_count_label.text = "%d / %d" % [p_count, capacity]
	
	# 3. Dynamic Stats Text
	var text = ""
	
	if current_building.current_state == BaseBuilding.BuildingState.ACTIVE:
		if data is EconomicBuildingData:
			var eco = data as EconomicBuildingData
			var production = (eco.base_passive_output * p_count) 
			text += "[b]Yield:[/b] %d %s / Year\n" % [production, eco.resource_type.capitalize()]
		else:
			text += "Defensive Structure\nNo Production."
			
	else: # Construction / Blueprint
		var progress = current_entry.get("progress", 0)
		var req = data.construction_effort_required
		var pct = 0
		if req > 0:
			pct = int((float(progress) / req) * 100)
		
		text += "[b]Status:[/b] Constructing (%d%%)\n" % pct
		text += "[b]Progress:[/b] %d / %d\n" % [progress, req]
		
		var labor_per_year = p_count * EconomyManager.BUILDER_EFFICIENCY
		
		if labor_per_year > 0:
			var remaining = req - progress
			var years = ceil(float(remaining) / labor_per_year)
			text += "[color=blue]Est. Time: %d Year(s)[/color]" % years
		else:
			text += "[color=red]Est. Time: NO WORKERS ASSIGNED![/color]"
			
	stats_label.text = text
	
	# 4. Button State & Season Logic
	var is_summer = DynastyManager.current_season == DynastyManager.Season.SUMMER
	
	if is_summer:
		# Disable micro-management during Summer macro-management phase
		btn_add.disabled = true
		btn_remove.disabled = true
		btn_add.tooltip_text = SUMMER_TOOLTIP
		btn_remove.tooltip_text = SUMMER_TOOLTIP
		
		Loggie.msg("Building buttons locked for Summer").domain(LogDomains.GAMEPLAY).debug()
	else:
		# Standard seasonal behavior
		btn_add.disabled = p_count >= capacity
		btn_remove.disabled = p_count <= 0
		btn_add.tooltip_text = "" 
		btn_remove.tooltip_text = ""

func _on_add_worker() -> void:
	Loggie.msg("Manual worker assignment requested").domain(LogDomains.GAMEPLAY).info()
	EventBus.request_worker_assignment.emit(current_building)

func _on_remove_worker() -> void:
	Loggie.msg("Manual worker removal requested").domain(LogDomains.GAMEPLAY).info()
	EventBus.request_worker_removal.emit(current_building)
