extends Node2D
## Builds the world, player and interface, and turns taps into walking, mining and building.
## Tap empty space to walk there; tap higher up to jump or climb. Tap a block once to mine it; if it is out
## of reach the geologist walks over first. Drag over blocks to keep digging. In build mode a tap on empty
## space places a rubble block.

const World := preload("res://scripts/world.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const UiTheme := preload("res://scripts/ui_theme.gd")

const REACH_TILES := 4.5
const AUTOSAVE_SECONDS := 15.0
## How dark it gets underground, reached this many tiles below the surface.
const DARK_COLOR := Color(0.22, 0.2, 0.28)
const DARK_DEPTH_TILES := 14.0

var world: World
var player: Player
var hud: Hud
var overlay: MineOverlay
var shade: CanvasModulate

var build_mode := false
var pointer_down := false
var pointer_id := -100
var pointer_screen_pos := Vector2.ZERO
var mine_cell := Vector2i(-1, -1)   # the block being mined; stays set after the finger lifts
var mine_progress := 0.0
var _last_block_toast := ""
var _autosave := 0.0
var _depth_check := 0.0
var _shake := 0.0


class MineOverlay extends Node2D:
	## Twinkles on mineral veins and geodes in view, and the outline and progress bar on the tile being mined.
	var cell := Vector2i(-1, -1)
	var progress := 0.0
	var color := Color(1, 1, 1, 0.9)
	var world: Node2D
	var view := Rect2()
	var time := 0.0

	func _draw() -> void:
		_draw_sparkles()
		if cell.x < 0:
			return
		var r := Rect2(Vector2(cell) * 16.0, Vector2(16, 16))
		draw_rect(r, color, false, 1.0)
		if progress > 0.0:
			draw_rect(Rect2(r.position + Vector2(1, 13), Vector2(14 * progress, 2)), Color("f2c230"))

	func _draw_sparkles() -> void:
		var from := Vector2i((view.position / 16.0).floor())
		var to := Vector2i((view.end / 16.0).ceil())
		for y in range(maxi(from.y, 0), mini(to.y, World.HEIGHT)):
			for x in range(maxi(from.x, 0), mini(to.x, World.WIDTH)):
				var t: int = world.get_tile(Vector2i(x, y))
				if not world.gives_samples(t):
					continue
				var h := absi((x * 73856093) ^ (y * 19349663))
				var phase := time * 2.5 + float(h % 628) / 100.0
				var a := maxf(sin(phase), 0.0)
				if a < 0.2:
					continue
				var p := Vector2(x * 16 + 3 + h % 10, y * 16 + 3 + (h >> 4) % 10)
				var c := Color(1, 1, 0.85, a)
				var arm := 1.0 + 1.5 * a
				draw_rect(Rect2(p - Vector2(arm, 0.5), Vector2(arm * 2, 1)), c)
				draw_rect(Rect2(p - Vector2(0.5, arm), Vector2(1, arm * 2)), c)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("6db3e0"))
	_setup_input()
	world = World.new()
	add_child(world)
	world.build(GameState.world_seed, GameState.changed_cells)
	overlay = MineOverlay.new()
	overlay.world = world
	overlay.z_index = 10
	add_child(overlay)
	player = Player.new()
	add_child(player)
	if GameState.player_pos.size() == 2:
		player.position = Vector2(GameState.player_pos[0], GameState.player_pos[1])
	else:
		player.position = world.spawn_position()
	player.set_camera_limits(Vector2(World.WIDTH, World.HEIGHT) * World.TILE)
	shade = CanvasModulate.new()
	add_child(shade)
	hud = Hud.new()
	add_child(hud)
	hud.build_toggled.connect(func(on: bool): build_mode = on)
	hud.rope_pressed.connect(rope_to_surface)
	GameState.toast.connect(hud.show_toast)
	GameState.xp_gained.connect(_on_xp_gained)
	if GameState.in_tutorial():
		hud.show_toast("Welcome, geologist! Follow the goals at the top right to learn the ropes.")
	else:
		hud.show_toast("Welcome back! Tap a glittering vein to collect samples.")
	var reward := GameState.claim_daily()
	if not reward.is_empty():
		hud.show_daily(reward)


func _setup_input() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_W, KEY_SPACE, KEY_UP]}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if hud.panel_open():
		release_pointer()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not pointer_down and not hud.is_over_controls(event.position):
			press_pointer(event.index, event.position)
		elif not event.pressed and event.index == pointer_id:
			release_pointer()
	elif event is InputEventScreenDrag:
		if event.index == pointer_id:
			drag_pointer(event.position)
	# Mouse events copied from touches have device -1; only real mice count here.
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not hud.is_over_controls(event.position):
			press_pointer(-1, event.position)
		elif not event.pressed and pointer_id == -1:
			release_pointer()
	elif event is InputEventMouseMotion and event.device != -1 and pointer_id == -1:
		drag_pointer(event.position)


func press_pointer(id: int, screen_pos: Vector2) -> void:
	pointer_down = true
	pointer_id = id
	pointer_screen_pos = screen_pos
	var world_pos := screen_to_world(screen_pos)
	var cell := world.cell_at(world_pos)
	var t := world.get_tile(cell)
	if build_mode and t == World.AIR:
		try_place(cell)
	elif t == World.AIR:
		cancel_mining()
		GameState.track("walk")
		player.walk_to(world_pos.x)
		if world_pos.y < player.position.y - World.TILE * 1.5:
			player.climb_to(world_pos.y)
	else:
		target_block(cell)


## While a finger is down, sliding onto another block retargets the digging.
func drag_pointer(screen_pos: Vector2) -> void:
	pointer_screen_pos = screen_pos
	if build_mode:
		return
	var cell := world.cell_at(screen_to_world(screen_pos))
	if cell != mine_cell and world.get_tile(cell) != World.AIR and mine_cell.x >= 0:
		target_block(cell)


func target_block(cell: Vector2i) -> void:
	mine_cell = cell
	mine_progress = 0.0
	_last_block_toast = ""
	if not in_reach(cell):
		player.walk_to(world.cell_center(cell).x)


func cancel_mining() -> void:
	mine_cell = Vector2i(-1, -1)
	mine_progress = 0.0


func release_pointer() -> void:
	pointer_down = false
	pointer_id = -100


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func in_reach(cell: Vector2i) -> bool:
	return player.position.distance_to(world.cell_center(cell)) <= REACH_TILES * World.TILE


func _process(delta: float) -> void:
	overlay.cell = Vector2i(-1, -1)
	if mine_cell.x >= 0:
		if world.get_tile(mine_cell) == World.AIR:
			cancel_mining()
		else:
			overlay.cell = mine_cell
			overlay.color = Color(1, 1, 1, 0.9) if in_reach(mine_cell) else Color(1, 1, 1, 0.35)
			_mine_tick(delta)
	overlay.progress = mine_progress
	overlay.time += delta
	overlay.view = Rect2(screen_to_world(Vector2.ZERO), get_viewport().get_visible_rect().size / player.camera.zoom)
	overlay.queue_redraw()
	var below := player.position.y / World.TILE - World.SURFACE_Y
	shade.color = Color.WHITE.lerp(DARK_COLOR, clampf(below / DARK_DEPTH_TILES, 0.0, 1.0))
	player.lamp.energy = clampf(below / DARK_DEPTH_TILES, 0.0, 1.0) * 1.1
	player.lamp.texture_scale = 1.0 + 0.25 * GameState.upgrade_level("lamp")
	var depth := maxi(world.depth_m(player.position.y), 0)
	hud.set_depth(depth)
	_depth_check += delta
	if _depth_check > 0.5:
		_depth_check = 0.0
		GameState.track("depth", depth)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 12.0, 0.0)
		player.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		save()


func _mine_tick(delta: float) -> void:
	if not in_reach(mine_cell):
		return
	var t := world.get_tile(mine_cell)
	if t == World.BEDROCK:
		_toast_once("Bedrock. This is as deep as this build goes.")
		cancel_mining()
		return
	if not world.gives_samples(t) and world.hardness_of(t) > GameState.pick_hardness():
		if _toast_once("%s (hardness %s) is too hard for your %s (hardness %s)." % [
				world.tile_name(t), world.hardness_of(t), GameState.pick_name(), GameState.pick_hardness()]):
			Sfx.play("blocked")
		cancel_mining()
		return
	player.stop_walking()
	mine_progress += delta * GameState.dig_speed() / world.mine_time(t)
	if mine_progress >= 1.0:
		finish_mining(mine_cell)
		mine_progress = 0.0


## Breaks a tile for rubble, or collects samples from a vein or geode.
func finish_mining(cell: Vector2i) -> void:
	var t := world.get_tile(cell)
	if t == World.GEODE:
		_open_geode(cell)
		return
	if not world.is_vein(t):
		world.set_tile(cell, World.AIR)
		GameState.rubble += 1
		GameState.blocks_dug += 1
		Sfx.play("dig")
		_burst(cell, World.TILES[t]["color"], 8)
		shake(1.5)
		GameState.add_xp(GameState.XP_DIG)
		GameState.track("dig")
		_maybe_gold(cell)
		_maybe_rock_sample(cell, t)
		return
	var tier := world.tier_at(cell.y)
	var mineral_id := GameState.roll_mineral(tier)
	var sample := GameState.add_sample(mineral_id, world.depth_m(cell.y * World.TILE), tier)
	if sample.is_empty():
		hud.show_toast("Your bag is full. Open the Bag and name some samples first.")
		Sfx.play("blocked")
		return
	Sfx.play("sample")
	GameState.buzz(30)
	_burst(cell, GameData.color_of(sample["color"]), 14)
	shake(2.5)
	GameState.add_xp(GameState.XP_SAMPLE)
	GameState.track("sample")
	# Prospector's eye upgrade: a chance of a second sample from the same vein.
	if GameState.rng.randf() < 0.08 * GameState.luck():
		var bonus := GameState.add_sample(GameState.roll_mineral(tier), world.depth_m(cell.y * World.TILE), tier)
		if not bonus.is_empty():
			GameState.track("sample")
			hud.float_text(world_to_screen(world.cell_center(cell)) + Vector2(0, -24), "Bonus sample!",
				UiTheme.colors()["accent"], "star")
	var m := GameData.mineral(mineral_id)
	if GameState.pick_hardness() >= float(m["hardness"]["min"]):
		world.set_tile(cell, World.AIR)
		hud.show_toast("Collected an unknown %s sample. Test it in your Field Kit." % sample["color"])
	else:
		world.set_tile(cell, world.host_for(cell.y))
		hud.show_toast("The vein is harder than your pick (%s), but you chipped off a %s sample." % [
			GameState.pick_hardness(), sample["color"]])


## Digging host rock sometimes gives a hand specimen of that rock to identify.
func _maybe_rock_sample(cell: Vector2i, t: int) -> void:
	if not World.ROCK_OF.has(t):
		return
	var rock_id: String = World.ROCK_OF[t]
	if not GameState.roll_rock_sample(rock_id):
		return
	var swatch: Color = World.TILES[t]["color"]
	if GameState.add_rock_sample(rock_id, world.depth_m(cell.y * World.TILE), world.tier_at(cell.y), swatch.to_html(false)).is_empty():
		return
	Sfx.play("sample")
	GameState.buzz(20)
	GameState.add_xp(GameState.XP_SAMPLE)
	GameState.track("sample")
	hud.show_toast("You kept a rock sample. Name it in your Bag.")


func _open_geode(cell: Vector2i) -> void:
	var got := 0
	for i in 2:
		var id := GameState.roll_geode_crystal()
		var tier := maxi(world.tier_at(cell.y), int(GameData.mineral(id)["tier"]))
		if not GameState.add_sample(id, world.depth_m(cell.y * World.TILE), tier, GameState.GEODE_CRYSTALS[id]).is_empty():
			got += 1
	world.set_tile(cell, World.AIR)
	Sfx.play("geode")
	GameState.buzz(90)
	_burst(cell, Color("b07ad6"), 24)
	shake(4.0)
	GameState.add_xp(GameState.XP_GEODE)
	GameState.track("sample", got)
	GameState.track("geode")
	hud.show_banner("Geode!", "%d crystal samples from its hollow center." % got)


func try_place(cell: Vector2i) -> bool:
	if not in_reach(cell):
		hud.show_toast("Too far away to build there.")
		return false
	if GameState.rubble <= 0:
		hud.show_toast("No rubble left. Dig some rock first.")
		return false
	var player_rect := Rect2(player.position - Vector2(5, 8), Vector2(10, 16))
	if player_rect.intersects(Rect2(Vector2(cell) * World.TILE, Vector2(World.TILE, World.TILE))):
		return false
	world.set_tile(cell, World.RUBBLE)
	GameState.rubble -= 1
	Sfx.play("place")
	GameState.track("build")
	hud._refresh()
	return true


## Climb the rope back to the surface above where you stand.
func rope_to_surface() -> void:
	var x := clampi(int(player.position.x / World.TILE), 1, World.WIDTH - 2)
	var y := 0
	while y < World.HEIGHT and world.get_tile(Vector2i(x, y)) == World.AIR:
		y += 1
	player.position = Vector2(x * World.TILE + World.TILE / 2.0, (y - 1) * World.TILE)
	player.velocity = Vector2.ZERO
	player.stop_walking()
	player.camera.reset_smoothing()
	Sfx.play("craft")


## Digging rock sometimes turns up gold flakes, worth a few coins.
func _maybe_gold(cell: Vector2i) -> void:
	if GameState.rng.randf() >= 0.04 + 0.01 * GameState.luck():
		return
	var amount := GameState.rng.randi_range(1, 3) * world.tier_at(cell.y)
	GameState.add_coins(amount)
	Sfx.play("coin")
	hud.float_text(world_to_screen(world.cell_center(cell)) + Vector2(0, -20), "+%d gold" % amount,
		UiTheme.colors()["coin"], "coin")


## Pixel debris flying out of a broken block.
func _burst(cell: Vector2i, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = world.cell_center(cell)
	p.z_index = 5
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.55
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color.lightened(0.15)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(6, 6)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


## Shakes the camera a little, if screen shake is on.
func shake(strength: float) -> void:
	if GameState.settings["shake"]:
		_shake = maxf(_shake, strength)


func _on_xp_gained(amount: int, coins: int) -> void:
	if hud.panel_open() or amount <= 0:
		return
	var pos := world_to_screen(player.position + Vector2(0, -14))
	hud.float_text(pos, "+%d XP" % amount, UiTheme.colors()["xp"])
	if coins > 0:
		hud.float_text(pos + Vector2(0, -16), "+%d" % coins, UiTheme.colors()["coin"], "coin")


func _toast_once(text: String) -> bool:
	if text == _last_block_toast:
		return false
	_last_block_toast = text
	hud.show_toast(text)
	return true


func save() -> void:
	_autosave = 0.0
	GameState.player_pos = [player.position.x, player.position.y]
	GameState.save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player:
			save()
