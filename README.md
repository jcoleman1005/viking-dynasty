# Viking Dynasty

A strategic Viking settlement and raid management game built with Godot 4.5. Command Viking raiders, build and manage settlements, and expand your dynasty across the medieval world.

## Game Overview

Viking Dynasty combines real-time strategy elements with settlement building and resource management. Players control Viking raiders in tactical missions while developing their home settlement for long-term growth and expansion.

### Key Features

- **Real-Time Strategy Combat**: Command Viking units in tactical raids and defensive battles
- **Settlement Building**: Construct and manage economic and defensive buildings
- **Resource Management**: Collect, trade, and invest resources from successful raids
- **World Map Exploration**: Navigate regions and plan strategic campaigns
- **Dynasty Progression**: Build your Viking legacy through multiple generations

## Technical Architecture

### Built With
- **Engine**: Godot 4.5
- **Language**: GDScript 4.x with full static typing
- **Architecture**: Modular component-based design with signal-driven communication
- **AI Integration**: GodotAiSuite addon for development assistance

### Core Systems

#### Autoload Singletons
- **EventBus**: Central signal system for decoupled communication
- **SettlementManager**: Settlement data management and building systems
- **DynastyManager**: Long-term progression and character management
- **SceneManager**: Scene transitions and state management
- **PauseManager**: Game pause and time control

#### Data Systems
- **Buildings**: Modular building system with economic and defensive types
- **Units**: Typed unit data with stats, abilities, and formations
- **Settlements**: Persistent settlement data with resource tracking
- **World Map**: Regional data and campaign progression
- **Characters**: Jarl traits and dynasty lineage system

#### Game Modes
- **Settlement Bridge**: Home base building and management
- **Raid Missions**: Tactical combat scenarios
- **World Map**: Strategic campaign layer
- **Defensive Micro**: Base defense scenarios

## Project Structure

```
res://
├── addons/           # Editor plugins (GodotAiSuite)
├── autoload/         # Global singleton systems
├── data/             # Game data resources
│   ├── buildings/    # Building configurations and types
│   ├── characters/   # Jarl and character data
│   ├── missions/     # Mission and raid parameters
│   ├── settlements/  # Settlement templates and saves
│   ├── traits/       # Character trait definitions
│   ├── units/        # Unit stats and configurations
│   └── world_map/    # Regional and campaign data
├── player/           # Player controllers and camera systems
├── scenes/           # Scene files organized by type
│   ├── buildings/    # Building prefabs and components
│   ├── levels/       # Game levels and environments
│   ├── missions/     # Mission-specific scenes and logic
│   ├── units/        # Unit prefabs and behaviors
│   └── world_map/    # World map components
├── scripts/          # Additional scripts and utilities
├── tools/            # Development and testing tools
└── ui/               # User interface components
```

## Getting Started

### Prerequisites
- Godot 4.5 or later
- GodotAiSuite addon (included)

### Setup
1. Clone or download the project
2. Open in Godot 4.5+
3. The project includes the GodotAiSuite addon for AI-assisted development
4. Run the main scene to start development/testing

### Development Tools
- **Phase1TestRunner**: Automated testing for core systems
- **GridManager**: Visual grid editing for settlement layouts
- **Building Preview Cursor**: Real-time building placement system

## Game Systems

### Settlement Management
- **Economic Buildings**: Generate resources over time
- **Pathfinding Integration**: AStarGrid2D for unit navigation
- **Dynamic Placement**: Real-time building validation and preview
- **Resource Treasury**: Multi-resource economy system

### RTS Combat
- **Unit Selection**: Drag-select multiple units
- **Formation System**: Organized unit movements
- **Tactical Commands**: Move, attack, and defensive orders
- **Real-time Physics**: CharacterBody2D-based unit movement

### Event System
- **Decoupled Architecture**: Signal-based system communication
- **Command Pattern**: RTS commands through EventBus
- **State Management**: Scene-aware data persistence
- **Error Handling**: Comprehensive validation and logging

## Code Standards

### GDScript 4.x Patterns
```gdscript
# Static typing throughout
extends CharacterBody2D
class_name VikingRaider

@export var max_health: int = 100
@onready var health_bar: ProgressBar = $UI/HealthBar

# Signal-driven communication
signal unit_died(unit: VikingRaider)
signal health_changed(new_health: int, max_health: int)

# Modern Godot 4.x physics
func _physics_process(delta: float) -> void:
	if target_position != Vector2.ZERO:
		velocity = global_position.direction_to(target_position) * move_speed
		move_and_slide()
```

### Architecture Principles
- **Component-Based Design**: Modular systems with clear interfaces
- **Signal Communication**: Loose coupling through EventBus
- **Data-Driven Configuration**: Resource-based game data
- **Scene Composition**: Reusable prefabs and templates

## Contributing

### Development Workflow
1. **Analyze First**: Use project analysis tools to understand existing systems
2. **Search Before Creating**: Look for existing implementations to extend
3. **Fix Before Build**: Prioritize improvements over new features
4. **Test Systematically**: Use automated testing tools

### Code Quality
- All scripts use static typing and modern GDScript 4.x syntax
- Follow Godot naming conventions and scene organization
- Maintain signal-driven architecture for system communication
- Write self-documenting code with clear variable names

## License

[Specify your license here]

## Development Status

Currently in active development with focus on:
- Core settlement building mechanics
- RTS combat system refinement  
- World map and campaign progression
- UI/UX polish and game balance

---

**Built with Godot 4.5 and modern game development practices**
