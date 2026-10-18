extends Node2D
## Builds the world, player and interface, and turns taps into walking, mining and building.
## Tap empty space to walk there (higher up: jump). Hold on a block to mine it; if it is out of reach
## the geologist walks over first. In build mode a tap on empty space places a rubble block.

const World := preload("res://scripts/world.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")

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
var mine_cell := Vector2i(-1, -1)
var mine_progress := 0.0
var _last_block_toast := ""
var _autosave := 0.0


class MineOverlay extends Node2D:
	## Outline and progress bar on the tile being mined or built on.
	var cell := Vector2i(-1, -1)
	var progress := 0.0
	var color := Color(1, 1, 1, 0.9)

	func _draw() -> void:
		if cell.x < 0:
			return
		var r := Rect2(Vector2(cell) * 16.0, Vector2(16, 16))
		draw_rect(r, color, false, 1.0)
		if progress > 0.0:
			draw_rect(Rect2(r.position + Vector2(1, 13), Vector2(14 * progress, 2)), Color("f2c230"))


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("6db3e0"))
	_setup_input()
	world = World.new()
	add_child(world)
	world.build(GameState.world_seed, GameState.changed_cells)
	overlay = MineOverlay.new()
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
	hud.show_toast("Tap to walk. Hold on a glittering vein to collect a sample.")


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
			pointer_screen_pos = event.position
	# Mouse events copied from touches have device -1; only real mice count here.
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not hud.is_over_controls(event.position):
			press_pointer(-1, event.position)
		elif not event.pressed and pointer_id == -1:
			release_pointer()
	elif event is InputEventMouseMotion and event.device != -1 and pointer_id == -1:
		pointer_screen_pos = event.position


func press_pointer(id: int, screen_pos: Vector2) -> void:
	pointer_down = true
	pointer_id = id
	pointer_screen_pos = screen_pos
	mine_progress = 0.0
	var world_pos := screen_to_world(screen_pos)
	var cell := world.cell_at(world_pos)
	var t := world.get_tile(cell)
	if build_mode and t == World.AIR:
		try_place(cell)
	elif t == World.AIR:
		player.walk_to(world_pos.x)
		if world_pos.y < player.position.y - World.TILE * 1.5:
			player.jump_requested = true
	elif not in_reach(cell):
		player.walk_to(world.cell_center(cell).x)


func release_pointer() -> void:
	pointer_down = false
	pointer_id = -100
	mine_progress = 0.0
	mine_cell = Vector2i(-1, -1)
	_last_block_toast = ""


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func in_reach(cell: Vector2i) -> bool:
	return player.position.distance_to(world.cell_center(cell)) <= REACH_TILES * World.TILE


func _process(delta: float) -> void:
	overlay.cell = Vector2i(-1, -1)
	if pointer_down and not build_mode:
		var cell := world.cell_at(screen_to_world(pointer_screen_pos))
		if cell != mine_cell:
			mine_cell = cell
			mine_progress = 0.0
		if world.get_tile(cell) != World.AIR:
			overlay.cell = cell
			overlay.color = Color(1, 1, 1, 0.9) if in_reach(cell) else Color(1, 1, 1, 0.35)
			_mine_tick(delta)
	overlay.progress = mine_progress
	overlay.queue_redraw()
	var below := player.position.y / World.TILE - World.SURFACE_Y
	shade.color = Color.WHITE.lerp(DARK_COLOR, clampf(below / DARK_DEPTH_TILES, 0.0, 1.0))
	player.lamp.energy = clampf(below / DARK_DEPTH_TILES, 0.0, 1.0) * 1.1
	hud.set_status("%d m   %s %s   %s   Rubble %d" % [world.depth_m(player.position.y), GameState.pick_name(),
		GameState.pick_hardness(), GameState.rank_name(), GameState.rubble])
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		save()


func _mine_tick(delta: float) -> void:
	if not in_reach(mine_cell):
		return
	var t := world.get_tile(mine_cell)
	if t == World.BEDROCK:
		_toast_once("Bedrock. This is as deep as this build goes.")
		return
	if not world.gives_samples(t) and world.hardness_of(t) > GameState.pick_hardness():
		if _toast_once("%s (hardness %s) is too hard for your %s (hardness %s)." % [
				world.tile_name(t), world.hardness_of(t), GameState.pick_name(), GameState.pick_hardness()]):
			Sfx.play("blocked")
		return
	player.stop_walking()
	mine_progress += delta / world.mine_time(t)
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
		Sfx.play("dig")
		return
	var tier := world.tier_at(cell.y)
	var mineral_id := GameState.roll_mineral(tier)
	var sample := GameState.add_sample(mineral_id, world.depth_m(cell.y * World.TILE), tier)
	if sample.is_empty():
		hud.show_toast("Sample bag full. Identify some samples in your Field Kit.")
		return
	Sfx.play("sample")
	var m := GameData.mineral(mineral_id)
	if GameState.pick_hardness() >= float(m["hardness"]["min"]):
		world.set_tile(cell, World.AIR)
		hud.show_toast("Collected an unknown %s sample. Test it in your Field Kit." % sample["color"])
	else:
		world.set_tile(cell, world.host_for(cell.y))
		hud.show_toast("The vein is harder than your pick (%s), but you chipped off a %s sample." % [
			GameState.pick_hardness(), sample["color"]])


func _open_geode(cell: Vector2i) -> void:
	var got := 0
	for i in 2:
		var id := GameState.roll_geode_crystal()
		var tier := maxi(world.tier_at(cell.y), int(GameData.mineral(id)["tier"]))
		if not GameState.add_sample(id, world.depth_m(cell.y * World.TILE), tier, GameState.GEODE_CRYSTALS[id]).is_empty():
			got += 1
	world.set_tile(cell, World.AIR)
	Sfx.play("geode")
	hud.show_toast("A geode! %d crystal samples from its hollow center." % got)


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
