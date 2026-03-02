extends Node

## ConstructionAuthority
## Manages the construction decree queue and lifecycle.
## Delegates execution to SettlementManager and EconomyManager.

var active_decrees: Array[ConstructionDecree] = []
var _locked_households: Dictionary = {} # household_name: String -> decree_id: String

func _ready() -> void:
	if EventBus:
		EventBus.settlement_loaded.connect(_on_settlement_loaded)
	
	# Initial sync if already loaded
	if SettlementManager.current_settlement:
		_on_settlement_loaded(SettlementManager.current_settlement)

func _on_settlement_loaded(settlement: SettlementData) -> void:
	active_decrees = settlement.decree_queue
	_locked_households.clear()
	for d in active_decrees:
		if d.state == ConstructionDecree.DecreeState.AUTHORIZED and d.assigned_household_name != "":
			_locked_households[d.assigned_household_name] = d.decree_id

func issue_decree(building_data: BuildingData, resource_node: Node) -> ConstructionDecree:
	if not SettlementManager.active_tilemap_layer:
		return null
		
	# 1. Create a new Decree in DRAFT state
	var decree = ConstructionDecree.new()
	decree.building_data = building_data
	decree.target_resource_node = resource_node.get_path()
	decree.state = ConstructionDecree.DecreeState.DRAFT
	
	# 2. Convert resource_node world position to grid coordinates
	var origin_grid = SettlementManager.world_to_grid(resource_node.global_position)
	
	# 3. Run a BFS search centered on that grid position
	# 4. Exclude tiles already reserved by other active Decrees
	var reserved = get_reserved_tiles()
	var result = _run_survey_bfs(origin_grid, building_data.grid_size, reserved)
	
	# 5. Set decree.resolved_grid_pos to the result
	if result != Vector2i(-999, -999):
		decree.resolved_grid_pos = result
		# 6. Add Decree to active_decrees
		active_decrees.append(decree)
		# 7. Return the Decree
		return decree
	
	return null

func authorize_decree(decree: ConstructionDecree, household: HouseholdData) -> bool:
	# 1. Validate household.current_oath == HouseholdData.SeasonalOath.BUILD
	if household.current_oath != HouseholdData.SeasonalOath.BUILD:
		return false
		
	# 2. Validate household.household_name is not already in _locked_households
	if _locked_households.has(household.household_name):
		return false
		
	# 3. Call EconomyManager.attempt_purchase(decree.building_data.build_cost)
	if not EconomyManager.attempt_purchase(decree.building_data.build_cost):
		return false
		
	# 4. Set decree.assigned_household_name to household.household_name
	decree.assigned_household_name = household.household_name
	
	# 5. Add household.household_name to _locked_households
	_locked_households[household.household_name] = decree.decree_id
	
	# 6. Transition decree.state to AUTHORIZED
	decree.state = ConstructionDecree.DecreeState.AUTHORIZED
	
	# NEW: Immediately seal the decree to place the blueprint on the map
	seal_all_authorized_decrees()
	
	return true

func cancel_decree(decree: ConstructionDecree) -> void:
	# 1. If decree.state == AUTHORIZED: call EconomyManager.deposit_resources
	if decree.state == ConstructionDecree.DecreeState.AUTHORIZED:
		EconomyManager.deposit_resources(decree.building_data.build_cost)
		
	# 2. Remove decree.assigned_household_name from _locked_households
	if decree.assigned_household_name != "":
		_locked_households.erase(decree.assigned_household_name)
		
	# 3. Remove Decree from active_decrees
	active_decrees.erase(decree)
	
	EventBus.decree_cancelled.emit(decree.resolved_grid_pos)
	
	# (settlement.decree_queue is the same array reference if synced via _on_settlement_loaded)

func seal_all_authorized_decrees() -> void:
	# 1. Check if SettlementManager.active_tilemap_layer is valid
	if not SettlementManager.active_tilemap_layer:
		return
		
	# 2. Iterate active_decrees where state == AUTHORIZED
	# Use a separate list to avoid modifying array while iterating
	var to_seal: Array[ConstructionDecree] = []
	for d in active_decrees:
		if d.state == ConstructionDecree.DecreeState.AUTHORIZED:
			to_seal.append(d)
			
	for decree in to_seal:
		# 3. call SettlementManager.place_building(decree.building_data, decree.resolved_grid_pos, true)
		var building_node = SettlementManager.place_building(decree.building_data, decree.resolved_grid_pos, true)
		
		if not building_node:
			Loggie.msg("ConstructionAuthority: Failed to place building at %s for decree %s" % [decree.resolved_grid_pos, decree.decree_id]).domain(LogDomains.SETTLEMENT).error()
			continue
			
		Loggie.msg("ConstructionAuthority: Successfully placed blueprint for %s at %s" % [decree.building_data.display_name, decree.resolved_grid_pos]).domain(LogDomains.SETTLEMENT).info()
		
		# 4. Immediately after placement, find the newly created entry in pending_construction_buildings
		if SettlementManager.current_settlement:
			for entry in SettlementManager.current_settlement.pending_construction_buildings:
				var entry_pos = entry.get("grid_position", Vector2i(-999, -999))
				if entry_pos == decree.resolved_grid_pos:
					# 5. Write decree.assigned_household_name into that entry
					entry["assigned_household_name"] = decree.assigned_household_name
					# 6. Write the household's member_count into that entry as peasant_count
					var household = decree.get_household()
					if household:
						entry["peasant_count"] = household.member_count
					break
		
		# 7. Remove decree.assigned_household_name from _locked_households
		if decree.assigned_household_name != "":
			_locked_households.erase(decree.assigned_household_name)
			
		# 8. Transition decree.state to SEALED
		decree.state = ConstructionDecree.DecreeState.SEALED
		
		# 9. Remove Decree from active_decrees
		active_decrees.erase(decree)
		
		EventBus.decree_sealed.emit(decree.resolved_grid_pos)

func get_reserved_tiles() -> Array[Vector2i]:
	var reserved: Array[Vector2i] = []
	for d in active_decrees:
		if d.resolved_grid_pos != Vector2i(-999, -999):
			for x in range(d.building_data.grid_size.x):
				for y in range(d.building_data.grid_size.y):
					reserved.append(d.resolved_grid_pos + Vector2i(x, y))
	return reserved

func _run_survey_bfs(origin: Vector2i, size: Vector2i, reserved: Array[Vector2i]) -> Vector2i:
	var queue = [origin]
	var visited = {origin: true}
	var max_steps = 100 
	var steps = 0
	
	while queue.size() > 0 and steps < max_steps:
		var current = queue.pop_front()
		steps += 1
		
		if SettlementManager.is_placement_valid(current, size):
			var conflict = false
			for x in range(size.x):
				for y in range(size.y):
					if (current + Vector2i(x, y)) in reserved:
						conflict = true
						break
				if conflict: break
				
			if not conflict:
				return current
				
		var neighbors = [
			current + Vector2i(1, 0),
			current + Vector2i(-1, 0),
			current + Vector2i(0, 1),
			current + Vector2i(0, -1)
		]
		
		for n in neighbors:
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
				
	return Vector2i(-999, -999)
