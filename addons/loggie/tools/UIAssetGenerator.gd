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

func _gen_icons() -> void:
	var icons = ["icon_build", "icon_army", "icon_crown", "icon_map", "icon_time"]
	for name in icons:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var col = Color("#f5e6d3") # Parchment White
		
		for x in 64:
			for y in 64:
				var d_center = Vector2(x,y).distance_to(Vector2(32,32))
				var pixel = Color(0,0,0,0)
				
				match name:
					"icon_build": # House shape
						if y > 30 and x > 14 and x < 50 and y < 54: pixel = col # Box
						if y <= 30 and y > 10 and abs(x - 32) < (y - 6): pixel = col # Roof
					"icon_army": # Helmet shape
						if d_center < 20 and y < 36: pixel = col # Dome
						if y >= 36 and y < 50 and abs(x-32) < 20: pixel = col # Cheek guards
						if x == 32 and y < 45: pixel = Color(0,0,0,0) # Nose gap
					"icon_crown": # Crown shape
						if y > 30 and y < 50 and x > 14 and x < 50: pixel = col # Band
						if y <= 30 and (abs(x-14) < 4 or abs(x-32) < 6 or abs(x-50) < 4): pixel = col # Points
					"icon_map": # Scroll shape
						if x > 14 and x < 50 and y > 10 and y < 54: pixel = col # Paper
						# Cutout lines
						if (y % 10 == 0) and x > 20 and x < 44: pixel = Color(0,0,0,0)
					"icon_time": # Hourglass
						if abs(x-32) < (y-10)*0.8 and y < 32 and y > 10: pixel = col # Top
						if abs(x-32) < (54-y)*0.8 and y >= 32 and y < 54: pixel = col # Bottom
				
				img.set_pixel(x, y, pixel)
		
		img.save_png(OUT_PATH + name + ".png")

func _gen_resource_icons() -> void:
	var resources = ["res_gold", "res_wood", "res_food", "res_stone"]
	
	for name in resources:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		
		for x in 64:
			for y in 64:
				var pixel = Color(0,0,0,0)
				
				match name:
					"res_gold": # Coin stack
						# Bottom Coin
						if Vector2(x,y).distance_to(Vector2(24, 40)) < 10: pixel = Color("#ffd700")
						if Vector2(x,y).distance_to(Vector2(40, 40)) < 10: pixel = Color("#daa520")
						# Top Coin
						if Vector2(x,y).distance_to(Vector2(32, 28)) < 10: pixel = Color("#ffff00")
						
					"res_wood": # Logs
						# Log 1
						if x > 10 and x < 54 and y > 20 and y < 30: pixel = Color("#8b4513")
						# Log 2
						if x > 10 and x < 54 and y > 32 and y < 42: pixel = Color("#a0522d")
						# Log 3
						if x > 10 and x < 54 and y > 44 and y < 54: pixel = Color("#8b4513")
						# Ends
						if x < 14 and y > 20 and y < 54: pixel = Color("#deb887")
						
					"res_food": # Meat on bone
						# Bone
						if x > 10 and x < 54 and abs(y-32) < 4: pixel = Color("#f5f5f5")
						if Vector2(x,y).distance_to(Vector2(14, 32)) < 6: pixel = Color("#f5f5f5")
						if Vector2(x,y).distance_to(Vector2(50, 32)) < 6: pixel = Color("#f5f5f5")
						# Meat
						if Vector2(x,y).distance_to(Vector2(32, 32)) < 14: pixel = Color("#cd5c5c")
						
					"res_stone": # Boulder
						var d = Vector2(x,y).distance_to(Vector2(32,32))
						# Irregular shape logic
						var noise = (x * y) % 7
						if d < 20 + noise: 
							pixel = Color("#808080")
							if x > 32 and y < 32: pixel = Color("#a9a9a9") # Highlight
							
				img.set_pixel(x, y, pixel)
		
		img.save_png(OUT_PATH + name + ".png")
