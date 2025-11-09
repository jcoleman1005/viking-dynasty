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
# --- REMOVED: This variable was causing the bug ---
# var valid_collision_mask: int = 0
# --------------------------------------------------

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	# Connect signals in code
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _physics_process(delta: float) -> void:
	# Move in straight line
	global_position += direction * speed * delta

func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int, projectile_speed: float = 400.0, collision_mask: int = 0) -> void:
	"""
	Initialize the projectile with all necessary parameters.
	
	Args:
		start_position: Where the projectile starts
		target_position: Where to aim (calculates direction)
		projectile_damage: Damage to deal on hit
		projectile_speed: How fast the projectile moves
		collision_mask: What collision layers this projectile can hit
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

func _on_body_entered(body: Node2D) -> void:
	# Check if this body is on a layer we're supposed to hit
	if body is CharacterBody2D or body is RigidBody2D or body is StaticBody2D:
		var body_layer = 0
		if body.has_method("get_collision_layer"):
			body_layer = body.get_collision_layer()
		elif "collision_layer" in body:
			body_layer = body.collision_layer
		
		# --- THIS IS THE FIX ---
		# We check against self.collision_mask, which was set in setup(),
		# not the old, uninitialized 'valid_collision_mask' variable.
		if body_layer & self.collision_mask:
		# --- END FIX ---
			
			# Deal damage if the body can take it
			if body.has_method("take_damage"):
				body.take_damage(damage)
			
			# Destroy the projectile
			queue_free()

func _on_lifetime_timeout() -> void:
	# Projectile flew for too long, destroy self
	queue_free()
