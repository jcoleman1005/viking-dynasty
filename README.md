# Viking Dynasty

A strategic Viking settlement and raid management game built with Godot 4.5. Command Viking raiders, build and manage settlements, and expand your dynasty across the medieval world.

## Game Overview

Viking Dynasty combines real-time strategy elements with settlement building and resource management. Players control Viking raiders in tactical missions while developing their home settlement for long-term growth and expansion.

### Key Features

- **Real-Time Strategy Combat**: Command Viking units in tactical raids and defensive battles
- **Settlement Building**: Construct and manage economic and defensive buildings with dynamic placement
- **Resource Management**: Collect, trade, and invest resources from successful raids
- **World Map Exploration**: Navigate regions and plan strategic campaigns
- **Dynasty Progression**: Build your Viking legacy through multiple generations
- **Dynamic Pathfinding**: AStarGrid2D-based unit navigation and building placement validation

## Technical Architecture

### Built With
- **Engine**: Godot 4.5
- **Language**: GDScript 4.x with full static typing
- **Architecture**: Modular component-based design with signal-driven communication
- **AI Integration**: GodotAiSuite addon for development assistance

### Core Systems

#### Autoload Singletons
- **EventBus**: Central signal system for decoupled communication across all game systems
- **SettlementManager**: Settlement data management, building placement, and pathfinding coordination
- **DynastyManager**: Long-term progression, character management, and legacy tracking
- **SceneManager**: Scene transitions, state management, and level loading
- **PauseManager**: Game pause, time control, and runtime management

#### Data Systems
- **Buildings**: Modular building system with economic and defensive types, grid-based placement
- **Units**: Typed unit data with stats, abilities, formation support, and AI behaviors
- **Settlements**: Persistent settlement data with resource tracking and save/load functionality
- **World Map**: Regional data, campaign progression, and strategic layer management
- **Characters**: Jarl traits, dynasty lineage system, and character progression
- **Missions**: Raid configuration, loot systems, and mission parameters

#### Game Modes
- **Settlement Bridge**: Home base building and management with economic systems
- **Raid Missions**: Tactical combat scenarios with loot collection and unit commands
- **World Map**: Strategic campaign layer with regional exploration
- **Defensive Micro**: Base defense scenarios with tower defense elements

### Recent Architecture Improvements
- **Enhanced Unit System**: PlayerVikingRaider and VikingRaider prefabs with specialized behaviors
- **Improved Combat**: AttackAI component system with projectile-based combat
- **Refined Grid Management**: Comprehensive pathfinding with proper bounds checking
- **Better Scene Organization**: Clear separation of concerns with scene-specific components
- **Advanced Input Mapping**: Custom input actions including debug features

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
│   ├── components/   # Reusable game components (AttackAI, etc.)
│   ├── effects/      # Visual effects and projectiles
│   ├── levels/       # Game levels and environments
│   ├── missions/     # Mission-specific scenes and logic
│   ├── units/        # Unit prefabs and behaviors
│   └── world_map/    # World map components
├── scripts/          # Additional scripts and utilities
│   ├── ai/          # AI systems and finite state machines
│   ├── buildings/   # Building logic and behaviors
│   ├── ui/          # User interface scripts
│   ├── units/       # Unit behaviors and controllers
│   └── utility/     # Helper scripts and tools
├── tools/            # Development and testing tools
└── ui/               # User interface components
```

## Getting Started

### Prerequisites
- **Godot 4.5+** (Recommended: Latest stable version)
- **GodotAiSuite addon** (included in project)

### Setup
1. Clone or download the project repository
2. Open in Godot 4.5 or later
3. The project includes the GodotAiSuite addon for AI-assisted development
4. Run the main scene to start development/testing
5. All scripts use modern GDScript 4.x syntax with static typing

### Development Tools
- **GridManager**: Visual grid editing for settlement layouts
- **Building Preview Cursor**: Real-time building placement system with validation
- **Runtime Inspector**: Debug runtime properties and behaviors during gameplay
- **Pause Menu**: Runtime game control and debugging interface

### Input Configuration
The project includes several configured input actions:
- **UI Controls**: Standard UI navigation and interaction
- **Debug Tools**: Time travel debugging (T key) for development
- **Pause System**: Escape key for pause menu access
- **Combat Controls**: Unit selection, movement, and attack commands

## Game Systems

### Settlement Management
- **Economic Buildings**: Generate resources over time with fixed payouts
- **Dynamic Placement**: Real-time building validation with grid-based positioning
- **Pathfinding Integration**: AStarGrid2D for unit navigation with obstacle avoidance
- **Resource Treasury**: Multi-resource economy with purchase/sale validation
- **Save/Load System**: Persistent settlement data with proper resource management

### RTS Combat
- **Unit Selection**: Drag-select multiple units with formation support
- **Tactical Commands**: Move, attack, and defensive orders through signal system
- **Real-time Physics**: CharacterBody2D-based unit movement with collision handling
- **AI Systems**: Finite state machine-based unit behaviors and decision making
- **Combat Mechanics**: Projectile system with damage calculation and visual effects

### World Map & Campaign
- **Regional Exploration**: Navigate different map areas and plan campaigns
- **MacroCamera System**: Strategic overview with zoom and pan controls
- **Mission Selection**: Choose from various raid and defensive scenarios
- **Progress Tracking**: Persistent world state and campaign advancement

### Event & Signal Architecture
- **EventBus System**: Centralized communication hub for all game systems
- **Decoupled Design**: Signal-based system communication with minimal dependencies
- **Command Pattern**: RTS commands routed through EventBus for better organization
- **State Management**: Scene-aware data persistence with proper cleanup

## Code Standards

### GDScript 4.x Best Practices
```gdscript
# Modern static typing throughout
extends CharacterBody2D
class_name VikingRaider

@export var max_health: int = 100
@export var move_speed: float = 150.0
@onready var health_bar: ProgressBar = $UI/HealthBar

# Signal-driven communication
signal unit_died(unit: VikingRaider)
signal health_changed(new_health: int, max_health: int)

var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		health_changed.emit(health, max_health)
		if health <= 0:
			unit_died.emit(self)

# Modern Godot 4.x physics
func _physics_process(delta: float) -> void:
	if target_position != Vector2.ZERO:
		velocity = global_position.direction_to(target_position) * move_speed
		move_and_slide()
```

### Architecture Principles
- **Component-Based Design**: Modular systems with clear, typed interfaces
- **Signal Communication**: Loose coupling through EventBus and direct signals
- **Data-Driven Configuration**: Resource-based game data with proper type safety
- **Scene Composition**: Reusable prefabs and templates with proper inheritance
- **Error Handling**: Comprehensive validation with informative error messages

### Development Standards
- **Static Typing Required**: All variables and function parameters must be typed
- **Modern Syntax Only**: Use @export, @onready, extends patterns consistently
- **Signal Architecture**: Prefer signals over direct method calls for system communication
- **Resource Management**: Proper cleanup with queue_free() and null checking
- **Documentation**: Self-documenting code with clear variable names and comments

## Layer Organization

The project uses a well-defined collision layer system:
- **Layer 1**: Environment (static obstacles and terrain)
- **Layer 2**: Player_Units (player-controlled units)
- **Layer 3**: Enemy_Units (AI-controlled units)
- **Layer 4**: Enemy_Buildings (defensive structures and targets)

## Contributing

### Development Workflow
1. **Analyze First**: Use project analysis tools to understand existing systems
2. **Search Before Creating**: Look for existing implementations to extend or improve
3. **Fix Before Build**: Prioritize improvements and debugging over new features
4. **Test Systematically**: Use automated testing tools and runtime validation
5. **Follow Architecture**: Maintain signal-driven, component-based design patterns

### Code Quality Gates
- All scripts must compile without errors or warnings
- Follow Godot naming conventions and scene organization standards
- Maintain signal-driven architecture for system communication
- Write self-documenting code with proper type hints and clear naming
- Test changes with both automated tools and manual gameplay verification

## Current Development Status

### Completed Systems ✅
- Core settlement building mechanics with grid-based placement
- RTS unit selection and movement with pathfinding
- Resource management and economy with save/load
- Basic combat system with projectiles and damage
- Event-driven architecture with comprehensive signal system
- Unit prefab system with PlayerVikingRaider and VikingRaider variants
- AttackAI component for automated combat behaviors
- World map foundation with region-based exploration

### Active Development 🚧
- Advanced AI behaviors and tactical decision making
- UI/UX polish and game balance improvements
- Performance optimization and code quality enhancements
- Extended building types and economic complexity
- Mission system expansion with varied objectives

### Planned Features 📋
- Dynasty progression and character development
- Advanced formation systems and unit abilities
- Multiplayer support and networking
- Modding support and custom content tools
- Platform-specific optimizations and builds

## License

[Specify your license here]

---

**Built with Godot 4.5 and modern game development practices**

*This project demonstrates professional-grade architecture with signal-driven communication, static typing, and modular component design suitable for commercial game development.*
