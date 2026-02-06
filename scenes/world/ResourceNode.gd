#res://scenes/world/ResourceNode.gd
@tool
class_name ResourceNode
extends Area2D

signal node_depleted(node: ResourceNode)

# --- Configuration ---
@export_group("District Settings")
## The type of resource. Must match EconomicBuildingData.resource_type (e.g., "wood", "food", "stone").
@export var resource_type: String = "wood":
	set(value):
		resource_type = value
		queue_redraw() # Update color in editor

## The radius (in pixels) within which gathering buildings must be placed.
## Default: 6 tiles * 32px = 192.0
@export var district_radius: float = 192.0:
	set(value):
		district_radius = value
		queue_redraw() # Update circle size in editor

@export_group("Pool Settings")
@export var max_pool: int = 1000
@export var current_pool: int = 1000
@export var is_infinite: bool = false

# --- Internal ---
# Colors for the editor visualizer
const DEBUG_COLORS = {
	"wood": Color.FOREST_GREEN,
	"food": Color.GOLDENROD,
	"stone": Color.LIGHT_SLATE_GRAY,
	"gold": Color.GOLD
}

func _ready() -> void:
	# Critical: Registers this node so the SettlementManager can find it for placement checks
	add_to_group("resource_nodes")
	
	if not Engine.is_editor_hint():
		# Runtime initialization
		current_pool = max_pool

func _draw() -> void:
	# Only draw the district radius in the Editor or if Debug Collisions is on
	if Engine.is_editor_hint() or get_tree().debug_collisions_hint:
		var color = DEBUG_COLORS.get(resource_type, Color.WHITE)
		
		# Draw faint fill area
		draw_circle(Vector2.ZERO, district_radius, Color(color.r, color.g, color.b, 0.1))
		# Draw dashed outline (approximate)
		draw_arc(Vector2.ZERO, district_radius, 0, TAU, 64, color, 2.0)

# --- Public API ---

func harvest(amount: int) -> int:
	"""
	Attempts to harvest 'amount'. Returns actual harvested amount.
	"""
	if is_depleted(): 
		return 0
	
	if is_infinite: 
		return amount
		
	var actual_amount = min(amount, current_pool)
	current_pool -= actual_amount
	
	if current_pool <= 0:
		_on_depletion()
		
	return actual_amount

func is_depleted() -> bool:
	return not is_infinite and current_pool <= 0

## Checks if a world position is inside this node's district
func is_position_in_district(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= district_radius

func _on_depletion() -> void:
	Loggie.msg("Resource Node depleted: %s" % name).domain(LogDomains.ECONOMY).info()
	node_depleted.emit(self)
	# Visual feedback for depletion can be added here (e.g., change sprite to stump)
	modulate = Color(0.5, 0.5, 0.5)
