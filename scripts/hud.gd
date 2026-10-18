extends CanvasLayer
## Status bar, touch controls, messages and the menu panels.

const FieldKit := preload("res://scripts/field_kit.gd")
const Codex := preload("res://scripts/codex.gd")
const Craft := preload("res://scripts/craft.gd")

const BUTTON_SIZE := 44
const MARGIN := 12

var root: Control
var top_bar: PanelContainer
var status_label: Label
var kit_button: Button
var toast_label: Label
var touch_buttons: Array[TouchScreenButton] = []
var panels: Array[Control] = []
var _toast_left := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	add_child(root)
	_build_top_bar()
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(440, 0)
	toast_label.position = Vector2(-220, 40)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 4)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	for spec in [["move_left", "left"], ["move_right", "right"], ["jump", "up"]]:
		var b := TouchScreenButton.new()
		b.action = spec[0]
		b.texture_normal = _arrow_texture(spec[1], false)
		b.texture_pressed = _arrow_texture(spec[1], true)
		b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		add_child(b)
		touch_buttons.append(b)
	for script in [FieldKit, Codex, Craft]:
		var p: Control = script.new()
		p.visible = false
		root.add_child(p)
		panels.append(p)
	get_viewport().size_changed.connect(_layout)
	GameState.changed.connect(_refresh_buttons)
	_layout()
	_refresh_buttons()


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("241c2b")
	panel.border_color = Color("c9a45c")
	panel.set_border_width_all(2)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("4a3a55"), "hover": Color("5c4869"), "pressed": Color("c9a45c"),
			"disabled": Color("2f2836"), "focus": Color(0, 0, 0, 0)}[state]
		sb.border_color = Color("1a1420")
		sb.set_border_width_all(0 if state == "focus" else 1)
		sb.set_content_margin_all(5)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_disabled_color", "Button", Color("7d7385"))
	var list_bg := StyleBoxFlat.new()
	list_bg.bg_color = Color("171119")
	list_bg.set_content_margin_all(4)
	t.set_stylebox("panel", "ItemList", list_bg)
	t.set_stylebox("normal", "RichTextLabel", list_bg)
	return t


func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top_bar)
	var row := HBoxContainer.new()
	top_bar.add_child(row)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	kit_button = Button.new()
	kit_button.pressed.connect(func(): open_panel(0))
	row.add_child(kit_button)
	var codex := Button.new()
	codex.text = "Codex"
	codex.pressed.connect(func(): open_panel(1))
	row.add_child(codex)
	var craft := Button.new()
	craft.text = "Craft"
	craft.pressed.connect(func(): open_panel(2))
	row.add_child(craft)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var y := size.y - BUTTON_SIZE - MARGIN
	touch_buttons[0].position = Vector2(MARGIN, y)
	touch_buttons[1].position = Vector2(MARGIN * 2 + BUTTON_SIZE, y)
	touch_buttons[2].position = Vector2(size.x - BUTTON_SIZE - MARGIN, y)


func _refresh_buttons() -> void:
	kit_button.text = "Field Kit (%d)" % GameState.samples.size()


func set_status(text: String) -> void:
	status_label.text = text


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	_toast_left = 4.0


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		toast_label.modulate.a = clampf(_toast_left, 0.0, 1.0)


func open_panel(index: int) -> void:
	for p in panels:
		p.visible = false
	panels[index].call("open")


func panel_open() -> bool:
	for p in panels:
		if p.visible:
			return true
	return false


## True when a screen position is on the status bar or a touch button, so it should not start mining.
func is_over_controls(pos: Vector2) -> bool:
	if top_bar.get_global_rect().has_point(pos):
		return true
	for b in touch_buttons:
		if Rect2(b.position, Vector2(BUTTON_SIZE, BUTTON_SIZE)).grow(6).has_point(pos):
			return true
	return false


func _arrow_texture(direction: String, pressed: bool) -> ImageTexture:
	var img := Image.create(BUTTON_SIZE, BUTTON_SIZE, false, Image.FORMAT_RGBA8)
	var fill := Color(1, 1, 1, 0.35 if pressed else 0.15)
	var edge := Color(1, 1, 1, 0.6)
	var arrow := Color(1, 1, 1, 0.85)
	var c := BUTTON_SIZE / 2
	for y in BUTTON_SIZE:
		for x in BUTTON_SIZE:
			var col := fill
			if x < 2 or y < 2 or x >= BUTTON_SIZE - 2 or y >= BUTTON_SIZE - 2:
				col = edge
			# Triangle pointing the given way, 8-bit style.
			var u := x - c
			var v := y - c
			var along: int = {"left": -u, "right": u, "up": -v}[direction]
			var across := absi(v if direction != "up" else u)
			if along > -8 and along < 10 and across < (10 - along) / 2 + 2 and along < 10:
				col = arrow
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
