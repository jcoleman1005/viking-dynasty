#res://autoload/ProjectilePoolManager.gd
# res://autoload/ProjectilePoolManager.gd
#
# Manages an object pool of projectiles to avoid the performance
# cost of instantiating and freeing them during gameplay.

extends Node

# Set this to the scene your game uses for projectiles.
@export var projectile_scene: PackedScene = preload("res://scenes/effects/Projectile.tscn")
@export var initial_pool_size: int = 50

# This array holds the projectiles that are "on the shelf" and ready to be used.
var available_projectiles: Array[Projectile] = []

# This node just holds all projectiles so they exist in the scene tree.
var projectile_container: Node

func _ready() -> void:
	projectile_container = Node.new()
	projectile_container.name = "ProjectileContainer"
	add_child(projectile_container)
	
	# Pre-load the pool with an initial batch of projectiles
	for i in range(initial_pool_size):
		var p = projectile_scene.instantiate() as Projectile
		projectile_container.add_child(p)
		p.return_to_pool() # Deactivate it and move it off-screen
		available_projectiles.append(p)
	
	Loggie.msg("ProjectilePoolManager: Initialized with %d projectiles." % initial_pool_size).domain("RTS").info()

func get_projectile() -> Projectile:
	"""
	Retrieves an available projectile from the pool.
	If the pool is empty, it creates a new one.
	"""
	if not available_projectiles.is_empty():
		# Get a projectile from the "shelf"
		return available_projectiles.pop_front()
	else:
		# The "shelf" is empty. This isn't ideal, but we can
		# create a new one on-the-fly to prevent errors.
		push_warning("ProjectilePoolManager: Pool depleted! Creating a new projectile.")
		var p = projectile_scene.instantiate() as Projectile
		projectile_container.add_child(p)
		return p

func return_projectile(projectile: Projectile) -> void:
	"""
	Returns a projectile to the pool, making it available again.
	"""
	projectile.return_to_pool()
	available_projectiles.append(projectile)
