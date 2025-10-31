# res://addons/GodotAiSuite/agent/diff_view.gd
@tool
extends PanelContainer
class_name DiffView

const GDSyntaxHighlighterScript = preload("res://addons/GodotAiSuite/agent/syntax_highlighter.gd")

# --- UI Node References ---
@onready var _v_scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var _h_box_container: HBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer
@onready var _h_scroll_left: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/LeftPanel/CodeContainer/ScrollContainer
@onready var _h_scroll_right: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/RightPanel/CodeContainer/ScrollContainer
@onready var _line_numbers_left: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/LeftPanel/CodeContainer/LineNumbersLeft
@onready var _code_left: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/LeftPanel/CodeContainer/ScrollContainer/CodeLeft
@onready var _line_numbers_right: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/RightPanel/CodeContainer/LineNumbersRight
@onready var _code_right: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/RightPanel/CodeContainer/ScrollContainer/CodeRight

# --- Internal State ---
var _processed_diff: Array = []
var _old_content: String
var _new_content: String
var _syntax_highlighter


func _ready() -> void:
	# Connections must be deferred in @tool scripts
	if not is_node_ready():
		await ready

	# Defensively ensure BBCode is enabled, as it might fail to load from scene state.
	_line_numbers_left.bbcode_enabled = true
	_code_left.bbcode_enabled = true
	_line_numbers_right.bbcode_enabled = true
	_code_right.bbcode_enabled = true

	_syntax_highlighter = GDSyntaxHighlighterScript.new()

	# If show_diff() was called before this node was ready, the content
	# will be set. Render it now that the onready vars are available.
	_generate_and_render_diff()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	if not event.is_pressed():
		return

	if not (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		return
		
	# Check if the mouse is over one of the horizontal scroll containers
	var is_over_h_scroll = _h_scroll_left.get_global_rect().has_point(event.global_position) or \
						   _h_scroll_right.get_global_rect().has_point(event.global_position)
	
	if is_over_h_scroll:
		var v_scrollbar = _v_scroll_container.get_v_scroll_bar()
		# A reasonable scroll amount, can be adjusted
		var scroll_amount = v_scrollbar.page * 0.25 
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_v_scroll_container.scroll_vertical += scroll_amount
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_v_scroll_container.scroll_vertical -= scroll_amount
			
		get_viewport().set_input_as_handled()

# --- Public Methods ---
func show_diff(old_content: String, new_content: String) -> void:
	_old_content = old_content
	_new_content = new_content
	
	# If the node is already ready, render immediately.
	# Otherwise, _ready() will pick it up.
	if is_node_ready():
		_generate_and_render_diff()

# --- Rendering Logic ---
func _generate_and_render_diff() -> void:
	# Guard against being called before content is set or nodes are ready
	if not is_node_ready() or _old_content == null or _new_content == null:
		return
		
	var old_lines: PackedStringArray = _old_content.split("\n")
	var new_lines: PackedStringArray = _new_content.split("\n")
	var diff_lines: Array = _compute_diff(old_lines, new_lines)

	_process_diff_for_rendering(diff_lines)
	_render_diff()


func _process_diff_for_rendering(diff_lines: Array) -> void:
	_processed_diff.clear()
	# Directly convert each diff line into the processed format without any grouping.
	for line_data in diff_lines:
		_processed_diff.append({ "type": "line", "data": line_data })


func _render_diff() -> void:
	var left_num_builder: Array[String] = []
	var left_code_builder: Array[String] = []
	var right_num_builder: Array[String] = []
	var right_code_builder: Array[String] = []
	
	var left_line_num: int = 1
	var right_line_num: int = 1

	for item in _processed_diff:
		var line_data: Dictionary = item.data
		var status: String = line_data.status
		var highlighted_content: String = _syntax_highlighter.highlight_gdscript_line(line_data.content)
	
		match status:
			"eq":
				left_num_builder.append(str(left_line_num))
				left_code_builder.append("  " + highlighted_content)
				right_num_builder.append(str(right_line_num))
				right_code_builder.append("  " + highlighted_content)
				left_line_num += 1
				right_line_num += 1
			"del":
				left_num_builder.append("[color=#ffaaaa]" + str(left_line_num) + "[/color]")
				left_code_builder.append("[bgcolor=#402020]- " + highlighted_content + "[/bgcolor]")
				right_num_builder.append("")
				right_code_builder.append("[bgcolor=#252525] [/bgcolor]") # Filler line
				left_line_num += 1
			"add":
				left_num_builder.append("")
				left_code_builder.append("[bgcolor=#252525] [/bgcolor]") # Filler line
				right_num_builder.append("[color=#aaffaa]" + str(right_line_num) + "[/color]")
				right_code_builder.append("[bgcolor=#204020]+ " + highlighted_content + "[/bgcolor]")
				right_line_num += 1

	_line_numbers_left.bbcode_text = "\n".join(left_num_builder)
	_code_left.bbcode_text = "\n".join(left_code_builder)
	_line_numbers_right.bbcode_text = "\n".join(right_num_builder)
	_code_right.bbcode_text = "\n".join(right_code_builder)


# --- Internal Diff Implementation ---
# This is a standard Longest Common Subsequence (LCS) based diff algorithm.
func _compute_diff(a: PackedStringArray, b: PackedStringArray) -> Array:
	var n: int = a.size()
	var m: int = b.size()
	var max_len: int = n + m
	var v: Array = []
	v.resize(2 * max_len + 1)
	v.fill(0)
	var trace: Array = []

	for d in range(max_len + 1):
		var trace_d: Array = []
		trace_d.resize(v.size())
		trace_d.fill(0)
		
		for k in range(-d, d + 1, 2):
			var index: int = k + max_len
			var x: int
			
			if k == -d or (k != d and v[index - 1] < v[index + 1]):
				x = v[index + 1]
			else:
				x = v[index - 1] + 1

			var y: int = x - k
			
			while x < n and y < m and a[x] == b[y]:
				x += 1
				y += 1
			
			v[index] = x
			trace_d[index] = x
			
			if x >= n and y >= m:
				trace.append(trace_d)
				return _backtrack(trace, a, b)
		trace.append(trace_d)
	
	return []

func _backtrack(trace: Array, a: PackedStringArray, b: PackedStringArray) -> Array:
	var result: Array = []
	var x: int = a.size()
	var y: int = b.size()
	var max_len: int = a.size() + b.size()

	# Iterate backwards from the last edit distance (d) down to the first edit.
	for d in range(trace.size() - 1, 0, -1):
		var k: int = x - y
		var index: int = k + max_len
		
		var v_prev: Array = trace[d - 1]
		var prev_k: int
		
		# Find which path we took in the previous (d-1) step to get to our current k-line.
		# Did we come from k-1 (deletion) or k+1 (insertion)?
		if k == -d or (k != d and v_prev.size() > index -1 and v_prev[index - 1] < v_prev[index + 1]):
			prev_k = k + 1 # Came from k+1 line, which corresponds to an insertion.
		else:
			prev_k = k - 1 # Came from k-1 line, which corresponds to a deletion.
			
		# Get the coordinates at the end of the snake on the previous path.
		var prev_x: int = v_prev[prev_k + max_len]
		var prev_y: int = prev_x - prev_k

		# Backtrack through the current "snake" of equal lines until we reach the end of the previous path.
		# A snake is a sequence of diagonal moves (matching lines).
		while x > prev_x and y > prev_y:
			result.push_front({ "status": "eq", "content": a[x - 1] })
			x -= 1
			y -= 1
		
		# Now, at (x, y), we are at the start of the snake. The step before this
		# was the single non-diagonal move (the insertion or deletion).
		if d > 0: # This check might be redundant due to loop range, but it's safe
			if x > prev_x:
				# We moved horizontally from (x-1, y) to (x, y), so it was a deletion from 'a'.
				result.push_front({ "status": "del", "content": a[x - 1] })
				x -= 1
			else:
				# We moved vertically from (x, y-1) to (x, y), so it was an insertion from 'b'.
				result.push_front({ "status": "add", "content": b[y - 1] })
				y -= 1
	
	# After the loop, (x, y) should be at the end of the initial snake from d=0.
	# Any remaining lines from (0,0) to (x,y) are part of this initial snake.
	while x > 0 and y > 0:
		result.push_front({ "status": "eq", "content": a[x - 1] })
		x -= 1
		y -= 1
	
	# If there are any remaining lines in just 'a' or just 'b' at the very beginning.
	while x > 0:
		result.push_front({ "status": "del", "content": a[x-1] })
		x -= 1
	while y > 0:
		result.push_front({ "status": "add", "content": b[y-1] })
		y -= 1

	return result
