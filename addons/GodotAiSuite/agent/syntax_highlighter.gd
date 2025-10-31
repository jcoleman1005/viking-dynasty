# res://addons/GodotAiSuite/agent/syntax_highlighter.gd
@tool
extends RefCounted
class_name GDSyntaxHighlighter

# --- Theme Colors (inspired by Godot's default script editor theme) ---
const COLOR_KEYWORD = Color("#CF844E")   # Godot Orange
const COLOR_TYPE = Color("#69A2E8")      # Godot Blue (Types)
const COLOR_STRING = Color("#E5D472")    # Godot Yellow
const COLOR_COMMENT = Color("#748089")   # Godot Gray
const COLOR_NUMBER = Color("#A4D383")    # Godot Green

# --- GDScript Definitions ---
const KEYWORDS = {
	"and": true, "as": true, "assert": true, "break": true, "breakpoint": true,
	"class": true, "class_name": true, "continue": true, "const": true,
	"elif": true, "else": true, "enum": true, "export": true, "extends": true,
	"for": true, "func": true, "if": true, "in": true, "is": true, "master": true,
	"mastersync": true, "match": true, "not": true, "onready": true, "or": true,
	"pass": true, "preload": true, "puppet": true, "puppetsync": true,
	"remote": true, "remotesync": true, "return": true, "rpc": true,
	"self": true, "setget": true, "signal": true, "static": true, "super": true,
	"tool": true, "var": true, "while": true, "yield": true,
}

const BUILTIN_TYPES = {
	"void": true, "bool": true, "int": true, "float": true, "String": true,
	"Vector2": true, "Vector2i": true, "Rect2": true, "Rect2i": true,
	"Vector3": true, "Vector3i": true, "Transform2D": true, "Plane": true,
	"Quaternion": true, "AABB": true, "Basis": true, "Transform3D": true,
	"Color": true, "NodePath": true, "RID": true, "Object": true,
	"Callable": true, "Dictionary": true, "Array": true, "PackedByteArray": true,
	"PackedInt32Array": true, "PackedInt64Array": true, "PackedFloat32Array": true,
	"PackedFloat64Array": true, "PackedStringArray": true, "PackedVector2Array": true,
	"PackedVector3Array": true, "PackedColorArray": true,
}

# --- Internal State ---
var _regex_cache: Dictionary = {}

# --- Public API ---
func highlight_gdscript_line(line: String) -> String:
	if line.is_empty():
		return ""

	var tokens: Array[Dictionary] = []
	
	# 1. Find all potential tokens. Order of finding doesn't matter yet.
	_find_tokens(line, _get_regex("comment", "#.*"), "comment", tokens)
	_find_tokens(line, _get_regex("string", "(\"[^\"]*\"|'[^']*')"), "string", tokens)
	_find_tokens(line, _get_regex("number", "\\b-?[0-9]+(\\.[0-9]+)?\\b"), "number", tokens)
	_find_tokens(line, _get_regex("word", "[A-Za-z_][A-Za-z0-9_]*"), "word", tokens)

	# 2. Filter overlapping tokens
	tokens.sort_custom(func(a, b): return a.start < b.start)
	var filtered_tokens: Array[Dictionary] = []
	var last_end: int = -1
	for token in tokens:
		if token.start >= last_end:
			filtered_tokens.append(token)
			last_end = token.end
			
	# 3. Build the final string from tokens
	var result_parts: Array[String] = []
	var current_pos: int = 0
	for token in filtered_tokens:
		# Append non-token text before the current token
		var pretext: String = line.substr(current_pos, token.start - current_pos)
		result_parts.append(pretext.replace("[", "[["))
		
		# Append the highlighted token
		var token_text: String = line.substr(token.start, token.end - token.start)
		var color: Color = _get_color_for_token(token, token_text)
		
		if color.a > 0: # Check if a color was assigned
			var safe_token_text: String = token_text.replace("[", "[[")
			result_parts.append("[color=%s]%s[/color]" % [color.to_html(false), safe_token_text])
		else:
			result_parts.append(token_text.replace("[", "[["))
		
		current_pos = token.end
		
	# Append any remaining text after the last token
	var posttext: String = line.substr(current_pos)
	result_parts.append(posttext.replace("[", "[["))
	
	return "".join(result_parts)

# --- Internal Logic ---
func _get_regex(key: String, pattern: String) -> RegEx:
	if not _regex_cache.has(key):
		var regex := RegEx.new()
		regex.compile(pattern)
		_regex_cache[key] = regex
	return _regex_cache[key]

func _find_tokens(line: String, regex: RegEx, type: String, tokens_array: Array) -> void:
	for match in regex.search_all(line):
		tokens_array.append({
			"start": match.get_start(),
			"end": match.get_end(),
			"type": type,
		})

func _get_color_for_token(token_data: Dictionary, token_text: String) -> Color:
	match token_data.type:
		"comment":
			return COLOR_COMMENT
		"string":
			return COLOR_STRING
		"number":
			return COLOR_NUMBER
		"word":
			if KEYWORDS.has(token_text):
				return COLOR_KEYWORD
			if BUILTIN_TYPES.has(token_text):
				return COLOR_TYPE
			# Custom class check (PascalCase convention)
			if not token_text.is_empty() and token_text[0] == token_text[0].to_upper() and not token_text[0].is_valid_int():
				return COLOR_TYPE
	
	return Color(0,0,0,0) # Return transparent color if no match
