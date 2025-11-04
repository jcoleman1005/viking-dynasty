# Enemy Base Editor - Visual Settlement Designer

A comprehensive GUI tool for creating and editing enemy settlements in Viking Dynasty.

## Overview

The Enemy Base Editor provides a visual interface for designing enemy settlements with:
- **Visual Grid Editor**: Click-and-place building system with live preview
- **Building Palette**: Categorized building selection with search and filtering
- **Property Panel**: Treasury and garrison management
- **Template System**: Pre-made settlement layouts for quick creation
- **Validation**: Error checking for overlaps and missing components
- **Save/Load**: Full file management for settlement data

## Features

### 🎯 Visual Grid Editor
- **32x32 cell grid** representing the game world (120x80 cells)
- **Click to place** buildings from the palette
- **Right-click to remove** buildings
- **Hover preview** showing placement validity
- **Real-time visual feedback** with colored indicators
- **Automatic building sprites** with fallback colored rectangles

### 🏗️ Building Palette
- **Categorized view**: Defensive, Economic, Religious, Residential, Utility
- **Search functionality**: Filter buildings by name
- **Building details**: Cost, health, stats displayed on each button
- **Visual selection**: Highlighted selected building
- **Auto-loading**: Discovers all building .tres files automatically

### ⚙️ Settlement Properties
- **Treasury Editor**: Gold, Wood, Food, Stone resource management
- **Garrison Editor**: Add/remove unit types with counts
- **Collapsible sections**: Organized UI with expandable groups
- **Live updates**: Changes immediately reflect in settlement data

### 📋 Templates System
- **Fortress**: Heavily fortified with walls, towers, strong defenses
- **Monastery**: Religious settlement with chapel, library, scriptorium
- **Village**: Basic settlement with economic buildings, minimal defenses
- **Outpost**: Small military outpost with basic walls and watchtower
- **Custom descriptions**: Each template includes usage guidelines

### ✅ Validation & Quality
- **Overlap detection**: Prevents buildings from being placed on same cell
- **Bounds checking**: Ensures buildings stay within grid limits
- **Essential building check**: Warns if settlement lacks main hall
- **Error reporting**: Clear dialog with specific issues listed

### 💾 File Management
- **New/Load/Save/Save As**: Complete file operations
- **Template loading**: Quick settlement creation from presets
- **Auto-format detection**: Works with existing .tres settlement files
- **File dialog**: Easy navigation to `res://data/settlements/`

## Usage Guide

### Getting Started
1. **Access**: The editor appears as a dock in the left panel when the plugin is enabled
2. **Create**: Click "New" to start a fresh settlement or "Templates" for presets
3. **Build**: Select buildings from the palette and click on the grid to place
4. **Configure**: Use the property panel to set treasury and garrison units
5. **Save**: Use "Save As" to create new settlement files

### Building Placement
- **Select**: Click a building in the palette (right panel)
- **Place**: Click on the grid where you want the building
- **Remove**: Right-click on placed buildings to remove them
- **Preview**: Hover to see green (valid) or red (invalid) placement indicators

### Templates
- **Load**: Click "Templates" in toolbar and select a preset
- **Confirm**: Review the description and confirm to replace current settlement
- **Customize**: Use templates as starting points, then modify as needed

### Validation
- **Check**: Click "Validate" to check for errors
- **Review**: Read the detailed error report in the popup
- **Fix**: Address each issue listed before using in game

## File Structure

```
res://addons/enemy_base_editor/
├── plugin.gd                    # Main plugin entry point
├── EnemyBaseEditorDock.gd      # Main editor interface
├── EnemyBaseEditorDock.tscn    # Editor scene file
├── SettlementGridEditor.gd     # Visual grid component
├── BuildingPalette.gd          # Building selection component
├── SettlementProperties.gd     # Property editing component
├── CollapsibleGroup.gd         # UI utility component
├── SettlementTemplates.gd      # Template system
└── README.md                   # This documentation
```

## Integration

### Data Compatibility
- **Seamless**: Works with existing `SettlementData` resources
- **No changes**: Uses current building and unit data structures
- **Backward compatible**: Settlements created manually still work
- **Forward compatible**: GUI-created settlements work in existing systems

### Existing Workflow
- **SettlementManager**: Settlements load normally in game
- **Building placement**: Uses same grid system as runtime
- **Unit garrison**: Compatible with recruitment system
- **Resource costs**: Matches existing economy

## Technical Details

### Grid System
- **Cell Size**: 32px visual, matches game's tile_size
- **Grid Bounds**: 120x80 cells (configurable in SettlementManager)
- **Coordinate System**: Vector2i grid positions
- **Validation**: Real-time bounds and overlap checking

### Building Data
- **Auto-discovery**: Scans `res://data/buildings/` for .tres files
- **Smart categorization**: Uses building properties to assign categories
- **Visual representation**: Shows textures or colored fallbacks
- **Cost display**: Shows build_cost dictionary in readable format

### Templates
- **Static generation**: Pre-configured SettlementData instances
- **Parameterized**: Easy to add new templates by extending SettlementTemplates
- **Descriptive**: Each template includes difficulty and usage notes

## Extending the System

### Adding New Templates
```gdscript
# In SettlementTemplates.gd
static func create_my_template() -> SettlementData:
    var settlement = SettlementData.new()
    settlement.treasury = {"gold": 500, "wood": 300, "food": 200, "stone": 150}
    settlement.placed_buildings = [
        {"grid_position": Vector2i(10, 10), "resource_path": "res://data/buildings/MyBuilding.tres"}
    ]
    settlement.garrisoned_units = {"res://data/units/MyUnit.tres": 5}
    return settlement
```

### Adding Building Categories
```gdscript
# In BuildingPalette.gd, update _get_building_category()
elif "custom" in name:
    return BuildingCategory.CUSTOM
```

### Custom Validation Rules
```gdscript
# In EnemyBaseEditorDock.gd, extend _validate_settlement()
# Add custom game-specific validation logic
if not has_essential_resource_buildings:
    errors.append("Settlement needs at least one economic building")
```

## Performance

- **Efficient**: Only redraws grid when needed
- **Scalable**: Handles large settlements (tested up to 100+ buildings)
- **Responsive**: UI updates in real-time without lag
- **Memory-conscious**: Cleans up sprites and dialogs properly

## Future Enhancements

- **Undo/Redo**: Already implemented but can be expanded
- **Copy/Paste**: Building selection and duplication
- **Multi-select**: Select and operate on multiple buildings
- **Export to scene**: Generate actual game scenes for testing
- **Advanced templates**: Procedural generation patterns
- **Building rotation**: Support for rotated building placement
- **Terrain layers**: Ground textures and environmental details

## Support

This tool integrates seamlessly with your existing Viking Dynasty settlement system. All settlements created in the GUI work exactly the same as manually created ones in your game logic.

The visual editor significantly speeds up enemy base creation while maintaining full compatibility with your current codebase.
