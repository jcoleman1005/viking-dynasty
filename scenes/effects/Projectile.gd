#res://scenes/effects/Projectile.gd
# res://scenes/effects/Projectile.gd
class_name Projectile
extends Area2D

# Projectile properties
var damage: int = 0
var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var firer: Node2D = null

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	# Connect signals if not already connected (safety for pooling)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Default state - ensure "off" by default
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	
	if lifetime_timer:
		lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int, projectile_speed: float = 400.0, collision_mask_value: int = 0) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	damage = projectile_damage
	speed = projectile_speed
	
	# Rotate visual
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# --- CRITICAL FIX: Defer ALL physics state changes ---
	# Because setup() often runs during a physics callback (e.g. _on_body_entered),
	# direct assignments to collision properties will fail silently.
	
	set_deferred("collision_mask", collision_mask_value)
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)
	
	show()
	
	# We also defer enabling the process loop to keep it in sync with physics
	call_deferred("set_physics_process", true)
	
	if lifetime_timer:
		lifetime_timer.start()

func return_to_pool() -> void:
	"""Deactivates the projectile and hides it."""
	# Defer disabling physics to avoid locking errors
	set_deferred("monitoring", false)
	set_deferred("collision_mask", 0) # Reset mask to clean state
	call_deferred("set_physics_process", false)
	
	hide()
	if lifetime_timer:
		lifetime_timer.stop()
	
	# Move far away to ensure no lingering collisions while deferral processes
	global_position = Vector2(-5000, -5000) 

func _on_area_entered(area: Area2D) -> void:
	# Check collision mask manually as a fallback, though physics engine handles it
	if area.collision_layer & self.collision_mask:
		_handle_impact(area.get_parent())

func _on_body_entered(body: Node2D) -> void:
	if body.collision_layer & self.collision_mask:
		_handle_impact(body)

func _handle_impact(target: Node2D) -> void:
	if not target: return
	
	if target.has_method("take_damage"):
		if is_instance_valid(firer):
			target.take_damage(damage, firer)
		else:
			target.take_damage(damage, null)
	
	# Return to pool
	ProjectilePoolManager.return_projectile(self)

func _on_lifetime_timeout() -> void:
	ProjectilePoolManager.return_projectile(self)
