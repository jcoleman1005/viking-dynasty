# res://scenes/units/Base_Unit.gd
#
# --- MODIFIED: Added AttackTimer reference and visual tweening by state ---

class_name BaseUnit
extends CharacterBody2D

signal destroyed

@export var data: UnitData
var fsm: UnitFSM
var current_health: int = 50

# Node refs
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D

# Color tweening
var _color_tween: Tween
const STATE_COLORS := {
	UnitFSM.State.IDLE: Color(0.3, 0.6, 1.0),     # Blue
	UnitFSM.State.MOVING: Color(0.4, 1.0, 0.4),   # Green
	UnitFSM.State.ATTACKING: Color(1.0, 0.3, 0.3) # Red
}
const ERROR_COLOR := Color(0.7, 0.3, 1.0)        # Purple

func _ready() -> void:
	if not data:
		push_warning("BaseUnit scene is missing its BuildingData resource.")
		return
	
	current_health = data.max_health
	
	# Pass the timer reference to the FSM
	fsm = UnitFSM.new(self, attack_timer)
	
	# Initialize visual to current state color (IDLE by default)
	sprite.modulate = STATE_COLORS.get(UnitFSM.State.IDLE, Color.WHITE)
	
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)

func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_grid_pos: Vector2i) -> void:
	if fsm and fsm.current_state == UnitFSM.State.MOVING:
		fsm._recalculate_path()

func _physics_process(delta: float) -> void:
	if fsm:
		fsm.update(delta)
	
	if not fsm or fsm.current_state != UnitFSM.State.MOVING:
		velocity = Vector2.ZERO
		move_and_slide()

# --- Visual State Hooks ---
func on_state_changed(state: UnitFSM.State) -> void:
	var to_color: Color = STATE_COLORS.get(state, Color.WHITE)
	_tween_color(to_color, 0.2)

func flash_error_color() -> void:
	# Quick flash to purple, then return to current state color
	var back_color: Color = STATE_COLORS.get(fsm.current_state, Color.WHITE)
	var t := create_tween()
	t.tween_property(sprite, "modulate", ERROR_COLOR, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate", back_color, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tween_color(to_color: Color, duration: float = 0.2) -> void:
	if _color_tween and _color_tween.is_running():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(sprite, "modulate", to_color, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been killed." % data.display_name)
	destroyed.emit()
	queue_free()

# --- RTS Command Interface ---

func command_move_to(target_pos: Vector2) -> void:
	"""Command this unit to move to a position"""
	if fsm:
		fsm.command_move_to(target_pos)

func command_attack(target: Node2D) -> void:
	"""Command this unit to attack a target"""
	if fsm:
		fsm.command_attack(target)

# --- Selection System ---

var is_selected: bool = false

func set_selected(selected: bool) -> void:
	"""Set the unit's selection state"""
	is_selected = selected
	
	if is_selected:
		_show_selection_indicator()
		print("%s selected" % data.display_name)
	else:
		_hide_selection_indicator()
		print("%s deselected" % data.display_name)

func _show_selection_indicator() -> void:
	"""Show visual selection indicator"""
	queue_redraw()

func _hide_selection_indicator() -> void:
	"""Hide visual selection indicator"""
	queue_redraw()

func _draw() -> void:
	"""Draw unit-specific visuals"""
	if is_selected:
		# Draw selection circle around the unit
		var radius = 25.0
		var color = Color.YELLOW
		color.a = 0.8
		draw_circle(Vector2.ZERO, radius, color, false, 3.0)
