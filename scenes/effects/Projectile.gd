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
var firer: Node2D = null # --- NEW: This replaces using 'owner' ---

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	self.monitoring = true
	self.monitorable = false
	lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int, projectile_speed: float = 400.0, collision_mask: int = 0) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	damage = projectile_damage
	speed = projectile_speed
	self.collision_mask = collision_mask
	
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	"""Called when this Area2D detects a 'monitorable' Area2D (like our Hitbox)."""
	
	if area.collision_layer & self.collision_mask:
		var parent_body = area.get_parent()
		if parent_body and parent_body.has_method("take_damage"):
			# --- MODIFIED: Pass 'firer' instead of 'owner' ---
			parent_body.take_damage(damage, firer)
			queue_free()
		else:
			push_warning("Projectile hit non-damagable Area: '%s'." % area.name)

func _on_body_entered(body: Node2D) -> void:
	"""Called when this Area2D detects a 'monitorable' PhysicsBody (like a unit)."""
	
	if not body is CollisionObject2D:
		return
	
	if body.collision_layer & self.collision_mask:
		if body.has_method("take_damage"):
			# --- MODIFIED: Pass 'firer' instead of 'owner' ---
			body.take_damage(damage, firer)
		
		queue_free()

func _on_lifetime_timeout() -> void:
	queue_free()
