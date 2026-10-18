extends Node2D
## Builds the world, player and interface, and runs mining (hold a finger or the mouse on a tile).

const World := preload("res://scripts/world.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")

const REACH_TILES := 4.5
const NO_POINTER := -2
const MOUSE_POINTER := -1
const AUTOSAVE_SECONDS := 15.0

var world: World
var player: Player
var hud: Hud
var overlay: MineOverlay

var mining_pointer := NO_POINTER
var mining_screen_pos := Vector2.ZERO
var mine_cell := Vector2i(-1, -1)
var mine_progress := 0.0
var _last_block_toast := ""
var _autosave := 0.0


class MineOverlay extends Node2D:
	## Outline and progress bar on the tile being mined.
	var cell := Vector2i(-1, -1)
	var progress := 0.0

	func _draw() -> void:
		if cell.x < 0:
			return
		var r := Rect2(Vector2(cell) * 16.0, Vector2(16, 16))
		draw_rect(r, Color(1, 1, 1, 0.9), false, 1.0)
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
	hud = Hud.new()
	add_child(hud)
	GameState.toast.connect(hud.show_toast)
	hud.show_toast("Hold on a glittering vein to collect a sample.")


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
		_stop_mining()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not hud.is_over_controls(event.position):
			_start_mining(event.index, event.position)
		elif not event.pressed and event.index == mining_pointer:
			_stop_mining()
	elif event is InputEventScreenDrag:
		if event.index == mining_pointer:
			mining_screen_pos = event.position
	# Mouse events copied from touches have device -1; only real mice mine with the mouse.
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_mining(MOUSE_POINTER, event.position)
		elif mining_pointer == MOUSE_POINTER:
			_stop_mining()
	elif event is InputEventMouseMotion and event.device != -1 and mining_pointer == MOUSE_POINTER:
		mining_screen_pos = event.position


func _start_mining(pointer: int, pos: Vector2) -> void:
	mining_pointer = pointer
	mining_screen_pos = pos
	mine_progress = 0.0


func _stop_mining() -> void:
	mining_pointer = NO_POINTER
	mine_progress = 0.0
	mine_cell = Vector2i(-1, -1)
	_last_block_toast = ""


func _process(delta: float) -> void:
	if mining_pointer != NO_POINTER:
		var cell := world.cell_at(get_viewport().get_canvas_transform().affine_inverse() * mining_screen_pos)
		if cell != mine_cell:
			mine_cell = cell
			mine_progress = 0.0
		_mine_tick(delta)
	overlay.cell = mine_cell if mining_pointer != NO_POINTER else Vector2i(-1, -1)
	overlay.progress = mine_progress
	overlay.queue_redraw()
	hud.set_status("Depth %d m   %s (H %s)" % [world.depth_m(player.position.y), GameState.pick_name(), GameState.pick_hardness()])
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		save()


func _mine_tick(delta: float) -> void:
	var t := world.get_tile(mine_cell)
	if t == World.AIR:
		return
	if player.position.distance_to(world.cell_center(mine_cell)) > REACH_TILES * World.TILE:
		return
	if t == World.BEDROCK:
		_toast_once("Bedrock. This is as deep as the first build goes.")
		return
	if not world.is_vein(t) and world.hardness_of(t) > GameState.pick_hardness():
		_toast_once("%s (hardness %s) is too hard for your %s (hardness %s)." % [
			world.tile_name(t), world.hardness_of(t), GameState.pick_name(), GameState.pick_hardness()])
		return
	mine_progress += delta / world.mine_time(t)
	if mine_progress >= 1.0:
		finish_mining(mine_cell)
		mine_progress = 0.0


## Breaks a tile, or collects a sample from a vein.
func finish_mining(cell: Vector2i) -> void:
	var t := world.get_tile(cell)
	if not world.is_vein(t):
		world.set_tile(cell, World.AIR)
		return
	var tier := world.tier_at(cell.y)
	var mineral_id := GameState.roll_mineral(tier)
	var sample := GameState.add_sample(mineral_id, world.depth_m(cell.y * World.TILE), tier)
	if sample.is_empty():
		hud.show_toast("Sample bag full. Identify some samples in your Field Kit.")
		return
	var m := GameData.mineral(mineral_id)
	if GameState.pick_hardness() >= float(m["hardness"]["min"]):
		world.set_tile(cell, World.AIR)
		hud.show_toast("Collected an unknown %s sample. Test it in your Field Kit." % sample["color"])
	else:
		world.set_tile(cell, world.host_for(cell.y))
		hud.show_toast("The vein is harder than your pick (%s), but you chipped off a %s sample." % [
			GameState.pick_hardness(), sample["color"]])


func _toast_once(text: String) -> void:
	if text != _last_block_toast:
		_last_block_toast = text
		hud.show_toast(text)


func save() -> void:
	_autosave = 0.0
	GameState.player_pos = [player.position.x, player.position.y]
	GameState.save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player:
			save()
