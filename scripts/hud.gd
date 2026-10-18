extends CanvasLayer
## On-screen interface: info card (level, XP, depth, pick, coins, streak), goal tracker, big thumb buttons,
## messages, floating rewards, level-up banner, discovery cards and the menu panels.

signal build_toggled(on: bool)
signal rope_pressed

const UiTheme := preload("res://scripts/ui_theme.gd")
const FieldKit := preload("res://scripts/field_kit.gd")
const Codex := preload("res://scripts/codex.gd")
const Workshop := preload("res://scripts/craft.gd")
const Settings := preload("res://scripts/settings.gd")
const School := preload("res://scripts/school.gd")

enum { PANEL_BAG, PANEL_CODEX, PANEL_WORKSHOP, PANEL_SETTINGS, PANEL_SCHOOL }
const MARGIN := 8
const HUD_BUTTON := Vector2(62, 54)

var root: Control
var info_card: PanelContainer
var level_label: Label
var rank_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var depth_label: Label
var pick_label: Label
var coin_label: Label
var streak_box: HBoxContainer
var streak_label: Label
var goal_card: PanelContainer
var goal_list: VBoxContainer
var goals_collapsed := false
var gear_button: Button
var left_bar: HBoxContainer
var right_bar: HBoxContainer
var bag_button: Button
var codex_button: Button
var workshop_button: Button
var school_button: Button
var build_button: Button
var rope_button: Button
var toast_card: PanelContainer
var toast_label: Label
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
var popup: PanelContainer
var panels: Array[Control] = []
var _toast_left := 0.0
var _banner_left := 0.0
var _depth := -1
var _time := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	_build_info_card()
	_build_goal_card()
	_build_buttons()
	_build_messages()
	for script in [FieldKit, Codex, Workshop, Settings, School]:
		var p: Control = script.new()
		p.visible = false
		root.add_child(p)
		panels.append(p)
	GameState.changed.connect(_refresh)
	GameState.settings_changed.connect(_apply_settings)
	GameState.leveled_up.connect(func(level: int):
		show_banner("Level %d!" % level, GameState.rank_name()))
	GameState.milestone.connect(show_banner)
	GameState.goal_completed.connect(func(g: Dictionary):
		show_toast("Goal complete: %s  +%d XP  +%d coins" % [g["text"], g["xp"], g["coins"]]))
	_refresh()


## Keeps a control at a screen corner at its minimum size, MARGIN from the edges.
static func pin(c: Control, right: bool, bottom: bool, margin := MARGIN) -> void:
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	c.offset_left = -margin if right else margin
	c.offset_right = c.offset_left
	c.offset_top = -margin if bottom else margin
	c.offset_bottom = c.offset_top
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END


static func icon_rect(name: String, size := 18) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func label(text := "", variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_info_card() -> void:
	info_card = PanelContainer.new()
	info_card.theme_type_variation = "HudCard"
	info_card.mouse_filter = Control.MOUSE_FILTER_STOP
	pin(info_card, false, false)
	root.add_child(info_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	info_card.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(icon_rect("star"))
	level_label = label("", "Title")
	top.add_child(level_label)
	rank_label = label("", "Muted")
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rank_label)
	xp_bar = ProgressBar.new()
	xp_bar.theme_type_variation = "XpBar"
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(190, 8)
	xp_bar.max_value = 1.0
	xp_bar.step = 0.0
	v.add_child(xp_bar)
	xp_label = label("", "Muted")
	v.add_child(xp_label)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	v.add_child(stats)
	stats.add_child(icon_rect("depth"))
	depth_label = label()
	stats.add_child(depth_label)
	stats.add_child(icon_rect("pick"))
	pick_label = label()
	stats.add_child(pick_label)
	stats.add_child(icon_rect("coin"))
	coin_label = label()
	stats.add_child(coin_label)
	streak_box = HBoxContainer.new()
	streak_box.add_child(icon_rect("flame"))
	streak_label = label()
	streak_box.add_child(streak_label)
	stats.add_child(streak_box)


func _build_goal_card() -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	pin(box, true, false)
	root.add_child(box)
	goal_card = PanelContainer.new()
	goal_card.theme_type_variation = "HudCard"
	goal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_card.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			goals_collapsed = not goals_collapsed
			Sfx.play("tap")
			_refresh())
	box.add_child(goal_card)
	goal_list = VBoxContainer.new()
	goal_list.add_theme_constant_override("separation", 2)
	goal_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_card.add_child(goal_list)
	gear_button = Button.new()
	gear_button.theme_type_variation = "HudButton"
	gear_button.icon = UiTheme.icon("gear")
	gear_button.tooltip_text = "Settings"
	gear_button.custom_minimum_size = Vector2(UiTheme.TAP, UiTheme.TAP)
	gear_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear_button.expand_icon = true
	gear_button.pressed.connect(func(): open_panel(PANEL_SETTINGS))
	box.add_child(gear_button)


func _hud_button(text: String, icon: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "HudButton"
	b.text = text
	b.icon = UiTheme.icon(icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.custom_minimum_size = HUD_BUTTON
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_buttons() -> void:
	left_bar = HBoxContainer.new()
	left_bar.add_theme_constant_override("separation", 6)
	pin(left_bar, false, true)
	root.add_child(left_bar)
	bag_button = _hud_button("Bag", "bag")
	bag_button.pressed.connect(func(): open_panel(PANEL_BAG))
	left_bar.add_child(bag_button)
	codex_button = _hud_button("Codex", "codex")
	codex_button.pressed.connect(func(): open_panel(PANEL_CODEX))
	left_bar.add_child(codex_button)
	workshop_button = _hud_button("Workshop", "anvil")
	workshop_button.custom_minimum_size.x = 76
	workshop_button.pressed.connect(func(): open_panel(PANEL_WORKSHOP))
	left_bar.add_child(workshop_button)
	school_button = _hud_button("School", "cap")
	school_button.pressed.connect(func(): open_panel(PANEL_SCHOOL))
	left_bar.add_child(school_button)
	right_bar = HBoxContainer.new()
	right_bar.add_theme_constant_override("separation", 6)
	pin(right_bar, true, true)
	root.add_child(right_bar)
	build_button = _hud_button("Build", "brick")
	build_button.toggle_mode = true
	build_button.toggled.connect(func(on: bool):
		Sfx.play("tap")
		if on:
			show_toast("Build mode: tap open space near you to place a rubble block.")
		_refresh()
		build_toggled.emit(on))
	right_bar.add_child(build_button)
	rope_button = _hud_button("Rope up", "rope")
	rope_button.custom_minimum_size.x = 70
	rope_button.pressed.connect(func(): rope_pressed.emit())
	right_bar.add_child(rope_button)


func _build_messages() -> void:
	toast_card = PanelContainer.new()
	toast_card.theme_type_variation = "HudCard"
	toast_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_card.anchor_left = 0.5
	toast_card.anchor_right = 0.5
	toast_card.anchor_top = 1.0
	toast_card.anchor_bottom = 1.0
	toast_card.offset_top = -HUD_BUTTON.y - MARGIN - 8
	toast_card.offset_bottom = toast_card.offset_top
	toast_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_card.visible = false
	root.add_child(toast_card)
	toast_label = label()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(300, 0)
	toast_card.add_child(toast_label)

	banner = PanelContainer.new()
	banner.theme_type_variation = "Card"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.offset_top = -70
	banner.offset_bottom = -70
	banner.visible = false
	root.add_child(banner)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(bv)
	banner_title = label("", "Title")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_font_size_override("font_size", UiTheme.font_size() + 12)
	bv.add_child(banner_title)
	banner_text = label()
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_text)


func _apply_settings() -> void:
	root.theme = UiTheme.make()
	banner_title.add_theme_font_size_override("font_size", UiTheme.font_size() + 12)
	_refresh()


func _refresh() -> void:
	var gs := GameState
	level_label.text = "Lv %d" % gs.level()
	rank_label.text = gs.rank_name()
	var tween := create_tween()
	tween.tween_property(xp_bar, "value", gs.level_progress(), 0.35)
	xp_label.text = "%d / %d XP to level %d" % [gs.xp - gs.xp_for_level(gs.level()),
		gs.xp_for_level(gs.level() + 1) - gs.xp_for_level(gs.level()), gs.level() + 1]
	pick_label.text = "%s  " % gs.pick_hardness()
	coin_label.text = "%d  " % gs.coins
	streak_box.visible = gs.streak >= 2
	streak_label.text = "x%d" % gs.streak
	var full := gs.samples.size() >= gs.max_samples()
	bag_button.text = "Bag %d/%d" % [gs.samples.size(), gs.max_samples()] if gs.samples.size() > 0 else "Bag"
	bag_button.custom_minimum_size.x = 84 if gs.samples.size() > 0 else HUD_BUTTON.x
	bag_button.add_theme_color_override("font_color", UiTheme.colors()["bad"] if full else UiTheme.colors()["text"])
	var shop_ready := false
	for u in gs.UPGRADES:
		shop_ready = shop_ready or gs.can_buy(u["id"])
	for r in gs.RECIPES:
		shop_ready = shop_ready or gs.can_craft(r)
	workshop_button.text = "Workshop!" if shop_ready else "Workshop"
	build_button.text = "Build %d" % gs.rubble if build_button.button_pressed else "Build"
	var waiting := gs.lessons_waiting()
	school_button.text = "School %d" % waiting if waiting > 0 else "School"
	school_button.custom_minimum_size.x = 78 if waiting > 0 else HUD_BUTTON.x
	_refresh_goals()


func _refresh_goals() -> void:
	for c in goal_list.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_list.add_child(head)
	head.add_child(icon_rect("goal", 14))
	var title := "Tutorial" if GameState.in_tutorial() else "Goals"
	head.add_child(label("%s  %s" % [title, "(tap to show)" if goals_collapsed else ""], "Muted"))
	if goals_collapsed:
		return
	for g in GameState.goals:
		var l := label(g["text"], "Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 0)
		goal_list.add_child(l)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		goal_list.add_child(row)
		var bar := ProgressBar.new()
		bar.theme_type_variation = "GoodBar"
		bar.show_percentage = false
		bar.max_value = int(g["target"])
		bar.value = mini(int(g["progress"]), int(g["target"]))
		bar.custom_minimum_size = Vector2(110, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		var unit := " m" if g["event"] == "depth" else ""
		row.add_child(label("%d/%d%s" % [mini(int(g["progress"]), int(g["target"])), int(g["target"]), unit], "Muted"))


## Called every frame by main with the current depth.
func set_depth(depth_m: int) -> void:
	if depth_m != _depth:
		_depth = depth_m
		depth_label.text = "%d m  " % depth_m


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_card.visible = true
	toast_card.modulate.a = 1.0
	_toast_left = 4.0


func show_banner(title: String, text: String) -> void:
	banner_title.text = title
	banner_text.text = text
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_left = 2.5


## A reward that rises from a screen position and fades, like "+5 XP".
func float_text(screen_pos: Vector2, text: String, color: Color, icon := "") -> void:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		box.add_child(icon_rect(icon, 14))
	var l := label(text, "HudLabel")
	l.add_theme_color_override("font_color", color)
	box.add_child(l)
	root.add_child(box)
	box.position = screen_pos - Vector2(20, 10)
	var tween := create_tween().set_parallel()
	tween.tween_property(box, "position:y", box.position.y - 36, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(box, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(box.queue_free)


## A discovery card (new fossil, new zone) with an optional photo, a short explanation and up to two
## buttons. The first button closes the card; `more` runs when the second is pressed.
func show_card(title: String, subtitle: String, body: String, photo_id := "", more_label := "",
		more := Callable()) -> void:
	if popup != null:
		popup.queue_free()
	popup = PanelContainer.new()
	popup.theme_type_variation = "Card"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(popup)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	popup.add_child(row)
	var credits: Dictionary = GameData.credits.get(photo_id, {})
	if not credits.is_empty() and ResourceLoader.exists(credits["image"]):
		var pic := TextureRect.new()
		pic.texture = load(credits["image"])
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(150, 150)
		row.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(300, 0)
	row.add_child(v)
	v.add_child(label(title, "Title"))
	if subtitle != "":
		v.add_child(label(subtitle, "Muted"))
	var l := label(body)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var buttons := HBoxContainer.new()
	v.add_child(buttons)
	var ok := Button.new()
	ok.theme_type_variation = "Accent"
	ok.text = "Keep digging"
	ok.custom_minimum_size = Vector2(130, UiTheme.TAP)
	ok.pressed.connect(close_card)
	buttons.add_child(ok)
	if more_label != "":
		var m := Button.new()
		m.text = more_label
		m.custom_minimum_size = Vector2(130, UiTheme.TAP)
		m.pressed.connect(func():
			close_card()
			more.call())
		buttons.add_child(m)
	popup.pivot_offset = popup.size / 2.0
	popup.modulate.a = 0.0
	create_tween().tween_property(popup, "modulate:a", 1.0, 0.2)


func close_card() -> void:
	Sfx.play("tap")
	if popup != null:
		popup.queue_free()
		popup = null


func _process(delta: float) -> void:
	_time += delta
	if _toast_left > 0.0:
		_toast_left -= delta
		toast_card.modulate.a = clampf(_toast_left, 0.0, 1.0)
		if _toast_left <= 0.0:
			toast_card.visible = false
	if _banner_left > 0.0:
		_banner_left -= delta
		banner.modulate.a = clampf(_banner_left * 2.0, 0.0, 1.0)
		if _banner_left <= 0.0:
			banner.visible = false
	# The tutorial points at the button you need next by pulsing it.
	var hint := GameState.tutorial_hint()
	var glow := Color.WHITE.lerp(UiTheme.colors()["accent"], 0.5 + 0.5 * sin(_time * 6.0))
	bag_button.modulate = glow if hint == "bag" and not panel_open() else Color.WHITE
	codex_button.modulate = glow if hint == "codex" and not panel_open() else Color.WHITE
	# A new lesson waiting makes the School button glow softly.
	var soft := Color.WHITE.lerp(UiTheme.colors()["accent"], 0.25 + 0.25 * sin(_time * 3.0))
	school_button.modulate = soft if GameState.lessons_waiting() > 0 and not panel_open() else Color.WHITE


func open_panel(index: int) -> void:
	Sfx.play("tap")
	for p in panels:
		p.visible = false
	var p := panels[index]
	p.call("open")
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.12)
	if index == PANEL_CODEX:
		GameState.track("codex")


func panel_open() -> bool:
	if popup != null:
		return true
	for p in panels:
		if p.visible:
			return true
	return false


## True when a screen position is on part of the interface, so the tap is not also a walk or mine.
func is_over_controls(pos: Vector2) -> bool:
	for c in [info_card, goal_card, gear_button, left_bar, right_bar]:
		if c.visible and c.get_global_rect().grow(4).has_point(pos):
			return true
	return false
