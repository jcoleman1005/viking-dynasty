# res://data/missions/RaidLootData.gd
# Resource for tracking loot collected during raids
# GDD Ref: Phase 3 Task 7 - Resource-Driven Payout

extends Resource
class_name RaidLootData

@export var collected_loot: Dictionary = {}

func _init() -> void:
	# Initialize with default resource types
	collected_loot = {
		"gold": 0,
		"wood": 0,
		"food": 0,
		"stone": 0
	}

func add_loot(resource_type: String, amount: int) -> void:
	"""Add loot to the collection"""
	if collected_loot.has(resource_type):
		collected_loot[resource_type] += amount
	else:
		collected_loot[resource_type] = amount
	
	Loggie.msg("Loot added: %d %s (Total: %d)" % [amount, resource_type, collected_loot[resource_type]]).domain("MAP").info()

func add_loot_from_building(building_data: BuildingData) -> void:
	"""Extract loot from a destroyed building"""
	if not building_data:
		return
	
	# For EconomicBuildingData, give loot based on the resource type
	if building_data is EconomicBuildingData:
		var eco_data: EconomicBuildingData = building_data
		var loot_amount = eco_data.fixed_payout_amount * 3  # 3x the daily payout as loot
		add_loot(eco_data.resource_type, loot_amount)
	else:
		# Default loot for other buildings
		add_loot("gold", 50)

func get_total_loot() -> Dictionary:
	"""Get a copy of the collected loot"""
	return collected_loot.duplicate()

func clear_loot() -> void:
	"""Reset all loot to zero"""
	for resource_type in collected_loot:
		collected_loot[resource_type] = 0

func get_loot_summary() -> String:
	"""Get a formatted string of collected loot"""
	var summary_parts: Array[String] = []
	for resource_type in collected_loot:
		if collected_loot[resource_type] > 0:
			summary_parts.append("%d %s" % [collected_loot[resource_type], resource_type])
	
	if summary_parts.is_empty():
		return "No loot collected"
	else:
		return "Loot: " + ", ".join(summary_parts)
