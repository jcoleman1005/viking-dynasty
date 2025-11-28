# res://scenes/ui/PortraitGenerator.gd
@tool
class_name PortraitGenerator
extends Control

# --- Node References ---
# We removed @onready to manually ensure this populates even in tests
var layers: Dictionary = {}

# --- Configuration ---
const PARTS_PATH = "res://data/portraits/parts/"

func _ready() -> void:
	_setup_layers()
	_clear_portrait()

func _setup_layers() -> void:
	# If layers are already grabbed, don't do it again
	if not layers.is_empty(): return
	
	# We use get_node_or_null to be safe, though $Name works too if children exist
	layers = {
		"BACKGROUND": $Background,
		"BODY": $Body,
		"HEAD": $Head,
		"HAIR_BACK": $HairBack,
		"FACE_DETAILS": $FaceDetails,
		"CLOTHES": $Clothes,
		"BEARD": $Beard,
		"HAIR_FRONT": $HairFront,
		"ACCESSORY": $Accessory
	}

## Main entry point. Pass a JarlData.portrait_config dictionary here.
func build_portrait(config: Dictionary) -> void:
	# Critical: Ensure layers are mapped before we try to use them
	_setup_layers()
	_clear_portrait()
	
	for key: String in config.keys():
		if key.ends_with("_id"):
			var part_id = config[key]
			_load_and_apply_part(part_id, config)

## Loads a specific part resource and applies it to the correct layer
func _load_and_apply_part(part_id: String, full_config: Dictionary) -> void:
	if part_id == "": return
	
	var path = PARTS_PATH + part_id + ".tres"
	if not ResourceLoader.exists(path):
		# Only warn if not in editor mode to avoid spamming while typing
		if not Engine.is_editor_hint():
			Loggie.msg("PortraitGenerator: Part not found at %s" % path).domain(LogDomains.UI).warn()
		return
		
	var part_data = load(path) as PortraitPartData
	if not part_data: return
	
	if not layers.has(part_data.part_type):
		push_warning("PortraitGenerator: Unknown part type '%s'" % part_data.part_type)
		return
		
	var target_node = layers[part_data.part_type] as TextureRect
	if not target_node: return
	
	# 2. Apply Texture
	target_node.texture = part_data.texture
	
	# 3. Apply Color
	var tint = Color.WHITE
	
	match part_data.color_category:
		"skin":
			tint = full_config.get("skin_color", Color.WHITE)
		"hair":
			tint = full_config.get("hair_color", Color.WHITE)
		"clothing":
			tint = full_config.get("primary_color", Color.WHITE)
		_:
			tint = Color.WHITE
			
	target_node.self_modulate = tint

func _clear_portrait() -> void:
	if layers.is_empty(): return
	
	for node in layers.values():
		if node is TextureRect:
			node.texture = null
			node.self_modulate = Color.WHITE
