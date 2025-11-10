# res://scenes/effects/Projectile.gd
#
# A simple, straight-line projectile that applies damage on impact.
# More performant than homing projectiles.

class_name Projectile
extends Area2D

# Projectile properties
var damage: int = 0
var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	# We now connect to 'area_entered' to detect the building's Hitbox
	area_entered.connect(_on_area_entered)
	# We also keep body_entered for the Watchtower's projectiles
	body_entered.connect(_on_body_entered)
	# --- THIS IS THE FIX (Part 2) ---
	# Set 'monitoring' to true. This tells the Area2D to
	# detect 'monitorable' areas AND bodies.
	self.monitoring = true
	
	# Set 'monitorable' to false. This projectile doesn't
	# need to be detected by other areas.
	self.monitorable = false
	# --- END FIX ---
	lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _physics_process(delta: float) -> void:
	# Move in straight line
	global_position += direction * speed * delta

func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int, projectile_speed: float = 400.0, collision_mask: int = 0) -> void:
	"""
	Initialize the projectile with all necessary parameters.
	"""
	global_position = start_position
	direction = (target_position - start_position).normalized()
	damage = projectile_damage
	speed = projectile_speed
	
	# Set the collision mask on the Area2D
	self.collision_mask = collision_mask
	
	# Point the projectile in the direction of travel (for visual rotation)
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	"""Called when this Area2D detects a 'monitorable' Area2D (like our Hitbox)."""
	
	# Check if the area's layer matches our mask
	if area.collision_layer & self.collision_mask:
		# Find the building, which is the parent of the Hitbox
		var parent_body = area.get_parent()
		if parent_body and parent_body.has_method("take_damage"):
			parent_body.take_damage(damage)
			queue_free() # Destroy projectile
		else:
			push_warning("Projectile hit non-damagable Area: '%s'." % area.name)
	# else: We hit an Area we don't care about (e.g. SeparationArea), just ignore.

func _on_body_entered(body: Node2D) -> void:
	"""Called when this Area2D detects a 'monitorable' PhysicsBody (like a unit)."""
	
	if not body is CollisionObject2D:
		return
	
	# Check if the body's layer matches our mask
	if body.collision_layer & self.collision_mask:
		# Deal damage if the body can take it
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Destroy the projectile
		queue_free()
	# else: We hit a body we don't care about, just ignore.

func _on_lifetime_timeout() -> void:
	# Projectile flew for too long, destroy self
	queue_free()
