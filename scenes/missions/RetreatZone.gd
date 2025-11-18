# res://scenes/missions/RetreatZone.gd
class_name RetreatZone
extends Area2D

signal unit_evacuated(unit: BaseUnit)

func _ready() -> void:
	# Detect Player Units (Layer 2)
	collision_mask = 2 
	monitorable = false
	monitoring = true
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is BaseUnit and body.is_in_group("player_units"):
		_evacuate_unit(body)

func _evacuate_unit(unit: BaseUnit) -> void:
	# 1. LOGIC CLEANUP (Immediate)
	# Remove from group so the Mission Manager knows it's "Gone" even if visible
	unit.remove_from_group("player_units")
	
	# Disable physics so it stops moving/colliding
	unit.set_physics_process(false)
	unit.collision_layer = 0
	unit.collision_mask = 0
	
	# 2. NOTIFY SYSTEM
	Loggie.msg("Unit Escaped: %s" % unit.name).domain("RTS").info()
	unit_evacuated.emit(unit)
	
	# 3. VISUAL CLEANUP (Delayed)
	var tween = create_tween()
	tween.tween_property(unit, "modulate:a", 0.0, 0.5)
	tween.tween_callback(unit.queue_free)
