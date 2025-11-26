# res://data/missions/RaidLootData.gd
extends Resource
class_name RaidLootData

@export var collected_loot: Dictionary = {}

func _init() -> void:
	# --- FIX: Use Constants ---
	collected_loot = {
		GameResources.GOLD: 0,
		GameResources.WOOD: 0,
		GameResources.FOOD: 0,
		GameResources.STONE: 0
	}

func add_loot(resource_type: String, amount: int) -> void:
	if collected_loot.has(resource_type):
		collected_loot[resource_type] += amount
	else:
		collected_loot[resource_type] = amount
	
	Loggie.msg("Loot added: %d %s (Total: %d)" % [amount, resource_type, collected_loot[resource_type]]).domain("MAP").info()

func add_loot_from_building(building_data: BuildingData) -> void:
	if not building_data:
		return
	
	if building_data is EconomicBuildingData:
		var eco_data: EconomicBuildingData = building_data
		var loot_amount = eco_data.fixed_payout_amount * 3
		add_loot(eco_data.resource_type, loot_amount)
	else:
		# --- FIX: Use Constant ---
		add_loot(GameResources.GOLD, 50)

func get_total_loot() -> Dictionary:
	return collected_loot.duplicate()

func clear_loot() -> void:
	for resource_type in collected_loot:
		collected_loot[resource_type] = 0

func get_loot_summary() -> String:
	var summary_parts: Array[String] = []
	# Use GameResources order to ensure consistent display (Gold first, then Wood...)
	for resource_type in GameResources.ALL_CURRENCIES:
		if collected_loot.has(resource_type) and collected_loot[resource_type] > 0:
			var display_name = GameResources.get_display_name(resource_type)
			summary_parts.append("%d %s" % [collected_loot[resource_type], display_name])
	
	if summary_parts.is_empty():
		return "No loot collected"
	else:
		return "Loot: " + ", ".join(summary_parts)
