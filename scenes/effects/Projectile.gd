# res://scenes/effects/Projectile.gd
#
# A simple, straight-line projectile that applies damage on impact.
# Now integrated with ProjectilePoolManager.

class_name Projectile
extends Area2D

# Projectile properties
var damage: int = 0
var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var firer: Node2D = null

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# We must defer setting physics properties
	set_deferred("monitoring", true)
	
	self.monitorable = false
	lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int, projectile_speed: float = 400.0, collision_mask: int = 0) -> void:
	# This function now "wakes up" the projectile
	global_position = start_position
	direction = (target_position - start_position).normalized()
	damage = projectile_damage
	speed = projectile_speed
	self.collision_mask = collision_mask
	
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Activate the projectile
	show()
	set_physics_process(true)
	set_deferred("monitoring", true)
	lifetime_timer.start()

func return_to_pool() -> void:
	"""
	Deactivates the projectile and hides it, returning it to the pool.
	"""
	hide()
	set_physics_process(false)
	set_deferred("monitoring", false)
	lifetime_timer.stop()
	global_position = Vector2(-1000, -1000) # Move it off-screen

func _on_area_entered(area: Area2D) -> void:
	"""Called when this Area2D detects a 'monitorable' Area2D (like our Hitbox)."""
	
	if area.collision_layer & self.collision_mask:
		var parent_body = area.get_parent()
		if parent_body and parent_body.has_method("take_damage"):
			
			if is_instance_valid(firer):
				parent_body.take_damage(damage, firer)
			else:
				parent_body.take_damage(damage, null)
			
			ProjectilePoolManager.return_projectile(self)
		else:
			push_warning("Projectile hit non-damagable Area: '%s'." % area.name)

func _on_body_entered(body: Node2D) -> void:
	"""Called when this Area2D detects a 'monitorable' PhysicsBody (like a unit)."""
	
	if not body is CollisionObject2D:
		return
	
	if body.collision_layer & self.collision_mask:
		if body.has_method("take_damage"):
			if is_instance_valid(firer):
				body.take_damage(damage, firer)
			else:
				body.take_damage(damage, null)
		
		ProjectilePoolManager.return_projectile(self)

func _on_lifetime_timeout() -> void:
	ProjectilePoolManager.return_projectile(self)
