# 🏰 Settlement Layout Customization Guide

## 📍 **How Grid Coordinates Work**

The settlement uses a grid system where each building is placed at specific coordinates:
- `Vector2i(x, y)` where x=horizontal position, y=vertical position
- Grid starts at (0,0) in the top-left corner
- Typical settlement area spans from (0,0) to (20,20)

## 🏗️ **Available Buildings**

| Building Name | Resource Path | Grid Size |
|--------------|---------------|-----------|
| Great Hall | `res://data/buildings/Bldg_GreatHall.tres` | 3x2 |
| Wall | `res://data/buildings/Bldg_Wall.tres` | 1x1 |
| Lumber Yard | `res://data/buildings/LumberYard.tres` | 2x2 |
| Watchtower | `res://data/buildings/Monastery_Watchtower.tres` | 2x2 |
| Chapel | `res://data/buildings/Monastery_Chapel.tres` | 2x2 |
| Granary | `res://data/buildings/Monastery_Granary.tres` | 2x2 |
| Library | `res://data/buildings/Monastery_Library.tres` | 2x2 |
| Scriptorium | `res://data/buildings/Monastery_Scriptorium.tres` | 2x2 |

## 🎯 **Methods to Customize Layouts**

### Method 1: Edit .tres Files Directly
Edit `res://data/settlements/home_base_fixed.tres` and modify the `placed_buildings` array:

```gdscript
placed_buildings = Array[Dictionary]([
{
"resource_path": "res://data/buildings/Bldg_GreatHall.tres",
"grid_position": Vector2i(10, 8)
},
{
"resource_path": "res://data/buildings/Bldg_Wall.tres", 
"grid_position": Vector2i(8, 6)
}
])
```

### Method 2: Use Pre-made Layouts
Change the `home_base_data` in SettlementBridge scene inspector to:
- `res://data/settlements/home_base_fixed.tres` - Balanced starter base
- `res://data/settlements/fortress_layout.tres` - Heavy defense focus
- `res://data/settlements/monastery_layout.tres` - Economic/religious focus

### Method 3: Create Layouts Programmatically
Use the SettlementLayoutEditor.gd tool to generate custom layouts

### Method 4: In-Game Coordinate Finding
1. Run the game
2. Press SPACEBAR while hovering mouse over desired locations
3. Check console for grid coordinates: "CLICKED GRID COORDINATE: (x, y)"
4. Use these coordinates in your layout

## 📐 **Layout Planning Tips**

### Grid Reference (20x20):
```
   0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
0  . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
1  . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
2  . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
3  . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
4  . . . . W . . . . .  .  .  .  .  .  W  .  .  .  .
5  . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
6  . . . . . . . . W W  .  W  W  .  .  .  .  .  .  .
7  . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
8  . . . . . . . . . .  H  H  H  .  .  .  .  .  .  .
9  . . . . . . . . . .  H  H  H  .  .  .  .  .  .  .
10 . . . . . . L L . .  .  .  .  .  G  G  .  .  .  .
11 . . . . . . L L . .  .  .  .  .  G  G  .  .  .  .
12 . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .
```

Where: H=Great Hall (3x2), W=Wall (1x1), L=Lumber Yard (2x2), G=Granary (2x2)

### Strategic Placement:
- **Great Hall**: Central location (around 8-12, 6-10)
- **Walls**: Form defensive perimeters
- **Watchtowers**: Corner positions for maximum coverage
- **Economic buildings**: Protected inside walls
- **Resource buildings**: Near resources or edges

## ⚡ **Quick Setup Examples**

### Starter Settlement (Balanced):
```gdscript
# Great Hall at center
{"resource_path": "res://data/buildings/Bldg_GreatHall.tres", "grid_position": Vector2i(10, 8)},
# Basic wall protection
{"resource_path": "res://data/buildings/Bldg_Wall.tres", "grid_position": Vector2i(8, 6)},
{"resource_path": "res://data/buildings/Bldg_Wall.tres", "grid_position": Vector2i(12, 6)},
# One economic building
{"resource_path": "res://data/buildings/LumberYard.tres", "grid_position": Vector2i(6, 10)}
```

### Fortress Settlement (Defense):
```gdscript
# Great Hall protected in center
{"resource_path": "res://data/buildings/Bldg_GreatHall.tres", "grid_position": Vector2i(10, 10)},
# Wall perimeter
{"resource_path": "res://data/buildings/Bldg_Wall.tres", "grid_position": Vector2i(6, 6)},
{"resource_path": "res://data/buildings/Bldg_Wall.tres", "grid_position": Vector2i(14, 6)},
# Corner watchtowers
{"resource_path": "res://data/buildings/Monastery_Watchtower.tres", "grid_position": Vector2i(5, 5)},
{"resource_path": "res://data/buildings/Monastery_Watchtower.tres", "grid_position": Vector2i(15, 5)}
```

## 🎮 **Implementation Steps**

1. **Plan your layout** using the grid reference
2. **Choose your method** (file editing, pre-made, or tool)
3. **Set coordinates** for each building
4. **Test in-game** to verify placement
5. **Adjust as needed** using the spacebar coordinate finder

The grid system makes it easy to create organized, strategic settlement layouts!
