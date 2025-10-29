# res://autoload/EventBus.gd
#
# A global Singleton (Autoload) that acts as a central "switchboard"
# for decoupled signal communication between major systems.
#
# Systems can emit signals on this bus, and other systems can
# listen for them, without ever needing a direct reference to each other.
extends Node

# This signal will be emitted by the UI (Build Menu)
# and listened for by the SettlementManager.
# GDD Ref:
signal build_request_made(building_data: BuildingData, grid_position: Vector2i)

# We will add many more signals here, for example:
# signal unit_spawn_requested(unit_data: UnitData)
# signal unit_killed(unit: BaseUnit)
# signal building_destroyed(building: BaseBuilding)
# signal wave_started(wave_number: int)
