extends Node2D
## Procedural crust: soil, a soft sedimentary tier, a quartz-cemented sandstone band that needs a
## steel pick, then a deeper basin tier. Tiles are painted in code so there are no art files yet.

enum { GRASS, DIRT, SAND, SHALE, LIMESTONE, SANDSTONE, DOLOSTONE, BEDROCK, VEIN_SHALLOW, VEIN_DEEP, TILE_COUNT }
const AIR := -1
const TILE := 16
const WIDTH := 160
const HEIGHT := 100
const SURFACE_Y := 18
const BAND_TOP := 52
const BAND_BOTTOM := 56
const METERS_PER_TILE := 2

## Display name, mining hardness (game values, roughly Mohs) and base color.
const TILES := {
	GRASS: {"name": "Topsoil", "hardness": 1.0, "color": Color("3f8f3a")},
	DIRT: {"name": "Soil", "hardness": 1.0, "color": Color("7a5236")},
	SAND: {"name": "Beach sand", "hardness": 1.0, "color": Color("dcc78a")},
	SHALE: {"name": "Shale", "hardness": 3.0, "color": Color("5d6170")},
	LIMESTONE: {"name": "Limestone", "hardness": 3.0, "color": Color("b9b29a")},
	SANDSTONE: {"name": "Quartz sandstone", "hardness": 6.0, "color": Color("c98d55")},
	DOLOSTONE: {"name": "Dolostone", "hardness": 3.5, "color": Color("a49a8c")},
	BEDROCK: {"name": "Bedrock", "hardness": 99.0, "color": Color("2a2530")},
	VEIN_SHALLOW: {"name": "Mineral vein", "hardness": 2.0, "color": Color("6a6672")},
	VEIN_DEEP: {"name": "Mineral vein", "hardness": 2.0, "color": Color("7d7468")},
}
const VEIN_SPARKLES := [Color("f2e36b"), Color("ffffff"), Color("d0453c"), Color("8ad1e0"), Color("b07ad6")]

var grid := PackedInt32Array()
var back := PackedInt32Array()   # dark back wall, shown where tiles are dug out or in caves
var map: TileMapLayer
var back_map: TileMapLayer


func build(seed: int, overrides: Dictionary) -> void:
	var tileset := _make_tileset()
	back_map = TileMapLayer.new()
	back_map.tile_set = tileset
	add_child(back_map)
	map = TileMapLayer.new()
	map.tile_set = tileset
	add_child(map)
	_generate(seed)
	for key in overrides:
		var parts: PackedStringArray = key.split(",")
		grid[int(parts[1]) * WIDTH + int(parts[0])] = int(overrides[key])
	for y in HEIGHT:
		for x in WIDTH:
			var t := grid[y * WIDTH + x]
			if t != AIR:
				map.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))
			var b := back[y * WIDTH + x]
			if b != AIR:
				back_map.set_cell(Vector2i(x, y), 0, Vector2i(b, 1))


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < WIDTH and c.y < HEIGHT


func get_tile(c: Vector2i) -> int:
	if not in_bounds(c):
		return BEDROCK
	return grid[c.y * WIDTH + c.x]


func set_tile(c: Vector2i, t: int) -> void:
	grid[c.y * WIDTH + c.x] = t
	if t == AIR:
		map.erase_cell(c)
	else:
		map.set_cell(c, 0, Vector2i(t, 0))
	GameState.changed_cells["%d,%d" % [c.x, c.y]] = t


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0


func is_vein(t: int) -> bool:
	return t == VEIN_SHALLOW or t == VEIN_DEEP


func tile_name(t: int) -> String:
	return TILES[t]["name"]


func hardness_of(t: int) -> float:
	return TILES[t]["hardness"]


func mine_time(t: int) -> float:
	return 0.2 + hardness_of(t) * 0.1


func tier_at(y: int) -> int:
	return 1 if y < BAND_BOTTOM else 2


## The rock a vein turns back into when the pick is too soft to break it.
func host_for(y: int) -> int:
	return SHALE if y < BAND_TOP else DOLOSTONE


func depth_m(world_y: float) -> int:
	return maxi(0, int((world_y / TILE - SURFACE_Y) * METERS_PER_TILE))


func spawn_position() -> Vector2:
	var x := WIDTH / 2
	for y in HEIGHT:
		if grid[y * WIDTH + x] != AIR:
			return Vector2(x * TILE + TILE / 2.0, (y - 1) * TILE)
	return Vector2(x * TILE, 0)


func _generate(seed: int) -> void:
	grid.resize(WIDTH * HEIGHT)
	back.resize(WIDTH * HEIGHT)
	var hills := _noise(seed, 0.03)
	var layers := _noise(seed + 1, 0.08)
	var caves := _noise(seed + 2, 0.07)
	var veins := _noise(seed + 3, 0.18)
	for x in WIDTH:
		var surface := SURFACE_Y + int(hills.get_noise_1d(x) * 6.0)
		var beach := x < 14
		for y in HEIGHT:
			var t := AIR
			if x == 0 or x == WIDTH - 1 or y >= HEIGHT - 2:
				t = BEDROCK
			elif y < surface:
				t = AIR
			elif y < surface + 4:
				if beach:
					t = SAND
				else:
					t = GRASS if y == surface else DIRT
			elif y >= BAND_TOP and y < BAND_BOTTOM:
				t = SANDSTONE
			elif y < BAND_TOP:
				# Squash the noise vertically so the strata read as horizontal beds.
				t = SHALE if layers.get_noise_2d(x * 0.25, y * 1.6) > 0.0 else LIMESTONE
			else:
				t = DOLOSTONE if layers.get_noise_2d(x * 0.25, y * 1.6) > -0.1 else SHALE
			back[y * WIDTH + x] = AIR if (t == AIR or t == GRASS) else t
			if t in [SHALE, LIMESTONE, DOLOSTONE]:
				if y > surface + 7 and caves.get_noise_2d(x, y) > 0.42:
					t = AIR
				elif veins.get_noise_2d(x, y) > 0.5:
					t = VEIN_SHALLOW if y < BAND_TOP else VEIN_DEEP
			grid[y * WIDTH + x] = t


func _noise(seed: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = frequency
	return n


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	# Row 0: solid tiles. Row 1: the same tiles darkened, for the back wall.
	var img := Image.create(TILE * TILE_COUNT, TILE * 2, false, Image.FORMAT_RGBA8)
	for i in TILE_COUNT:
		_paint_tile(img, i)
	for y in TILE:
		for x in TILE * TILE_COUNT:
			img.set_pixel(x, TILE + y, img.get_pixel(x, y).darkened(0.45))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var h := TILE / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for i in TILE_COUNT:
		src.create_tile(Vector2i(i, 0))
		var data := src.get_tile_data(Vector2i(i, 0), 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
		src.create_tile(Vector2i(i, 1))
	return ts


func _paint_tile(img: Image, index: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = index * 7919 + 17
	var base: Color = TILES[index]["color"]
	for py in TILE:
		for px in TILE:
			var c := base.darkened(r.randf() * 0.12)
			match index:
				GRASS:
					if py >= (5 if px % 3 == 0 else 4):
						c = TILES[DIRT]["color"].darkened(r.randf() * 0.12)
				SHALE:
					if py % 4 == 0:
						c = c.darkened(0.2)
				LIMESTONE:
					if r.randf() < 0.04:
						c = Color("e8e2cc")
				SANDSTONE, SAND:
					if r.randf() < 0.15:
						c = c.lightened(0.25)
				DOLOSTONE:
					if (px + py * 2) % 7 == 0:
						c = c.lightened(0.12)
				BEDROCK:
					if (px / 4 + py / 4) % 2 == 0:
						c = c.lightened(0.08)
				VEIN_SHALLOW, VEIN_DEEP:
					if r.randf() < 0.12:
						c = VEIN_SPARKLES[r.randi_range(0, VEIN_SPARKLES.size() - 1)]
			# Bevel edges for a chunky 8-bit block look.
			if px == 0 or py == 0:
				c = c.lightened(0.1)
			elif px == TILE - 1 or py == TILE - 1:
				c = c.darkened(0.25)
			img.set_pixel(index * TILE + px, py, c)
