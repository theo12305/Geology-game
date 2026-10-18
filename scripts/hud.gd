extends CanvasLayer
## Status bar, build and rope buttons, messages and the menu panels.

signal build_toggled(on: bool)
signal rope_pressed

const FieldKit := preload("res://scripts/field_kit.gd")
const Codex := preload("res://scripts/codex.gd")
const Craft := preload("res://scripts/craft.gd")

const MARGIN := 10

var root: Control
var top_bar: PanelContainer
var status_label: Label
var kit_button: Button
var toast_label: Label
var build_button: Button
var rope_button: Button
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
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(440, 0)
	toast_label.position = Vector2(-220, 40)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 4)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	build_button = Button.new()
	build_button.toggle_mode = true
	build_button.text = "Build"
	build_button.custom_minimum_size = Vector2(64, 36)
	build_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	build_button.toggled.connect(func(on: bool):
		build_button.text = "Build: ON" if on else "Build"
		build_toggled.emit(on))
	root.add_child(build_button)
	rope_button = Button.new()
	rope_button.text = "Rope up"
	rope_button.custom_minimum_size = Vector2(64, 36)
	rope_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	rope_button.pressed.connect(func(): rope_pressed.emit())
	root.add_child(rope_button)
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
	# Bottom buttons follow their anchors; only the message needs re-centering.
	toast_label.position.x = get_viewport().get_visible_rect().size.x / 2.0 - 220


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


## True when a screen position is on a button, so the tap is not also a walk or mine.
func is_over_controls(pos: Vector2) -> bool:
	for c in [top_bar, build_button, rope_button]:
		if c.get_global_rect().grow(4).has_point(pos):
			return true
	return false

