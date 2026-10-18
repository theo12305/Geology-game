extends Node2D
## Procedural crust, top to bottom: soil; tier 1 shale and limestone; a quartz sandstone band (needs a
## steel pick); tier 2 dolostone basin with coal; a chert band (needs a hardened pick); tier 3 metamorphic
## belt of slate, schist and marble; tier 4 granite pluton with a gneiss rim. Fossils hide in the sedimentary
## beds, crystal caverns glow in the deep rock, and caves grow stalactites. Tiles are painted in code.

# Append new tiles before TILE_COUNT: saves store these numbers.
enum { GRASS, DIRT, SAND, SHALE, LIMESTONE, SANDSTONE, DOLOSTONE, BEDROCK, VEIN_SHALLOW, VEIN_DEEP, RUBBLE, GEODE,
	COAL, CHERT, SLATE, SCHIST, MARBLE, GNEISS, GRANITE, CONGLOMERATE, VEIN_META, VEIN_GRANITE, FOSSIL, CRYSTAL,
	TILE_COUNT }
## Decorations: non-solid tiles drawn in empty cells, in atlas row 2.
enum { STALACTITE, STALAGMITE, TUFT, FLOWER, MUSHROOM, DECO_COUNT }
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
	FOSSIL: {"name": "Fossil", "hardness": 2.5, "color": Color("a39b84")},
	CRYSTAL: {"name": "Crystal lining", "hardness": 2.5, "color": Color("3a2f4a")},
}
## Zones you discover on the way down: id, name and what makes them geologically interesting.
const ZONES := {
	"beds": ["Sedimentary beds", "Shale and limestone laid down in a shallow sea, oldest at the bottom. Look for fossils!"],
	"sandstone_band": ["Quartz sandstone band", "Sand cemented by quartz, hardness about 6. A steel pick gets you through."],
	"basin": ["Dolostone basin", "Magnesium-rich brines turned limestone into dolostone and brought lead and zinc ores. Coal seams record swamp forests."],
	"chert_band": ["Chert band", "Microcrystalline quartz from the silica skeletons of plankton, hardness 7. You need a hardened pick."],
	"metamorphic": ["Metamorphic belt", "Heat and pressure recrystallised shale into slate and schist, and limestone into marble. Fossils did not survive."],
	"pluton": ["Granite pluton", "Magma that cooled slowly deep underground into big crystals of quartz, feldspar and mica, wrapped in gneiss."],
}
## Rock sample each host tile can give (ids in rocks.json).
const ROCK_OF := {
	SHALE: "shale", LIMESTONE: "limestone", SANDSTONE: "sandstone", DOLOSTONE: "dolostone", COAL: "coal",
	CHERT: "chert", SLATE: "slate", SCHIST: "schist", MARBLE: "marble", GNEISS: "gneiss", GRANITE: "granite",
	CONGLOMERATE: "conglomerate",
}
const VEIN_SPARKLES := [Color("f2e36b"), Color("ffffff"), Color("d0453c"), Color("8ad1e0"), Color("b07ad6")]

var grid := PackedInt32Array()
var deco := {}                   # Vector2i -> decoration id, in empty cells
var caverns: Array[Vector2] = [] # centers of crystal caverns, for their glow
var back := PackedInt32Array()   # dark back wall, shown where tiles are dug out or in caves
var map: TileMapLayer
var back_map: TileMapLayer
var deco_map: TileMapLayer
var scenery: Scenery


class Scenery extends Node2D:
	## Trees, the camp and clouds on the surface, drawn in code so digging under a tree makes it fall away.
	var world: Node2D
	var trees: Array = []        # [x tile, height in tiles, kind]
	var camp_x := 0
	var camp_rect := Rect2()
	var cloud_shift := 0.0

	func _process(delta: float) -> void:
		cloud_shift += delta * 4.0
		queue_redraw()

	func _surface(x: int) -> int:
		var y := 0
		while y < HEIGHT and world.get_tile(Vector2i(x, y)) == AIR:
			y += 1
		return y

	func _draw() -> void:
		var T := TILE
		for i in 7:
			var cx := fposmod(i * 260.0 + cloud_shift * (1.0 + i % 3 * 0.3), WIDTH * T + 200) - 100
			var cy := 30.0 + (i * 53) % 90
			for j in 3:
				draw_rect(Rect2(cx + j * 14 - (j % 2) * 4, cy - (j % 2) * 7, 26, 10), Color(1, 1, 1, 0.85))
		for tr in trees:
			var x: int = tr[0]
			var top := _surface(x)
			if world.get_tile(Vector2i(x, top)) != GRASS:
				continue
			var base := Vector2(x * T + T / 2.0, top * T)
			var h: int = tr[1] * T
			draw_rect(Rect2(base.x - 3, base.y - h, 6, h), Color("6b4a2f"))
			draw_rect(Rect2(base.x - 3, base.y - h, 2, h), Color("85603e"))
			if tr[2] == 0:
				for k in 3:
					var w := 44 - k * 10
					draw_rect(Rect2(base.x - w / 2.0, base.y - h - 6 - k * 9, w, 12), Color("2f7a35").lightened(k * 0.08))
				draw_rect(Rect2(base.x - 14, base.y - h - 10, 6, 4), Color("4a9e4a"))
			else:
				for k in 4:
					var w := 34 - k * 8
					draw_rect(Rect2(base.x - w / 2.0, base.y - h + 10 - k * 11, w, 11), Color("245c3a").lightened(k * 0.05))
		var ct := _surface(camp_x)
		var cb := Vector2(camp_x * T, ct * T)
		camp_rect = Rect2(cb + Vector2(-8, -34), Vector2(64, 34))
		# Tent
		draw_colored_polygon(PackedVector2Array([cb + Vector2(-6, 0), cb + Vector2(14, -24), cb + Vector2(34, 0)]), Color("d9643b"))
		draw_colored_polygon(PackedVector2Array([cb + Vector2(8, 0), cb + Vector2(14, -12), cb + Vector2(20, 0)]), Color("5a2a1c"))
		# Sign: a board with a book on it, on a post
		draw_rect(Rect2(cb + Vector2(43, -14), Vector2(3, 14)), Color("6b4a2f"))
		draw_rect(Rect2(cb + Vector2(34, -30), Vector2(22, 16)), Color("c49a5c"))
		draw_rect(Rect2(cb + Vector2(34, -30), Vector2(22, 16)), Color("6b4a2f"), false, 1.0)
		draw_rect(Rect2(cb + Vector2(38, -26), Vector2(6, 8)), Color("f3ecf7"))
		draw_rect(Rect2(cb + Vector2(45, -26), Vector2(6, 8)), Color("f3ecf7"))
		draw_rect(Rect2(cb + Vector2(44, -26), Vector2(1, 8)), Color("5b4a6b"))


func build(seed: int, overrides: Dictionary) -> void:
	var tileset := _make_tileset()
	back_map = TileMapLayer.new()
	back_map.tile_set = tileset
	add_child(back_map)
	map = TileMapLayer.new()
	map.tile_set = tileset
	add_child(map)
	deco_map = TileMapLayer.new()
	deco_map.tile_set = tileset
	deco_map.collision_enabled = false
	add_child(deco_map)
	_generate(seed)
	for key in overrides:
		var parts: PackedStringArray = key.split(",")
		grid[int(parts[1]) * WIDTH + int(parts[0])] = int(overrides[key])
	_decorate(seed)
	scenery = Scenery.new()
	scenery.world = self
	scenery.camp_x = WIDTH / 2 + 3
	var r := RandomNumberGenerator.new()
	r.seed = seed + 9
	var tx := 16
	while tx < WIDTH - 4:
		if absi(tx - scenery.camp_x - 1) > 4 and absi(tx - WIDTH / 2) > 2:
			scenery.trees.append([tx, r.randi_range(2, 4), r.randi_range(0, 1)])
		tx += r.randi_range(6, 13)
	add_child(scenery)
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
		# Formations hanging from or standing on this block fall with it.
		if deco.get(c + Vector2i.DOWN, -1) == STALACTITE:
			_clear_deco(c + Vector2i.DOWN)
		if deco.get(c + Vector2i.UP, STALACTITE) != STALACTITE:
			_clear_deco(c + Vector2i.UP)
	else:
		map.set_cell(c, 0, Vector2i(t, 0))
		_clear_deco(c)
	GameState.changed_cells["%d,%d" % [c.x, c.y]] = t


func _clear_deco(c: Vector2i) -> void:
	deco.erase(c)
	deco_map.erase_cell(c)


## Stalactites and stalagmites in limestone and dolostone caves, mushrooms in other caves, grass and
## flowers on the surface.
func _decorate(seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed + 7
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if grid[y * WIDTH + x] != AIR:
				continue
			var above := grid[(y - 1) * WIDTH + x]
			var below := grid[(y + 1) * WIDTH + x]
			var d := -1
			if above in [LIMESTONE, DOLOSTONE, MARBLE] and r.randf() < 0.35:
				d = STALACTITE
			elif below in [LIMESTONE, DOLOSTONE, MARBLE] and r.randf() < 0.2:
				d = STALAGMITE
			elif below == GRASS:
				d = [TUFT, TUFT, FLOWER, -1][r.randi_range(0, 3)]
			elif below in [SHALE, COAL, SLATE] and y > SURFACE_Y + 8 and r.randf() < 0.12:
				d = MUSHROOM
			if d >= 0:
				deco[Vector2i(x, y)] = d
				deco_map.set_cell(Vector2i(x, y), 0, Vector2i(d, 2))


## Which named zone a tile row is in, or "" near the surface.
func zone_at(y: int) -> String:
	if y < SURFACE_Y + 3:
		return ""
	if y < BAND_TOP:
		return "beds"
	if y < BAND_BOTTOM:
		return "sandstone_band"
	if y < CHERT_TOP:
		return "basin"
	if y < CHERT_BOTTOM:
		return "chert_band"
	if y < GRANITE_TOP:
		return "metamorphic"
	return "pluton"


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0


func is_vein(t: int) -> bool:
	return t in [VEIN_SHALLOW, VEIN_DEEP, VEIN_META, VEIN_GRANITE]


## Tiles that give samples when mined instead of rubble.
func gives_samples(t: int) -> bool:
	return is_vein(t) or t == GEODE or t == CRYSTAL


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
				elif t in [SHALE, LIMESTONE, DOLOSTONE] and y > surface + 5 and rare.randf() < 0.012:
					t = FOSSIL
			grid[y * WIDTH + x] = t
	_carve_caverns(rare)


## Rare glowing caverns lined with crystals, in the deeper rock. The hard bands stay whole.
func _carve_caverns(r: RandomNumberGenerator) -> void:
	caverns.clear()
	for i in 7:
		var c := Vector2(r.randi_range(10, WIDTH - 11), r.randi_range(BAND_BOTTOM + 5, HEIGHT - 8))
		var radius := Vector2(r.randf_range(3.5, 5.5), r.randf_range(2.5, 3.5))
		caverns.append(c * TILE + Vector2(TILE, TILE) / 2.0)
		for y in range(int(c.y - radius.y) - 2, int(c.y + radius.y) + 3):
			for x in range(int(c.x - radius.x) - 2, int(c.x + radius.x) + 3):
				if x < 1 or x > WIDTH - 2 or y > HEIGHT - 3:
					continue
				if (y >= CHERT_TOP and y < CHERT_BOTTOM) or (y >= BAND_TOP and y < BAND_BOTTOM):
					continue
				var d := Vector2((x - c.x) / radius.x, (y - c.y) / radius.y).length()
				if d < 1.0:
					grid[y * WIDTH + x] = AIR
				elif d < 1.45 and r.randf() < 0.7:
					grid[y * WIDTH + x] = CRYSTAL

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
	# Row 2: decorations, drawn in empty cells with no collision.
	var img := Image.create(TILE * TILE_COUNT, TILE * 3, false, Image.FORMAT_RGBA8)
	for i in TILE_COUNT:
		_paint_tile(img, i)
	for y in TILE:
		for x in TILE * TILE_COUNT:
			img.set_pixel(x, TILE + y, img.get_pixel(x, y).darkened(0.45))
	for i in DECO_COUNT:
		_paint_deco(img, i)
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
	for i in DECO_COUNT:
		src.create_tile(Vector2i(i, 2))
	return ts


func _paint_deco(img: Image, index: int) -> void:
	var oy := TILE * 2
	var ox := index * TILE
	for py in TILE:
		for px in TILE:
			var c := Color(0, 0, 0, 0)
			match index:
				STALACTITE:
					# Two icicle-shaped cones hanging from the ceiling.
					var w1 := 3.5 - py * 0.3
					var w2 := 2.5 - py * 0.35
					if absf(px - 5.5) < w1 or absf(px - 11.5) < w2:
						c = Color("d8d0bc") if px % 3 != 0 else Color("b9b09a")
				STALAGMITE:
					var h := TILE - 1 - py
					if absf(px - 8) < 4.0 - h * 0.35:
						c = Color("cfc6b0") if px % 3 != 0 else Color("aaa18c")
				TUFT:
					if py > 10 and (px % 3 == 1) and py > 10 + absi(px - 8) / 3:
						c = Color("4f9a3c")
				FLOWER:
					if px == 8 and py > 8:
						c = Color("4f9a3c")
					elif Vector2(px - 8, py - 6).length() < 2.2:
						c = Color("f7d64a") if Vector2(px - 8, py - 6).length() < 1.0 else Color("e2553f")
				MUSHROOM:
					if py >= 10 and absi(px - 8) <= 1:
						c = Color("e8e0d0")
					elif py >= 6 and py < 10 and absi(px - 8) <= 5 - (9 - py) / 2:
						c = Color("c9503c") if (px + py) % 4 != 0 else Color("f3ecf7")
			img.set_pixel(ox + px, oy + py, c)


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
				FOSSIL:
					# A pale ammonite spiral in grey limestone.
					var v := Vector2(px - 7.5, py - 7.5)
					var ang := atan2(v.y, v.x)
					var spiral := fposmod(v.length() - (ang + PI) * 0.8, 2.6)
					if v.length() < 6.0 and spiral < 1.0:
						c = Color("efe6cf")
					elif v.length() < 6.0:
						c = Color("8f8670")
				CRYSTAL:
					# Dark rock with three pointed crystals growing out of it.
					for k in 3:
						var cx: int = [4, 9, 13][k]
						var tip: int = [3, 1, 6][k]
						var half: float = (py - tip) * 0.35
						if py >= tip and absf(px - cx) <= half + 0.5:
							c = Color("9fe8ff") if k != 1 else Color("c99bff")
							if px < cx:
								c = c.lightened(0.3)
							elif absf(px - cx) > half - 0.6:
								c = c.darkened(0.25)
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
