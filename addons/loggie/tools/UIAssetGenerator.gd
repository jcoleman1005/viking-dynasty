@tool
extends EditorScript

const OUT_PATH = "res://ui/assets/"
const SIZE = 256

func _run() -> void:
	# 1. Ensure directory exists
	if not DirAccess.dir_exists_absolute(OUT_PATH):
		DirAccess.make_dir_recursive_absolute(OUT_PATH)
		
	print("--- Generating Chronicler UI Kit ---")
	
	# 2. Generate all textures
	_gen_parchment()    # For Backgrounds
	_gen_wood()         # For Panels/Buttons
	_gen_shield()       # For RTS Buttons
	_gen_wax_seal()     # For Event Choices
	_gen_scroll_vertical() # For Storefront
	_gen_tapestry()     # For Dynasty Tree
	# --- NEW: Generate Resource Tag ---
	_gen_resource_tag()
	_gen_tooltip_bg()
	_gen_icons()
	_gen_resource_icons()
	
	print("Assets Saved to ", OUT_PATH)
	
	# 3. Refresh Godot to see files
	EditorInterface.get_resource_filesystem().scan()

func _gen_parchment() -> void:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
	noise.frequency = 0.03
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	for x in SIZE:
		for y in SIZE:
			# Base: Cool Grey
			var col = Color("#aeb5bd")
			
			var n = noise.get_noise_2d(x, y)
			col = col.darkened(n * 0.1)
			
			img.set_pixel(x, y, col)
	img.save_png(OUT_PATH + "parchment_bg.png")
	
func _gen_wood() -> void:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
	noise.frequency = 0.02
	
	for x in SIZE:
		for y in SIZE:
			# Stretched grain
			var n = noise.get_noise_2d(x * 0.1, y * 4.0) 
			# Dark Oak
			var base = Color("#4a3c31") 
			img.set_pixel(x, y, base.darkened(n * 0.3))
	img.save_png(OUT_PATH + "wood_bg.png")

func _gen_shield() -> void:
	# RTS Button Background
	var s = 128
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center = Vector2(s / 2.0, s / 2.0)
	var radius = (s / 2.0) - 2.0
	
	for x in s:
		for y in s:
			var d = Vector2(x, y).distance_to(center)
			if d < radius:
				# Iron Rim
				if d > radius - 8:
					img.set_pixel(x, y, Color("#555555"))
				# Wood Body
				else:
					var grain = sin(x * 0.5) * 0.1
					var base = Color("#6d543e").lightened(grain)
					img.set_pixel(x, y, base)
					
				# Boss (Center bump)
				if d < 12:
					img.set_pixel(x, y, Color("#777777"))
					
	img.save_png(OUT_PATH + "shield_btn.png")

func _gen_wax_seal() -> void:
	# Event Choice Button
	var s = 64
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center = Vector2(s / 2.0, s / 2.0)
	var radius = (s / 2.0) - 4.0
	
	for x in s:
		for y in s:
			var d = Vector2(x, y).distance_to(center)
			if d < radius:
				# Wax Red
				var col = Color("#a83232") 
				# Edge bevel
				if d > radius - 8.0:
					col = col.darkened(0.1) 
				img.set_pixel(x, y, col)
	img.save_png(OUT_PATH + "wax_seal.png")

func _gen_scroll_vertical() -> void:
	# Storefront Background
	var w = 256
	var h = 512
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for x in w:
		for y in h:
			var col = Color("#f5e6d3")
			# Shadow on edges to look rolled
			var dist_x = min(x, w - x)
			if dist_x < 20:
				col = col.darkened((20 - dist_x) * 0.02)
			img.set_pixel(x, y, col)
			
	img.save_png(OUT_PATH + "scroll_bg.png")

func _gen_tapestry() -> void:
	# Dynasty Background
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for x in SIZE:
		for y in SIZE:
			# Woven texture pattern
			var weave = (int(x) % 4 == 0) or (int(y) % 4 == 0)
			# Dark cloth
			var col = Color("#2e222f") 
			if weave:
				col = col.lightened(0.05)
			img.set_pixel(x, y, col)
	img.save_png(OUT_PATH + "tapestry_bg.png")
	
func _gen_resource_tag() -> void:
	# A dark, iron-wood background for text labels
	var w = 128
	var h = 48
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for x in w:
		for y in h:
			# Dark Iron/Wood Color (#2F2F2F)
			var col = Color("#2F2F2F")
			
			# Add slight bevel at edges
			if x < 2 or x > w - 3 or y < 2 or y > h - 3:
				col = col.lightened(0.3)
			elif x < 4 or x > w - 5 or y < 4 or y > h - 5:
				col = col.darkened(0.5)
				
			img.set_pixel(x, y, col)
			
	img.save_png(OUT_PATH + "resource_tag.png")

func _gen_tooltip_bg() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 64:
			# Dark Slate Blue/Grey (#1e2124)
			img.set_pixel(x, y, Color("#1e2124"))
	
	# Add a gold border (1px)
	for i in 64:
		var gold = Color("#c5a54e")
		img.set_pixel(i, 0, gold)
		img.set_pixel(i, 63, gold)
		img.set_pixel(0, i, gold)
		img.set_pixel(63, i, gold)
		
	img.save_png(OUT_PATH + "tooltip_bg.png")

func _gen_resource_icons() -> void:
	var resources = ["res_gold", "res_wood", "res_food", "res_stone", "res_peasant", "res_thrall"]
	
	for name in resources:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		
		# Helper to fill a rect
		var fill_rect = func(rect: Rect2i, color: Color):
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					img.set_pixel(x, y, color)
		
		# Helper to fill a circle
		var fill_circle = func(center: Vector2, radius: float, color: Color):
			for x in 64:
				for y in 64:
					if Vector2(x,y).distance_to(center) <= radius:
						img.set_pixel(x, y, color)

		match name:
			"res_gold":
				# Stack of 3 Yellow Coins
				fill_circle.call(Vector2(20, 40), 12, Color.GOLD)
				fill_circle.call(Vector2(44, 40), 12, Color.GOLD)
				fill_circle.call(Vector2(32, 24), 12, Color("#ffff00")) # Bright Top
				
			"res_wood":
				# 3 Brown Logs (Rectangles)
				fill_rect.call(Rect2i(10, 10, 44, 12), Color("#8b4513"))
				fill_rect.call(Rect2i(10, 26, 44, 12), Color("#a0522d"))
				fill_rect.call(Rect2i(10, 42, 44, 12), Color("#8b4513"))
				
			"res_food":
				# Red Apple / Meat
				fill_circle.call(Vector2(32, 36), 20, Color("#cd5c5c")) # Meat
				fill_rect.call(Rect2i(30, 10, 4, 10), Color.WHITE) # Bone/Stem
				
			"res_stone":
				# Grey Boulder
				fill_circle.call(Vector2(32, 32), 22, Color.GRAY)
				fill_circle.call(Vector2(24, 24), 8, Color.LIGHT_GRAY) # Highlight
				
			"res_peasant":
				# Tan Face + Green Hood
				fill_circle.call(Vector2(32, 32), 24, Color("#556b2f")) # Hood
				fill_circle.call(Vector2(32, 32), 16, Color("#f5deb3")) # Face
				
			"res_thrall":
				# Iron Shackle
				fill_circle.call(Vector2(32, 32), 22, Color.DIM_GRAY) # Ring
				fill_circle.call(Vector2(32, 32), 14, Color(0,0,0,0)) # Hole (Transparent)
				fill_rect.call(Rect2i(28, 40, 8, 24), Color.DIM_GRAY) # Chain link

		img.save_png(OUT_PATH + name + ".png")

func _gen_icons() -> void:
	var icons = ["icon_build", "icon_army", "icon_crown", "icon_map", "icon_time", "icon_manage", "icon_family"]
	
	for name in icons:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		
		# --- FIX: Pure White for maximum visibility ---
		var col = Color.WHITE 
		# ----------------------------------------------
		
		# Helper for drawing shapes
		var draw_box = func(r: Rect2i):
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					img.set_pixel(x, y, col)
					
		match name:
			"icon_build": # Hammer
				draw_box.call(Rect2i(20, 20, 24, 12)) # Head
				draw_box.call(Rect2i(28, 32, 8, 24))  # Handle
			"icon_army": # Sword
				draw_box.call(Rect2i(30, 10, 4, 30)) # Blade
				draw_box.call(Rect2i(24, 40, 16, 4)) # Guard
				draw_box.call(Rect2i(30, 44, 4, 10)) # Hilt
			"icon_crown": # Crown
				draw_box.call(Rect2i(16, 40, 32, 8)) # Base
				draw_box.call(Rect2i(16, 20, 8, 20)) # Left
				draw_box.call(Rect2i(28, 20, 8, 20)) # Mid
				draw_box.call(Rect2i(40, 20, 8, 20)) # Right
			"icon_map": # Square Map
				draw_box.call(Rect2i(16, 16, 32, 32))
				# Cut center
				for x in range(20, 44):
					for y in range(20, 44):
						img.set_pixel(x, y, Color(0,0,0,0))
			"icon_time": # Hourglass
				draw_box.call(Rect2i(20, 16, 24, 4)) # Top
				draw_box.call(Rect2i(20, 44, 24, 4)) # Bot
				draw_box.call(Rect2i(28, 20, 8, 24)) # Middle
			"icon_manage": # Gear
				draw_box.call(Rect2i(20, 20, 24, 24))
				for x in range(26, 38):
					for y in range(26, 38):
						img.set_pixel(x, y, Color(0,0,0,0)) # Hole
			"icon_family": # Tree
				draw_box.call(Rect2i(28, 32, 8, 24)) # Trunk
				draw_box.call(Rect2i(20, 10, 24, 22)) # Leaves

		img.save_png(OUT_PATH + name + ".png")
