# res://scripts/ai/UnitAIConstants.gd
class_name UnitAIConstants
extends RefCounted

# Defines the possible states for the Unit Finite State Machine
enum State { 
	IDLE, 
	MOVING, 
	FORMATION_MOVING, 
	ATTACKING, 
	RETREATING,
	INTERACTING,
	COLLECTING, # New
	ESCORTING,  # New
	REGROUPING 
}

# Defines behavior stances
enum Stance { 
	AGGRESSIVE, 
	DEFENSIVE, 
	PASSIVE 
}
static func get_surface_distance(unit_node: Node2D, target_node: Node2D) -> float:
	if not is_instance_valid(unit_node) or not is_instance_valid(target_node):
		return INF
		
	var dist_center = unit_node.global_position.distance_to(target_node.global_position)
	
	# 1. Get Target Radius (Building or Unit)
	var r_target = _get_radius(target_node)
	
	# 2. Get Self Radius (The Unit's own body)
	var r_self = _get_radius(unit_node)
	
	# 3. Calculate gap between "skins"
	# (Distance minus both radii)
	return max(0.0, dist_center - r_target - r_self)

static func _get_radius(node: Node2D) -> float:
	# Check for Buildings (Grid based)
	if node is BaseBuilding and node.data:
		var size = min(node.data.grid_size.x, node.data.grid_size.y)
		return (size * 32.0) / 2.0
	
	# Check for Hitbox child (Common in your setup)
	if node.name == "Hitbox" and node.get_parent() is BaseBuilding:
		var b = node.get_parent()
		var size = min(b.data.grid_size.x, b.data.grid_size.y)
		return (size * 32.0) / 2.0
		
	# Check for Units/CollisionShapes
	var col = node.get_node_or_null("CollisionShape2D")
	if col:
		if col.shape is CircleShape2D: return col.shape.radius
		if col.shape is RectangleShape2D: 
			var size = min(col.shape.size.x, col.shape.size.y)
			return size / 2.0
			
	return 15.0 # Default fallback
