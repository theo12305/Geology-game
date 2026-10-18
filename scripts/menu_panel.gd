extends PanelContainer
## Full-screen menu with a title and a Close button. Subclasses fill `body` and override open().

var title_label: Label
var body: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		set_offset(side, 10)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		set_offset(side, -10)
	var outer := VBoxContainer.new()
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color("f2c230"))
	header.add_child(title_label)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_panel)
	header.add_child(close)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)


func open() -> void:
	visible = true


func close_panel() -> void:
	visible = false
	GameState.save_game()
