# Viking Dynasty

A strategic Viking settlement and raid management game built with Godot 4.x.

## Project Structure

```
res://
├── addons/           # Editor plugins and extensions
├── ai/              # AI-related scripts and data
├── assets/          # Art, audio, and media files  
├── autoload/        # Singleton scripts and scenes
├── data/            # Game data resources
│   ├── buildings/   # Building data and configurations
│   ├── missions/    # Mission and raid data
│   ├── settlements/ # Settlement data and templates
│   └── units/       # Unit stats and configurations
├── docs/            # Documentation and guides
├── formations/      # Military formation data
├── placeholders/    # Placeholder assets for development
├── player/          # Player controller and camera systems
├── scenes/          # All scene files organized by type
│   ├── buildings/   # Building scene prefabs
│   ├── levels/      # Game levels and environments
│   ├── missions/    # Mission-specific scenes
│   ├── units/       # Unit scene prefabs
│   └── world_map/   # World map components
├── scripts/         # GDScript files mirroring scene structure
├── textures/        # Texture resources and materials
├── themes/          # UI themes and styling
├── tools/           # Development tools and utilities
└── ui/              # User interface components
```

## Development Notes

- Built with Godot 4.x and GDScript 4.x
- Uses modern Godot patterns and typed GDScript
- Modular architecture with clear separation of concerns

## Getting Started

1. Open the project in Godot 4.x
2. Run the main scene to start development
3. Check `/docs` for detailed implementation guides