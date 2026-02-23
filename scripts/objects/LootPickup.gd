# res://scripts/objects/LootPickup.gd
class_name LootPickup
extends Area2D

var loot_data: Dictionary = {}
var despawn_timer: float = 30.0
var _age: float = 0.0

const PICKUP_RADIUS: float = 30.0
const COLOR_GOLD = Color(1.0, 0.85, 0.0, 0.9)
const COLOR_FOOD = Color(0.4, 0.9, 0.3, 0.9)

func _ready() -> void:
    # Collision setup — detect player units only
    collision_layer = 0
    collision_mask = 2  # LAYER_PLAYER
    monitoring = true
    monitorable = false
    
    # Create collision shape
    var shape = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = PICKUP_RADIUS
    shape.shape = circle
    add_child(shape)
    
    # Connect
    body_entered.connect(_on_body_entered)
    
    queue_redraw()

func _process(delta: float) -> void:
    _age += delta
    if _age >= despawn_timer:
        queue_free()
    # Pulse effect
    modulate.a = 0.6 + 0.4 * sin(_age * 3.0)

func _draw() -> void:
    var color = COLOR_GOLD
    if loot_data.has("food") and not loot_data.has("gold"):
        color = COLOR_FOOD
    draw_circle(Vector2.ZERO, 8.0, color)
    draw_circle(Vector2.ZERO, 10.0, color * 0.7, false, 2.0)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player_units"): return
    if not body.has_method("add_loot"): return
    
    var picked_up_any = false
    for type in loot_data.keys():
        var amount = loot_data[type]
        if amount <= 0: continue
        var taken = body.add_loot(type, amount)
        if taken > 0:
            loot_data[type] -= taken
            picked_up_any = true
            Loggie.msg("Loot picked up: %s +%d by %s" % [
                type, taken, body.name]
            ).domain("RAID").info()
    
    # Remove empty entries
    for type in loot_data.keys():
        if loot_data.has(type) and loot_data[type] <= 0:
            loot_data.erase(type)
    
    if loot_data.is_empty():
        queue_free()
