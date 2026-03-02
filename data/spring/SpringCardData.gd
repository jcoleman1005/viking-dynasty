class_name SpringCardData
extends Resource

@export var card_id: String = ""
@export var stat_gate: String = "" # "command", "stewardship", "learning", "prowess", "diplomacy", "charisma"
@export var stat_threshold: int = 0
@export var oath_phrasings: Array[String] = []
@export var condition_template: String = ""
@export var threshold_base: int = 0
@export var threshold_stat_multiplier: float = 0.0
@export var reward_mechanical: String = ""
@export var reward_narrative_template: String = ""
@export var consequence_mechanical: String = ""
@export var consequence_narrative_template: String = ""
## Key matching DynastyManager.spring_oath_metric (e.g. "food_harvested", "gold_raided").
@export var oath_metric_key: String = ""
@export var is_founding_echo: bool = false
@export var founding_echo_exile: String = ""
@export var is_intersection: bool = false
@export var secondary_stat_gate: String = ""
@export var secondary_stat_threshold: int = 0

# Runtime state — not exported; populated by SpringCardSelector.
var calculated_threshold: int = 0
var selected_phrasing: String = ""
