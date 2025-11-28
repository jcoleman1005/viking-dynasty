extends Resource

class_name PortraitPartData

@export_enum("BODY", "HEAD", "EYE", "MOUTH", "NOSE", "HAIR_BACK", "CLOTHES", "BEARD", "HAIR_FRONT", "ACCESSORY")
var part_type: String = "HEAD"

@export var texture: Texture2D

@export var tags: Array[String] = []

@export_enum("skin", "hair", "clothing", "none")
var color_category: String = "none"
