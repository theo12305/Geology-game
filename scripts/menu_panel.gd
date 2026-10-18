extends PanelContainer
## Full-screen menu with a title, an optional Back button and a big Close button. Subclasses fill `body`
## and override open().

const UiTheme := preload("res://scripts/ui_theme.gd")

var title_label: Label
var back_button: Button
var header: HBoxContainer
var body: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		set_offset(side, 6)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		set_offset(side, -6)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)
	header = HBoxContainer.new()
	outer.add_child(header)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.icon = UiTheme.icon("back")
	back_button.expand_icon = true
	back_button.custom_minimum_size = Vector2(80, UiTheme.TAP)
	back_button.visible = false
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(go_back)
	header.add_child(back_button)
	title_label = Label.new()
	title_label.theme_type_variation = "Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title_label)
	var close := Button.new()
	close.text = "Close"
	close.icon = UiTheme.icon("close")
	close.expand_icon = true
	close.custom_minimum_size = Vector2(90, UiTheme.TAP)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	header.add_child(close)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)


func open() -> void:
	visible = true


## Back button: subclasses with more than one page override this.
func go_back() -> void:
	close_panel()


func close_panel() -> void:
	Sfx.play("tap")
	visible = false
	GameState.save_game()


## A button sized for thumbs.
static func big_button(text: String, icon := "", accent := false) -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = UiTheme.icon(icon)
	b.custom_minimum_size = Vector2(0, UiTheme.TAP)
	b.expand_icon = true
	b.focus_mode = Control.FOCUS_NONE
	if accent:
		b.theme_type_variation = "Accent"
	return b


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
