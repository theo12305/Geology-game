extends Node2D
## Procedural crust, top to bottom: soil; tier 1 shale and limestone; a quartz sandstone band (needs a
## steel pick); tier 2 dolostone basin with coal; a chert band (needs a hardened pick); tier 3 metamorphic
## belt of slate, schist and marble; tier 4 granite pluton with a gneiss rim. Tiles are painted in code.

# Append new tiles before TILE_COUNT: saves store these numbers.
enum { GRASS, DIRT, SAND, SHALE, LIMESTONE, SANDSTONE, DOLOSTONE, BEDROCK, VEIN_SHALLOW, VEIN_DEEP, RUBBLE, GEODE,
	COAL, CHERT, SLATE, SCHIST, MARBLE, GNEISS, GRANITE, CONGLOMERATE, VEIN_META, VEIN_GRANITE, TILE_COUNT }
const AIR := -1
const TILE := 16
const WIDTH := 160
const HEIGHT := 170
const SURFACE_Y := 18
const BAND_TOP := 52        # quartz sandstone band, gate to tier 2
const BAND_BOTTOM := 56
const CHERT_TOP := 88       # chert band, gate to tier 3
const CHERT_BOTTOM := 92
const SLATE_BOTTOM := 104   # tier 3: slate above, schist and marble below
const GRANITE_TOP := 132    # tier 4: gneiss rim, then granite
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
	RUBBLE: {"name": "Rubble block", "hardness": 1.0, "color": Color("8a7f74")},
	GEODE: {"name": "Geode", "hardness": 2.5, "color": Color("6d6060")},
	COAL: {"name": "Coal seam", "hardness": 2.0, "color": Color("1f1d22")},
	CHERT: {"name": "Chert", "hardness": 7.0, "color": Color("6b4a3a")},
	SLATE: {"name": "Slate", "hardness": 3.0, "color": Color("3e4656")},
	SCHIST: {"name": "Schist", "hardness": 4.0, "color": Color("8a8a7c")},
	MARBLE: {"name": "Marble", "hardness": 3.0, "color": Color("e4e1d8")},
	GNEISS: {"name": "Gneiss", "hardness": 6.0, "color": Color("9a8f88")},
	GRANITE: {"name": "Granite", "hardness": 6.0, "color": Color("d9b8a8")},
	CONGLOMERATE: {"name": "Conglomerate", "hardness": 3.0, "color": Color("9c7f60")},
	VEIN_META: {"name": "Mineral vein", "hardness": 2.0, "color": Color("7f7f74")},
	VEIN_GRANITE: {"name": "Mineral vein", "hardness": 2.0, "color": Color("b59a8e")},
}
## Rock sample each host tile can give (ids in rocks.json).
const ROCK_OF := {
	SHALE: "shale", LIMESTONE: "limestone", SANDSTONE: "sandstone", DOLOSTONE: "dolostone", COAL: "coal",
	CHERT: "chert", SLATE: "slate", SCHIST: "schist", MARBLE: "marble", GNEISS: "gneiss", GRANITE: "granite",
	CONGLOMERATE: "conglomerate",
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
	return t in [VEIN_SHALLOW, VEIN_DEEP, VEIN_META, VEIN_GRANITE]


## Tiles that give samples when mined instead of rubble.
func gives_samples(t: int) -> bool:
	return is_vein(t) or t == GEODE


func tile_name(t: int) -> String:
	return TILES[t]["name"]


func hardness_of(t: int) -> float:
	return TILES[t]["hardness"]


func mine_time(t: int) -> float:
	return 0.08 + hardness_of(t) * 0.03


func tier_at(y: int) -> int:
	if y < BAND_BOTTOM:
		return 1
	if y < CHERT_BOTTOM:
		return 2
	if y < GRANITE_TOP:
		return 3
	return 4


## The rock a vein turns back into when the pick is too soft to break it.
func host_for(y: int) -> int:
	return [SHALE, DOLOSTONE, SCHIST, GRANITE][tier_at(y) - 1]


func vein_for(y: int) -> int:
	return [VEIN_SHALLOW, VEIN_DEEP, VEIN_META, VEIN_GRANITE][tier_at(y) - 1]


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
	var pebbles := _noise(seed + 5, 0.05)
	var rare := RandomNumberGenerator.new()
	rare.seed = seed + 4
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
			elif y < surface + 6 and pebbles.get_noise_1d(x) > 0.25:
				t = CONGLOMERATE
			elif y >= BAND_TOP and y < BAND_BOTTOM:
				t = SANDSTONE
			elif y >= CHERT_TOP and y < CHERT_BOTTOM:
				t = CHERT
			elif y < BAND_TOP:
				# Squash the noise vertically so the strata read as horizontal beds.
				t = SHALE if layers.get_noise_2d(x * 0.25, y * 1.6) > 0.0 else LIMESTONE
			elif y < CHERT_TOP:
				var n := layers.get_noise_2d(x * 0.25, y * 1.6)
				t = COAL if n < -0.45 else (DOLOSTONE if n > -0.1 else SHALE)
			elif y < GRANITE_TOP:
				if y < SLATE_BOTTOM:
					t = SLATE
				else:
					t = MARBLE if layers.get_noise_2d(x * 0.4, y * 1.2) > 0.35 else SCHIST
			else:
				# The pluton's top is domed; the rim against the schist is gneiss.
				var top := GRANITE_TOP + 6 + int(hills.get_noise_1d(x + 500) * 5.0)
				t = GNEISS if y < top else GRANITE
			back[y * WIDTH + x] = AIR if (t == AIR or t == GRASS) else t
			if t in [SHALE, LIMESTONE, DOLOSTONE, SLATE, SCHIST, MARBLE, GNEISS, GRANITE]:
				if y > surface + 7 and caves.get_noise_2d(x, y) > 0.42:
					t = AIR
				elif veins.get_noise_2d(x, y) > 0.5:
					t = vein_for(y)
				elif y > surface + 10 and rare.randf() < 0.004:
					t = GEODE
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
				VEIN_SHALLOW, VEIN_DEEP, VEIN_META, VEIN_GRANITE:
					if r.randf() < 0.12:
						c = VEIN_SPARKLES[r.randi_range(0, VEIN_SPARKLES.size() - 1)]
				COAL:
					if r.randf() < 0.08:
						c = Color("4a4a55")
				CHERT:
					if (px * 3 + py * 5) % 11 == 0:
						c = c.lightened(0.2)
				SLATE:
					if (px + py) % 5 == 0:
						c = c.darkened(0.25)
				SCHIST:
					if (py + int(sin(px * 0.8) * 1.5)) % 4 == 0:
						c = Color("c9c7b8") if r.randf() < 0.6 else c.darkened(0.3)
				MARBLE:
					if absi(py - (px / 2 + 4)) == 0 or r.randf() < 0.03:
						c = Color("a8a59e")
				GNEISS:
					if (py / 3) % 2 == 0:
						c = Color("4d4440").lightened(r.randf() * 0.1)
				GRANITE:
					# 2 x 2 pixel crystals read better than single-pixel noise.
					var roll := float(hash(Vector2i(px / 2, py / 2)) % 1000) / 1000.0
					if roll < 0.18:
						c = Color("2b2626")
					elif roll < 0.45:
						c = Color("efe8e2")
					elif roll < 0.6:
						c = Color("b0aaa6")
				CONGLOMERATE:
					if Vector2(px % 6 - 3, py % 6 - 3).length() < 2.2:
						c = Color("c8bfb0").darkened(r.randf() * 0.3)
				RUBBLE:
					if (px % 8 == 0) or (py % 8 == 0 and px > 0):
						c = c.darkened(0.3)
				GEODE:
					# Round rock with a hollow of purple crystals.
					var d := Vector2(px - 7.5, py - 7.5).length()
					if d < 4.5:
						c = Color("b07ad6").lightened(r.randf() * 0.4) if r.randf() < 0.7 else Color("e9d8ff")
					elif d < 6.0:
						c = Color("e8e4dc")
			# Bevel edges for a chunky 8-bit block look.
			if px == 0 or py == 0:
				c = c.lightened(0.1)
			elif px == TILE - 1 or py == TILE - 1:
				c = c.darkened(0.25)
			img.set_pixel(index * TILE + px, py, c)
