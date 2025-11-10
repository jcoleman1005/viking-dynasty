# AttackAI Component Usage Guide

The AttackAI component provides modular attack behavior that can be attached to any unit or building.

## Features

- **Modular Design**: Attach to any Node2D-based unit or building
- **Data-Driven Configuration**: Automatically configures from UnitData or BuildingData resources
- **Smart Targeting**: Closest target selection with collision layer filtering
- **Ranged/Melee Support**: Handles both projectile-based and direct damage attacks
- **Signal-Based**: Emits signals for attack events (great for visual effects)

## Basic Usage

### For Buildings (Defensive Structures)

Buildings automatically create and configure AttackAI when `data.is_defensive_structure = true`:

```gdscript
# The building handles this automatically in _setup_defensive_ai()
var attack_ai_scene = preload("res://scenes/components/AttackAI.tscn")
attack_ai = attack_ai_scene.instantiate()
add_child(attack_ai)

# Configure from building data
attack_ai.configure_from_data(data)

# Set target mask to attack player units (Layer 2)
var player_collision_mask: int = 1 << 1  # Layer 2
attack_ai.set_target_mask(player_collision_mask)
```

### For Units

Units need to be modified to use AttackAI instead of built-in attack logic:

```gdscript
# In BaseUnit or similar
@onready var attack_ai: AttackAI = $AttackAI  # Add as child in scene

func _ready():
    # Configure AI from unit data
    if attack_ai:
        attack_ai.configure_from_data(data)
        
        # Set target mask to attack enemies (Layers 3 and 4)
        var enemy_collision_mask: int = (1 << 2) | (1 << 3)
        attack_ai.set_target_mask(enemy_collision_mask)

# Update UnitFSM to use AttackAI instead of timer-based attacking
var fsm = UnitFSM.new(self, attack_ai)
```

## Configuration

### Automatic Configuration from Data Resources

```gdscript
# Both UnitData and BuildingData support these properties:
@export var attack_damage: int = 10
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0  # attacks per second
@export var projectile_scene: PackedScene  # null = melee, assigned = ranged
```

### Manual Configuration

```gdscript
# Set properties directly
attack_ai.attack_damage = 25
attack_ai.attack_range = 300.0
attack_ai.attack_speed = 2.0  # 2 attacks per second
attack_ai.projectile_scene = preload("res://scenes/effects/Arrow.tscn")

# Update collision mask
attack_ai.set_target_mask(enemy_mask)
```

## Collision Layer Setup

- **Layer 2**: Player Units
- **Layer 3-4**: Enemy Units
- **Layer 10**: Projectiles

### For Player Units/Buildings:
```gdscript
var enemy_mask = (1 << 2) | (1 << 3)  # Target layers 3 & 4
attack_ai.set_target_mask(enemy_mask)
```

### For Enemy Buildings:
```gdscript
var player_mask = 1 << 1  # Target layer 2
attack_ai.set_target_mask(player_mask)
```

## API Reference

### Methods

- `configure_from_data(data_resource)` - Auto-configure from UnitData/BuildingData
- `set_target_mask(mask: int)` - Set collision layers to target
- `force_target(target: Node2D)` - Force attack specific target
- `stop_attacking()` - Stop all attack behavior

### Signals

- `attack_started(target: Node2D)` - Emitted when starting to attack
- `attack_stopped()` - Emitted when stopping attack (no targets)
- `about_to_attack(target: Node2D, damage: int)` - Emitted before each attack

### Properties

- `attack_damage: int` - Damage per attack
- `attack_range: float` - Attack range in pixels
- `attack_speed: float` - Attacks per second
- `projectile_scene: PackedScene` - Projectile to spawn (null = melee)
- `target_collision_mask: int` - What layers to target

## Examples

### Archer Unit
```gdscript
# UnitData configuration
attack_damage = 15
attack_range = 400.0
attack_speed = 1.5
projectile_scene = preload("res://scenes/effects/Arrow.tscn")
```

### Melee Warrior
```gdscript
# UnitData configuration
attack_damage = 30
attack_range = 50.0
attack_speed = 0.8
projectile_scene = null  # null = melee
```

### Watchtower Building
```gdscript
# BuildingData configuration
is_defensive_structure = true
attack_damage = 20
attack_range = 500.0
attack_speed = 1.0
projectile_scene = preload("res://scenes/effects/Rock.tscn")
```

## Migration from Old System

### Before (UnitFSM with timer):
```gdscript
# Old approach - built into FSM
enum State { IDLE, MOVING, ATTACKING }
var attack_timer: Timer
func _on_attack_timer_timeout(): # Complex logic here
```

### After (AttackAI component):
```gdscript
# New approach - modular component
enum State { IDLE, MOVING }  # No ATTACKING state needed
var attack_ai: AttackAI
# AttackAI handles all attack logic
```

This modular approach makes attack behavior reusable, testable, and easier to maintain!