# Viking Dynasty - Project Status & Memories

## Core Systems & Refactors

### 1. Clan Labor Refactor (Phase 1-5) - COMPLETE
- **Households as Social Units**: Households now have named heads (PatronymicGenerator), lineage tracking, and automatic succession.
- **Seasonal Oaths**: Labor is assigned via "Seasonal Oaths" (BUILD, RAID, FARM, etc.) in the `ClanAllocationMenu`.
- **Loyalty & Tradition**: 
    - Loyalty (0-100) affects labor efficiency and determines mortality priority during crises.
    - Disloyal households may refuse specific oaths (Raid/Build).
    - Tradition provides a +5% efficiency bonus per year for households remaining on the same oath.
- **Raid Social Impact**: Implemented "Raid Jealousy" where non-raiders lose loyalty if a raid is successful, while raiders gain it.

### 2. Construction Decree System - COMPLETE
- **Workflow**: Introduced a multi-stage construction process: Issue Decree -> Authorize (assign household & pay) -> Seal (place building).
- **ConstructionAuthority**: New autoload managing the decree lifecycle and tile reservation (BFS-based survey).
- **UI/UX**: 
    - `BuildMenu` updated for decree selection.
    - `BuildingPreviewCursor` supports visual footprints and reservation logic.
    - `DecreeAuthorizationPopup` for assigning specific households to projects.

### 3. Settlement Stability & Persistence - UPDATED
- **Loading Guards**: `SettlementManager` now includes legacy save sanitization (auto-injecting missing rationing and sickness data) to prevent crashes.
- **Scene Safety**: Transitioned to `WeakRef` for active scene nodes (`active_building_container`, `active_tilemap_layer`) to prevent null-instance errors during scene transitions.
- **Terrain Validation**: Improved isometric coordinate math and terrain-aware placement (e.g., Great Hall water buffers).

### 4. Technical Debt & Cleanup
- **Legacy Pruning**: Removed the seasonal `Debugger` and obsolete worker-pool signals/UI.
- **UI Modernization**: Updated `MainGameUI` with specific task buttons (e.g., `BtnFarming`) and cleaned up resource dependencies in seasonal ledger scenes.

### 5. Summer Turn-Based Day System - COMPLETE
- **Daily Cycle**: Summer now consists of a fixed number of days (`SUMMER_DAYS = 12`).
- **Orchestration**: `DynastyManager.advance_day()` manages the increment, signal emission, and event checks.
- **UI Integration**: The main advancement button now reflects the current day (e.g., "Next Day (1/12)") during Summer and intercepts clicks to advance the day until the limit is reached.
- **Event Hook**: `EventManager.check_daily_events()` now filters events by `trigger_season` and `trigger_day` defined in `EventData.gd`, allowing for precise event timing.
- **Persistence**: Event history is now stored directly in `JarlData`, ensuring unique events remain unique across save/load cycles.
- **Campaign Flags**: Added `campaign_flags` to `JarlData` to support future multi-event story arcs and state-based triggers.

## Pending Tasks (TODOs)

### Core Gameplay & Simulation
- **Winter Day System**: Implement a turn-based day cycle for Winter (e.g., `WINTER_DAYS = 6`) to match the Summer mechanic (`DynastyManager.gd`).
- **Construction Progress**: Add incremental progress bar updates to reflect daily building progress in the UI (`EconomyManager.gd`).
- **Save Loading Investigation**: Investigate redundant calls to `_on_settlement_loaded` during game start (`EconomyManager.gd`).

### UI & Economics
- **Autumn Ledger**: Fully implement the financial snapshot and seasonal ledger UI (transactions, categories, and totals) (`EconomyManager.gd`).
- **Resource Caps**: Implement and enforce storage and population capacity limits across all systems (`EconomyManager.gd`).
- **Event Consequences**: Hook up event effect keys (e.g., `great_feast`, `burial_rite`) to actual treasury deductions/additions and UI feedback (`EventManager.gd`).

### Unit Behavior & Visuals
- **Animation Roadmap**: Implement task-specific worker animations:
    - Harvesting: Walking between Great Hall and resource buildings.
    - Construction: Perimeter patrolling and timed stops.
    - Raiding: Formation marching (`Base_Unit.gd`).
- **Inventory & Encumbrance**: Connect `get_speed_multiplier()` to unit inventory weight (`UnitFSM.gd`).
- **Logic Consolidation**: Unify resource gathering and pillaging logic between units and the `EconomyManager` (`UnitFSM.gd`).

## Current Context (Feb 17, 2026)
- **Active Branch**: `Winter-Refactor`
- **Focus**: Integrating social systems with economic gameplay and hardening the save/load pipeline.
