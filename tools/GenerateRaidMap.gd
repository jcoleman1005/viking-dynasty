# res://tools/GenerateRaidMap.gd
@tool
extends EditorScript

# --- CONFIGURATION ---
const TARGET_PATH = "res://data/settlements/generated/raid_rich_hub_01.tres"
const GRID_W = 80 
const GRID_H = 50
const BEACH_WIDTH = 15 

# --- BUILDING PALETTE ---
const B_HALL = "res://data/buildings/GreatHall.tres"
const B_WALL = "res://data/buildings/Bldg_Wall.tres"
const B_TOWER = "res://data/buildings/Monastery_Watchtower.tres"

const RICH_BUILDINGS = [
	"res://data/buildings/Monastery_Library.tres",
	"res://data/buildings/Monastery_Scriptorium.tres",
	"res://data/buildings/Monastery_Chapel.tres"
]

const MID_BUILDINGS = [
	"res://data/buildings/Monastery_Granary.tres",
	"res://data/buildings/Monastery_Granary.tres" 
]

const POOR_BUILDINGS = [
	"res://data/buildings/Player_Farm.tres",
	"res://data/buildings/LumberYard.tres"
]

# --- STATE ---
var occupied_cells: Dictionary = {}
var placed_list: Array[Dictionary] = []

func _run() -> void:
	print("--- Generating Procedural Raid Map (The Hub) ---")
	_reset()
	
	var center = Vector2i(int(GRID_W * 0.7), int(GRID_H * 0.5))
	
	_place_building(B_HALL, center)
	_generate_citadel_layer(center, 6, 10)
	_generate_scatter_layer(center, 12, 20, MID_BUILDINGS, 0.6)
	_generate_scatter_layer(center, 22, 35, POOR_BUILDINGS, 0.3)
	
	_save_resource()

func _reset() -> void:
	occupied_cells.clear()
	placed_list.clear()

func _generate_citadel_layer(center: Vector2i, radius_min: int, radius_max: int) -> void:
	for x in range(center.x - radius_max, center.x + radius_max + 1):
		for y in range(center.y - radius_max, center.y + radius_max + 1):
			var pos = Vector2i(x, y)
			var dist = Vector2(pos).distance_to(Vector2(center))
			
			if dist >= radius_max - 1.5 and dist <= radius_max:
				if abs(pos.y - center.y) < 3 and pos.x < center.x:
					continue
					
				if (x % 6 == 0 and y % 6 == 0) or dist > radius_max - 0.5:
					_try_place(B_TOWER, pos)
				else:
					_try_place(B_WALL, pos)
					
	var attempts = 20
	for i in range(attempts):
		var building = RICH_BUILDINGS.pick_random()
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(radius_min, radius_max - 2)
		var pos = center + Vector2i(offset)
		_try_place(building, pos)

func _generate_scatter_layer(center: Vector2i, r_min: int, r_max: int, palette: Array, density: float) -> void:
	for x in range(center.x - r_max, center.x + r_max):
		for y in range(center.y - r_max, center.y + r_max):
			var pos = Vector2i(x, y)
			
			if pos.x < BEACH_WIDTH: continue
			
			var dist = Vector2(pos).distance_to(Vector2(center))
			
			if dist > r_min and dist < r_max:
				if randf() < density * 0.1: 
					var b = palette.pick_random()
					_try_place(b, pos)

func _try_place(path: String, grid_pos: Vector2i) -> void:
	var data = load(path) as BuildingData
	if not data: return
	
	var size = data.grid_size
	
	if grid_pos.x < BEACH_WIDTH: return
	if grid_pos.x + size.x >= GRID_W: return
	if grid_pos.y < 0 or grid_pos.y + size.y >= GRID_H: return
	
	for x in range(size.x):
		for y in range(size.y):
			var check = grid_pos + Vector2i(x, y)
			if occupied_cells.has(check):
				return 
				
	_place_building(path, grid_pos)

func _place_building(path: String, grid_pos: Vector2i) -> void:
	var data = load(path) as BuildingData
	var size = data.grid_size
	
	for x in range(size.x):
		for y in range(size.y):
			occupied_cells[grid_pos + Vector2i(x, y)] = true
			
	placed_list.append({
		"resource_path": path,
		"grid_position": grid_pos
	})

func _save_resource() -> void:
	var dir = TARGET_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		
	var s_data = SettlementData.new()
	s_data.placed_buildings = placed_list
	s_data.treasury = {"gold": 2000, "wood": 1000, "food": 800, "stone": 500}
	
	# --- FIX: Use clear() instead of assignment to respect strict typing ---
	s_data.warbands.clear() 
	# ---------------------------------------------------------------------
	
	var err = ResourceSaver.save(s_data, TARGET_PATH)
	if err == OK:
		print("✅ Map Saved: ", TARGET_PATH)
		print("   Buildings: ", placed_list.size())
		EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("❌ Save Failed: ", err)
