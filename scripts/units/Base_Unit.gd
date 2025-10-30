# res://scenes/units/Base_Unit.gd
#
# --- MODIFIED: Added AttackTimer reference ---

class_name BaseUnit
extends CharacterBody2D

@export var data: UnitData
var fsm: UnitFSM
var current_health: int = 50

# --- ADDED ---
@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	if not data:
		push_warning("BaseUnit scene is missing its BuildingData resource.")
		return
	
	current_health = data.max_health
	
	# --- MODIFIED ---
	# Pass the timer reference to the FSM
	fsm = UnitFSM.new(self, attack_timer)
	
	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)

func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_grid_pos: Vector2i) -> void:
	if fsm and fsm.current_state == UnitFSM.State.MOVE:
		fsm.recalculate_path()

func _physics_process(delta: float) -> void:
	if fsm:
		fsm.update(delta)
	
	if not fsm or fsm.current_state != UnitFSM.State.MOVE:
		velocity = Vector2.ZERO
		move_and_slide()

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been killed." % data.display_name)
	queue_free()
