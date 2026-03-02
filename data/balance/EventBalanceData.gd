# res://data/balance/EventBalanceData.gd
# Holds all tunable values for event effect handlers as exported variables.
# Assign the companion EventBalanceData.tres instance in the Godot Inspector
# on the EventManager node so handlers can read balanced values without
# magic numbers embedded in code.
class_name EventBalanceData
extends Resource

# --- Full Quarantine ---
@export_group("Full Quarantine")
## Starting labor reduction applied on day 1 of Summer (60%)
@export var full_quarantine_initial_reduction: float = 0.6
## Minimum reduction that holds for the final N days of Summer (20%)
@export var full_quarantine_floor_reduction: float = 0.2
## How many days before the end of Summer the floor reduction kicks in
@export var full_quarantine_hold_days_from_end: int = 3

# --- Partial Quarantine ---
@export_group("Partial Quarantine")
## Maximum sick population reduction achievable at the final Summer day (75%)
@export var partial_quarantine_max_reduction: float = 0.75
## Controls the exponential curve steepness. Higher = slower early, faster late.
@export var partial_quarantine_exponent: float = 2.0
## Random +/- variance applied to the rolled severity
@export var partial_quarantine_random_variance: float = 0.15

# --- Great Feast: Provider ---
@export_group("Great Feast - Provider")
@export var provider_food_cost: int = 50
@export var provider_renown_reward: int = 5
@export var provider_loyalty_reward: int = 10
## Divides population to get scaled loyalty bonus (20 / pop)
@export var provider_loyalty_scaled_divisor: int = 20

# --- Great Feast: Ring-Giver ---
@export_group("Great Feast - Ring-Giver")
@export var ring_giver_food_cost: int = 20
@export var ring_giver_gold_cost: int = 60
@export var ring_giver_renown_reward: int = 25
@export var ring_giver_warband_morale_reward: int = 15

# --- Great Feast: Saga-Worthy ---
@export_group("Great Feast - Saga-Worthy")
@export var saga_food_cost: int = 100
@export var saga_gold_cost: int = 100
@export var saga_renown_reward: int = 75
@export var saga_loyalty_reward: int = 30

# --- Great Feast: Saturation ---
@export_group("Great Feast - Saturation")
## Minimum days between feasts for full reward effect
@export var feast_saturation_cooldown_days: int = 30
## Reward multiplier when the cooldown has not been met
@export var feast_saturation_penalty_multiplier: float = 0.5

# --- Burial Rite ---
@export_group("Burial Rite")
@export var burial_rite_gold_cost: int = 100
## Reduces the incoming Jarl-death loyalty penalty by this fraction (75%)
@export var burial_rite_penalty_reduction: float = 0.75

# --- Buy Grain ---
@export_group("Buy Grain")
## Base food cost per villager rescued
@export var buy_grain_cost_per_villager: int = 4
## Multiplier applied on top of base cost (exported for tuning)
@export var buy_grain_cost_multiplier: int = 4
## Renown lost per villager not saved
@export var buy_grain_renown_loss_on_failure: int = 20

# --- Founding ---
@export_group("Founding")
## WinterManager.harsh_chance multiplied by this for Seeking Opportunity exile reason
@export var opportunity_seeker_winter_multiplier: float = 1.5
## Renown awarded per Crags trigger event
@export var crags_renown_per_trigger: int = 15
## Years between Crags Renown trigger events
@export var crags_renown_trigger_years: int = 2

# --- Renown Decay ---
@export_group("Renown Decay")
## Fraction of Renown lost per year after grace period (5%)
@export var renown_decay_rate: float = 0.05
## Consecutive safe oaths allowed before decay begins
@export var renown_decay_grace_period: int = 2
## Oath threshold > stat * this multiplier is considered bold (1.2 = 20% above comfortable)
@export var bold_oath_threshold_multiplier: float = 1.2

# --- Debt ---
@export_group("Debt")
## Food must be below (projected_winter_consumption * this) to trigger debt offer (30%)
@export var debt_trigger_threshold: float = 0.3
## Repayment amount multiplier when debt is inherited after Jarl death (130%)
@export var debt_inheritance_rate: float = 1.3
