# Projectile Collision Fix Summary

## Problem Solved
Enemy projectiles in defensive missions were not colliding with or damaging player buildings.

## Root Cause
Buildings were not assigned to proper collision layers, so projectiles couldn't target them.

## Solution Implemented

### 1. Building Collision Layer Setup (Base_Building.gd)
- **Player Buildings**: Set to Layer 1 (bit value 1)
- **Enemy Buildings**: Set to Layer 4 (bit value 8, bit position 3)
- Added automatic group assignment for easy identification
- Buildings now report their layer assignment via debug output

### 2. Enemy Unit Collision Layer Setup (RaidMission.gd)
- **Enemy Units**: Set to Layer 3 (bit value 4, bit position 2) in _spawn_enemy_wave()
- Added debug output to confirm layer assignment

### 3. Projectile Debug Output (Projectile.gd)
- Added temporary debug output to show collision attempts
- Shows: target name, target layer, projectile mask, and collision match status
- Shows damage dealt when successful

## Collision Layer Architecture
```
Layer 1 (bit 0): Player Buildings     - collision_layer = 1
Layer 2 (bit 1): Player Units         - collision_layer = 2 (already set)
Layer 3 (bit 2): Enemy Units          - collision_layer = 4  
Layer 4 (bit 3): Enemy Buildings      - collision_layer = 8
```

## Target Masks (AttackAI sets these automatically)
```
Player Units target: Enemy Units (4) + Enemy Buildings (8) = 12 (0b1100)
Enemy Units target:  Player Units (2) + Player Buildings (1) = 3 (0b0011)
```

## Verification
The system now properly:
1. Sets building collision layers based on `data.is_player_buildable`
2. Sets enemy unit collision layers when spawned
3. Projects debug output to verify collisions
4. Deals damage and destroys projectiles on successful hits

## To Remove Debug Output Later
When satisfied the system works, remove these debug prints:
1. In `Base_Building.gd` _ready(): Remove collision layer print statements
2. In `RaidMission.gd` _spawn_enemy_wave(): Remove enemy unit layer print  
3. In `Projectile.gd` _on_body_entered(): Remove debug print lines

## Testing
Run a defensive mission and watch the console output to verify:
- Buildings report correct collision layers on spawn
- Enemy units report correct collision layers on spawn  
- Projectiles show collision attempts and successful hits
- Buildings take damage and are destroyed when health reaches 0