# Viking Dynasty

A strategic Viking settlement and raid management game built with Godot 4.5. Command Viking raiders, build and manage settlements, and expand your dynasty across the medieval world.

## Game Overview

Viking Dynasty combines real-time strategy elements with settlement building and resource management. Players control Viking raiders in tactical missions while developing their home settlement for long-term growth and expansion.

### Key Features

- **Real-Time Strategy Combat**: Command Viking units in tactical raids and defensive battles with advanced AI systems
- **Settlement Building**: Construct and manage economic and defensive buildings with dynamic grid-based placement
- **Resource Management**: Collect, trade, and invest resources from successful raids with persistent economy
- **World Map Exploration**: Navigate regions and plan strategic campaigns across the Viking world
- **Dynasty Progression**: Build your Viking legacy through multiple generations with character traits and inheritance
- **Dynamic Pathfinding**: AStarGrid2D-based unit navigation with intelligent obstacle avoidance
- **Formation Combat**: Squad-based tactical formations with coordinated unit behaviors

## Technical Architecture

### Built With
- **Engine**: Godot 4.5 with GL Compatibility features
- **Language**: GDScript 4.x with full static typing and modern syntax
- **Architecture**: Modular component-based design with signal-driven communication
- **AI Integration**: GodotAiSuite addon for AI-assisted development and code generation

### Core Systems

#### Autoload Singletons
- **EventBus**: Central signal system for decoupled communication across all game systems
- **SettlementManager**: Settlement data management, building placement validation, and pathfinding coordination (313 lines)
- **DynastyManager**: Dynasty progression, character management, trait systems, and legacy tracking (253 lines)
- **SceneManager**: Scene transitions, state management, and level loading coordination
- **PauseManager**: Game pause, time control, and runtime debugging interface
- **EventManager**: Event system coordination and management
- **ProjectilePoolManager**: Performance-optimized projectile spawning and recycling system

#### Advanced Systems
- **Unit AI**: Comprehensive finite state machine with 302-line UnitFSM for tactical behaviors
- **Attack Systems**: Sophisticated AttackAI component (288 lines) with projectile-based combat
- **Formation Management**: Squad-based formation system (290 lines) with coordinated movement
- **Raid Management**: Complex raid mission system (433 lines) with objective management (228 lines)
- **Settlement Bridge**: Advanced building management (295 lines) with economic integration

#### Data Architecture
- **Buildings**: Modular building system with Base_Building (256 lines), economic and defensive types
- **Characters**: Comprehensive Jarl system (316 lines) with traits, heirs, and dynasty progression  
- **Units**: Typed unit data with specialized PlayerVikingRaider and EnemyVikingRaider implementations
- **World Map**: Regional data with macro-level strategic management (272 lines)
- **Missions**: Raid configuration with loot systems and dynamic objective generation

#### Game Modes & Levels
- **Settlement Bridge**: Home base building with comprehensive economic and defensive systems
- **Raid Missions**: Tactical combat scenarios with objective-based gameplay and loot collection
- **World Map**: Strategic campaign layer with region exploration and macro-level planning
- **Defensive Micro**: Base defense scenarios with tower defense elements

### Recent Architecture Improvements
- **Enhanced AI Systems**: Advanced UnitFSM with state-based behaviors and tactical decision making
- **Modular Combat System**: AttackAI component-based architecture for reusable attack behaviors across units and buildings
- **Improved Combat**: Projectile-based combat system with sophisticated damage calculation and ProjectilePoolManager optimization
- **Squad Formations**: Coordinated unit movement with formation maintenance and tactical positioning
- **Building Preview**: Real-time building placement with visual validation (301 lines)
- **UI Systems**: Comprehensive StorefrontUI (410 lines) and DynastyUI for player interaction

## Project Structure

```
res://
├── addons/           # Editor plugins and AI assistance
│   └── GodotAiSuite/ # AI-powered development tools
├── autoload/         # Global singleton systems
│   ├── DynastyManager.gd        # Dynasty and character progression
│   ├── EventBus.gd              # Central signal communication
│   ├── EventManager.gd          # Event system coordination
│   ├── PauseManager.gd          # Runtime control and debugging
│   ├── ProjectilePoolManager.gd # Performance-optimized projectile management
│   ├── SceneManager.gd          # Scene state management
│   └── SettlementManager.gd     # Building and pathfinding
├── data/             # Game data resources and configurations
│   ├── buildings/    # Building definitions and economic data
│   ├── characters/   # Jarl data, traits, and heir management
│   ├── legacy/       # Dynasty upgrade and progression systems
│   ├── missions/     # Raid parameters and loot configuration
│   ├── settlements/  # Settlement templates and saved data
│   ├── traits/       # Character trait definitions and effects
│   ├── units/        # Unit statistics and combat parameters
│   └── world_map/    # Regional data and campaign progression
├── player/           # Player control systems
│   ├── RTSCamera.gd     # Strategic camera with zoom and pan
│   └── RTSController.gd # RTS input handling and unit commands
├── scenes/           # Scene files organized by functionality
│   ├── buildings/    # Building prefabs and placement systems
│   ├── components/   # Reusable components (AttackAI, etc.)
│   ├── effects/      # Visual effects and projectile systems
│   ├── levels/       # Game environments and battle arenas
│   ├── missions/     # Mission-specific scenes and objectives
│   ├── units/        # Unit prefabs with AI behaviors
│   └── world_map/    # Strategic map components and regions
├── scripts/          # Additional game logic and utilities
│   ├── ai/          # Advanced AI systems and state machines
│   ├── buildings/   # Settlement management and construction
│   ├── formations/  # Squad tactics and unit coordination
│   ├── ui/          # User interface controllers and menus
│   ├── units/       # Unit behaviors and combat systems
│   ├── utility/     # Helper scripts and development tools
│   └── world_map/   # Strategic layer and campaign management
├── tools/            # Development and level editing tools
│   ├── EnemyBaseEditor.gd       # Enemy base layout designer
│   └── SettlementLayoutEditor.gd # Settlement planning tool
├── ui/               # User interface components and themes
│   ├── DynastyUI.gd         # Dynasty management interface
│   ├── StorefrontUI.gd      # Economic trading interface
│   └── SelectionBox.gd      # RTS unit selection system
```

## Getting Started

### Prerequisites
- **Godot 4.5+** (Recommended: Latest stable version with GL Compatibility)
- **GodotAiSuite addon** (included in project for AI-assisted development)

### Setup
1. Clone or download the project repository
2. Open in Godot 4.5 or later
3. The project auto-configures with GodotAiSuite for AI development assistance
4. All autoloads are pre-configured for immediate functionality
5. Scripts use modern GDScript 4.x with comprehensive static typing

### Development Tools
- **Settlement Layout Editor**: Visual settlement design and planning tool
- **Enemy Base Editor**: Design and test enemy base configurations  
- **Building Preview Cursor**: Real-time placement validation with grid snapping
- **GridManager**: Visual grid editing for precise settlement layouts
- **Runtime Inspector**: Debug runtime properties during gameplay

### Input Configuration
The project includes comprehensive input mapping:
- **UI Controls**: Complete navigation and interaction system
- **Debug Tools**: Time travel debugging with 'T' key for development
- **Pause System**: Escape key for comprehensive pause menu access
- **RTS Controls**: Unit selection, movement, and tactical commands
- **Formation Commands**: Squad management and tactical positioning

## Game Systems

### Settlement Management
- **Economic Buildings**: Resource generation with time-based payouts and upgrade paths
- **Dynamic Placement**: Real-time validation with AStarGrid2D pathfinding integration
- **Resource Treasury**: Multi-resource economy with purchase/sale validation and market dynamics
- **Save/Load System**: Persistent settlement data with complete resource state management
- **Building Preview**: Visual placement system with collision detection and grid snapping

### Advanced RTS Combat
- **Unit Selection**: Drag-select with formation support and multi-unit coordination
- **Tactical Commands**: Move, attack, and defensive orders through comprehensive signal system
- **Formation Combat**: Squad-based tactics with coordinated movement and positioning
- **AI Systems**: Multi-state finite state machine for intelligent unit behaviors
- **Combat Mechanics**: Projectile-based damage with visual effects and tactical depth

### Dynasty & Character Progression
- **Jarl Management**: Comprehensive character system with traits, abilities, and inheritance
- **Dynasty Progression**: Multi-generational advancement with legacy upgrades
- **Character Traits**: Dynamic trait system affecting gameplay and strategic options
- **Heir System**: Succession planning with trait inheritance and character development

### World Map & Campaign
- **Regional Exploration**: Navigate diverse map areas with strategic significance
- **MacroCamera System**: Strategic overview with smooth zoom and pan controls
- **Mission Selection**: Varied raid scenarios with dynamic objective generation
- **Progress Tracking**: Persistent world state with campaign advancement

### Event & Signal Architecture
- **EventBus System**: Centralized communication hub reducing system dependencies
- **Decoupled Design**: Signal-based architecture enabling modular system expansion
- **Command Pattern**: RTS commands routed through EventBus for clean organization
- **State Management**: Scene-aware data persistence with proper resource cleanup

## Code Standards

### GDScript 4.x Best Practices
```gdscript
# Modern static typing throughout
extends CharacterBody2D
class_name VikingRaider

@export var max_health: int = 100
@export var move_speed: float = 150.0
@export var combat_range: float = 50.0
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var attack_ai: AttackAI = $AttackAI

# Signal-driven communication
signal unit_died(unit: VikingRaider)
signal health_changed(new_health: int, max_health: int)
signal combat_state_changed(in_combat: bool)

var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		health_changed.emit(health, max_health)
		if health <= 0:
			unit_died.emit(self)

# Modern Godot 4.x physics with formation support
func _physics_process(delta: float) -> void:
	if target_position != Vector2.ZERO:
		var direction: Vector2 = global_position.direction_to(target_position)
		velocity = direction * move_speed
		move_and_slide()
		
		if global_position.distance_to(target_position) < 5.0:
			target_position = Vector2.ZERO
```

### Architecture Principles
- **Component-Based Design**: Modular systems with AttackAI, UnitFSM, and specialized components
- **Signal Communication**: Loose coupling through EventBus and direct signal connections
- **Data-Driven Configuration**: Resource-based game data with comprehensive type safety
- **Scene Composition**: Reusable prefabs with proper inheritance hierarchies
- **Error Handling**: Comprehensive validation with informative debugging output

### Development Standards
- **Static Typing Required**: All variables and function parameters must include explicit types
- **Modern Syntax Only**: Consistent use of @export, @onready, extends patterns throughout
- **Signal Architecture**: EventBus-first design with direct signals for component communication
- **Resource Management**: Proper cleanup with queue_free() and comprehensive null checking
- **Documentation**: Self-documenting code with clear naming and contextual comments

## Layer Organization

The project uses a comprehensive collision layer system:
- **Layer 1**: Environment (static obstacles, terrain, and world geometry)
- **Layer 2**: Player_Units (player-controlled units with pathfinding)
- **Layer 3**: Enemy_Units (AI-controlled units with tactical behaviors)
- **Layer 4**: Enemy_Buildings (defensive structures and raid targets)
- **Layer 5**: Projectiles (combat projectiles with collision detection)

## Contributing

### Development Workflow
1. **Analyze First**: Use project analysis tools to understand existing system architecture
2. **Search Before Creating**: Leverage search tools to find and extend existing implementations
3. **Fix Before Build**: Prioritize debugging and enhancement over new feature creation
4. **Test Systematically**: Use automated compilation checking and runtime validation
5. **Follow Architecture**: Maintain signal-driven, component-based design patterns consistently

### Code Quality Gates
- All scripts must compile without errors or warnings using static analysis
- Follow Godot 4.x naming conventions and scene organization standards
- Maintain EventBus-driven architecture for all inter-system communication
- Write self-documenting code with proper type hints and descriptive naming
- Validate changes with both automated tools and comprehensive gameplay testing

## Current Development Status

### Completed Systems ✅
- **Core Settlement**: Complete building mechanics with grid-based placement and pathfinding
- **Advanced RTS**: Unit selection, movement, formation combat with sophisticated AI
- **Resource Economy**: Comprehensive management with persistent save/load functionality
- **Combat Systems**: Projectile-based combat with AttackAI component and tactical depth (see `ATTACKAI_USAGE.md` for detailed guide)
- **Event Architecture**: Complete signal-driven communication with EventBus coordination
- **AI Systems**: Multi-state finite state machines with tactical decision making
- **Dynasty Management**: Character progression with traits, heirs, and legacy systems
- **World Map**: Strategic layer with region exploration and campaign management

### Active Development 🚧
- **UI/UX Enhancement**: Polishing StorefrontUI and DynastyUI for improved user experience
- **Performance Optimization**: Code quality improvements and system efficiency enhancements
- **Advanced AI**: Expanding tactical behaviors and strategic decision making systems
- **Mission Variety**: Expanding raid objectives and scenario diversity
- **Balance Tuning**: Economic systems and combat mechanics refinement

### Planned Features 📋
- **Multiplayer Support**: Network architecture and synchronized gameplay
- **Advanced Formations**: Extended tactical options and battlefield strategies
- **Modding Framework**: Custom content tools and extensible game systems
- **Platform Optimization**: Builds optimized for multiple target platforms
- **Campaign Expansion**: Extended world map with deeper strategic gameplay

## Development Statistics

- **Total Scripts**: 50+ GDScript files with comprehensive static typing
- **Core Systems**: 7 autoloaded singletons managing global game state
- **Major Components**: AttackAI (288 lines), UnitFSM (302 lines), SquadFormation (290 lines)
- **Data Systems**: Comprehensive character system with 316-line JarlData implementation
- **UI Systems**: Advanced interfaces including 410-line StorefrontUI
- **Architecture**: Signal-driven design with EventBus coordination across all systems



## License

[Specify your license here]

---

**Built with Godot 4.5 and professional game development practices**

*This project demonstrates commercial-grade architecture with signal-driven communication, comprehensive static typing, component-based design, and AI-assisted development workflows suitable for professional game development.*
