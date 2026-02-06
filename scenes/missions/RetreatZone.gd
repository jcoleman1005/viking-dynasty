#res://scenes/missions/RetreatZone.gd
# res://scenes/missions/RetreatZone.gd
class_name RetreatZone
extends Area2D

signal unit_evacuated(unit: BaseUnit)

# Visuals
const COLOR_FILL = Color(0.2, 1.0, 0.2, 0.2) # Transparent Green
const COLOR_BORDER = Color(0.2, 1.0, 0.2, 0.8) # Solid Green Border

func _ready() -> void:
	# 1. Setup Collision
	# We only want to detect Player Units (Layer 2)
	collision_layer = 0 
	collision_mask = 2 
	monitorable = false
	monitoring = true
	
	body_entered.connect(_on_body_entered)
	
	# 2. Ensure we are visible for drawing
	z_index = 0 
	queue_redraw()

func _draw() -> void:
	# Draw the visual box matching the collision shape (200x200)
	# defined in RaidMission.gd
	var rect = Rect2(-100, -100, 200, 200)
	
	# Fill
	draw_rect(rect, COLOR_FILL, true)
	# Border
	draw_rect(rect, COLOR_BORDER, false, 3.0)
	
	# Optional Label
	var font = ThemeDB.get_fallback_font()
	draw_string(font, Vector2(-30, 5), "RETREAT", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func _on_body_entered(body: Node2D) -> void:
	# 1. Handle Soldiers with Loot
	if body.has_method("add_loot"): # Duck typing for BaseUnit
		var unit = body as BaseUnit
		if not unit.inventory.is_empty():
			_bank_unit_inventory(unit)
			
	# 2. Handle Retreating Units (Evacuation)
	# If a unit is explicitly in RETREATING state, we might despawn them to save them
	if body.get("fsm") and body.fsm.current_state == UnitAIConstants.State.RETREATING:
		_evacuate_unit(body)

func _bank_unit_inventory(unit: BaseUnit) -> void:
	var total_value = 0
	
	for type in unit.inventory:
		var amount = unit.inventory[type]
		if amount > 0:
			EventBus.raid_loot_secured.emit(type, amount)
			total_value += amount
			
			# Juice
			EventBus.floating_text_requested.emit("+%d %s" % [amount, type.capitalize()], unit.global_position, Color.GOLD)
	
	# Clear the unit's backpack so they can go steal more
	unit.inventory.clear()
	unit.current_loot_weight = 0
	
	if total_value > 0:
		print("RetreatZone: Secured loot from %s" % unit.name)

func _evacuate_unit(unit: BaseUnit) -> void:
	if unit.is_queued_for_deletion(): return
	
	# 1. Visual Feedback (Fade out)
	var tween = create_tween()
	tween.tween_property(unit, "modulate:a", 0.0, 0.5)
	
	# 2. Disable Logic (Stop moving/colliding immediately)
	unit.set_physics_process(false)
	unit.set_process(false)
	unit.collision_layer = 0
	unit.collision_mask = 0
	
	# 3. Notify System
	Loggie.msg("RetreatZone: Unit escaped -> %s" % unit.name).domain("RAID").info()
	unit_evacuated.emit(unit)
	
	# 4. Cleanup after fade
	tween.tween_callback(unit.queue_free)
