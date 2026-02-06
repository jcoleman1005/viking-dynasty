class_name AutumnReport
extends Resource

## A data container for the Autumn Resolution phase.
## Acts as an immutable snapshot of the transition from Autumn to Winter.
## Use init_from_context() to populate.

# ------------------------------------------------------------------------------
# Properties
# ------------------------------------------------------------------------------

## The total food gained during the Autumn harvest.
@export var harvest_yield: int = 0

## The estimated amount of food required to survive Winter.
@export var winter_demand: int = 0

## The calculated surplus (positive) or deficit (negative).
## Formula: (Treasury Total) - (Winter Demand)
@export var net_outcome: int = 0

## A snapshot of the treasury state at the exact moment of the season change.
## Keys match GameResources constants (e.g., GameResources.FOOD).
@export var treasury_snapshot: Dictionary = {}

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------

## Populates the report from the context dictionary provided by DynastyManager.
## @param context: Must contain keys "payout" (Dict), "forecast" (Dict), and "treasury" (Dict).
func init_from_context(context: Dictionary) -> void:
	# 1. Harvest Yield (Income)
	# Safely extract the food payout using the global constant.
	var payout_data: Dictionary = context.get("payout", {})
	if payout_data.has(GameResources.FOOD):
		harvest_yield = int(payout_data[GameResources.FOOD])
	else:
		harvest_yield = 0

	# 2. Winter Demand (Expense Projection)
	var forecast_data: Dictionary = context.get("forecast", {})
	if forecast_data.has(GameResources.FOOD):
		winter_demand = int(forecast_data[GameResources.FOOD])
	else:
		winter_demand = 0

	# 3. Treasury Snapshot (Current State)
	# We duplicate to ensure this report remains immutable even if the game state changes later.
	var raw_treasury: Dictionary = context.get("treasury", {})
	treasury_snapshot = raw_treasury.duplicate()
	
	var current_food_total: int = 0
	if treasury_snapshot.has(GameResources.FOOD):
		current_food_total = int(treasury_snapshot[GameResources.FOOD])

	# 4. Net Outcome (The Verdict)
	# Since this runs AFTER the Manager deposits the harvest, current_food_total includes harvest_yield.
	# Positive = Surplus, Negative = Deficit (Starvation Risk).
	net_outcome = current_food_total - winter_demand
