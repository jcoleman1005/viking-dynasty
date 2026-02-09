#res://scenes/units/UnitDebugger.gd
extends Node2D
class_name UnitDebugger

# --- CONFIG ---
@export var font_size: int = 12
@export var show_visuals: bool = true

# --- REFS ---
var parent: CharacterBody2D
var stuck_detector: Node
var label: Label

func _ready() -> void:
	# 1. Attach to Parent
	parent = get_parent() as CharacterBody2D
	if not parent:
		set_process(false)
		return

	# 2. Find StuckDetector (Sibling)
	stuck_detector = parent.get_node_or_null("StuckDetector")
	
	# 3. Setup UI Label
	label = Label.new()
	label.scale = Vector2(0.5, 0.5) # Make text crisp but small
	label.position = Vector2(-20, -50)
	label.modulate = Color.YELLOW
	add_child(label)
	
	# Ensure we draw on top of the sprite
	z_index = 100 

func _process(_delta: float) -> void:
	if not show_visuals: 
		label.text = ""
		return
		
	queue_redraw()
	_update_label()

func _update_label() -> void:
	var mask_val = parent.collision_mask
	var vel_len = parent.velocity.length()
	
	var status = "OK"
	if stuck_detector:
		if stuck_detector.is_phasing: status = "PHASING"
		elif stuck_detector.stuck_count > 0: status = "STUCK (%d)" % stuck_detector.stuck_count
	
	var txt = "ID: %s\n" % parent.name
	txt += "Vel: %.1f\n" % vel_len
	txt += "Mask: %d (Layer 1=%s)\n" % [mask_val, "ON" if mask_val & 1 else "OFF"]
	txt += "State: %s" % status
	
	# Show Collision Info
	var slide_count = parent.get_slide_collision_count()
	if slide_count > 0:
		var collider = parent.get_slide_collision(0).get_collider()
		txt += "\nHit: %s" % (collider.name if collider else "null")
		
	label.text = txt

func _draw() -> void:
	if not show_visuals: return
	
	# 1. Draw Velocity (Green Arrow)
	if parent.velocity.length() > 10.0:
		draw_line(Vector2.ZERO, parent.velocity.normalized() * 30.0, Color.GREEN, 2.0)
	
	# 2. Draw Target (Red Line)
	if "formation_target" in parent and parent.formation_target != Vector2.ZERO:
		var local_target = to_local(parent.formation_target)
		# Only draw if reasonably close
		if local_target.length() < 500:
			draw_line(Vector2.ZERO, local_target, Color.RED, 1.0)
			draw_circle(local_target, 3.0, Color.RED)

# --- DEEP SCAN TRIGGER ---
func _unhandled_input(event: InputEvent) -> void:
	# Press 'P' while hovering mouse over unit to print detailed logs
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var mouse_pos = get_global_mouse_position()
		if parent.global_position.distance_to(mouse_pos) < 30.0:
			_print_deep_scan()

func _print_deep_scan() -> void:
	print("\n=== 🕵️ UNIT DIAGNOSTIC: %s ===" % parent.name)
	print("Position:      ", parent.global_position)
	print("Target (Form): ", parent.get("formation_target"))
	print("Velocity:      %s (Speed: %.2f)" % [parent.velocity, parent.velocity.length()])
	print("Collision Mask:%d (Binary: %s)" % [parent.collision_mask, String.num_int64(parent.collision_mask, 2)])
	
	if stuck_detector:
		print("--- STUCK DETECTOR ---")
		print("Is Phasing:    ", stuck_detector.is_phasing)
		print("Stuck Count:   ", stuck_detector.stuck_count)
		print("Last Check Pos:", stuck_detector.last_pos)
		print("Dist Moved:    ", parent.global_position.distance_to(stuck_detector.last_pos))
	
	var count = parent.get_slide_collision_count()
	print("--- PHYSICS ---")
	print("Slide Collisions: ", count)
	for i in range(count):
		var col = parent.get_slide_collision(i)
		print("  [%d] Hit: %s (Layer: %d)" % [i, col.get_collider().name, col.get_collider().collision_layer])
	print("================================\n")
