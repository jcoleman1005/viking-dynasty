class_name RaidMenu
extends MarginContainer

## Component: RaidMenu
## Entry point for Raid mechanics.
## Instantiated by BottomBar.

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------

@onready var status_label: Label = %StatusLabel

# ------------------------------------------------------------------------------
# PUBLIC INTERFACE
# ------------------------------------------------------------------------------

func setup(_args = null) -> void:
	# verified: RaidManager exists (Source 738)
	if RaidManager:
		# verified: outbound_raid_force is an array property (Source 739)
		var force_size = RaidManager.outbound_raid_force.size()
		
		# Update UI with status
		status_label.text = "Raid Force: %d Warbands Ready" % force_size
		
		# Optional: Add tooltip hint
		if force_size == 0:
			status_label.tooltip_text = "Draft Warbands in the Settlement before heading out."
	else:
		status_label.text = "Raid Manager Unavailable"
		Loggie.msg("RaidManager singleton missing").domain(Loggie.LogDomains.UI).error()

# ------------------------------------------------------------------------------
# INTERNAL LOGIC
# ------------------------------------------------------------------------------

func _on_open_map_pressed() -> void:
	# verified: GameScenes.WORLD_MAP exists (Source 1348)
	# verified: EventBus.scene_change_requested exists (Source 713)
	if GameScenes:
		EventBus.scene_change_requested.emit(GameScenes.WORLD_MAP)
	else:
		Loggie.msg("GameScenes singleton missing").domain(Loggie.LogDomains.UI).error()
