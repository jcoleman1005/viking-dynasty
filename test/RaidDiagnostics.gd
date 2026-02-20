# res://test/RaidDiagnostics.gd
extends Node

## Standalone signal monitor for Fyrd wave debugging.
## Attach as child of RaidSandbox. Connects directly 
## to RaidObjectiveManager signals to verify they fire.

var obj_mgr: Node = null

func _ready() -> void:
    # Wait one frame for scene tree to settle
    await get_tree().process_frame
    
    # Find RaidObjectiveManager
    obj_mgr = _find_node_recursive(get_tree().root, "RaidObjectiveManager")
    
    if not obj_mgr:
        Loggie.msg("DIAG: Could not find RaidObjectiveManager!").domain("RAID").error()
        return
    
    Loggie.msg("DIAG: Found RaidObjectiveManager: %s" % str(obj_mgr)).domain("RAID").info()
    
    # Connect to ALL relevant signals independently
    if obj_mgr.has_signal("smoke_signal_triggered"):
        obj_mgr.smoke_signal_triggered.connect(func(): 
            Loggie.msg("DIAG: smoke_signal_triggered EMITTED").domain("RAID").warn())
        Loggie.msg("DIAG: Connected to smoke_signal_triggered").domain("RAID").info()
    
    if obj_mgr.has_signal("wave1_fyrd_arrived"):
        obj_mgr.wave1_fyrd_arrived.connect(func(): 
            Loggie.msg("DIAG: wave1_fyrd_arrived EMITTED").domain("RAID").warn())
        Loggie.msg("DIAG: Connected to wave1_fyrd_arrived").domain("RAID").info()
    else:
        Loggie.msg("DIAG: wave1_fyrd_arrived signal DOES NOT EXIST").domain("RAID").error()
    
    if obj_mgr.has_signal("wave2_fyrd_arrived"):
        obj_mgr.wave2_fyrd_arrived.connect(func(): 
            Loggie.msg("DIAG: wave2_fyrd_arrived EMITTED").domain("RAID").warn())
        Loggie.msg("DIAG: Connected to wave2_fyrd_arrived").domain("RAID").info()
    else:
        Loggie.msg("DIAG: wave2_fyrd_arrived signal DOES NOT EXIST").domain("RAID").error()
    
    # Also check what connections RaidMission has made
    var raid_mission = get_parent().get_node_or_null("RaidMission")
    if raid_mission:
        Loggie.msg("DIAG: RaidMission found").domain("RAID").info()
        Loggie.msg("DIAG: RaidMission has _on_wave1_fyrd: %s" % str(raid_mission.has_method("_on_wave1_fyrd"))).domain("RAID").info()
        Loggie.msg("DIAG: wave1 signal connections: %s" % str(obj_mgr.wave1_fyrd_arrived.get_connections())).domain("RAID").info()
        Loggie.msg("DIAG: wave2 signal connections: %s" % str(obj_mgr.wave2_fyrd_arrived.get_connections())).domain("RAID").info()

func _process(_delta: float) -> void:
    if not obj_mgr: return
    
    # Log state changes
    if obj_mgr.smoke_active:
        if int(obj_mgr.smoke_timer) % 30 == 0 and int(obj_mgr.smoke_timer) > 0:
            var t = int(obj_mgr.smoke_timer)
            if Engine.get_process_frames() % 60 == 0:
                Loggie.msg("DIAG: smoke_timer=%ds wave1_spawned=%s wave2_spawned=%s" % [
                    t, str(obj_mgr.wave1_spawned), str(obj_mgr.wave2_spawned)]
                ).domain("RAID").info()

func _find_node_recursive(node: Node, target_name: String) -> Node:
    if node.name == target_name:
        return node
    for child in node.get_children():
        var result = _find_node_recursive(child, target_name)
        if result:
            return result
    return null
