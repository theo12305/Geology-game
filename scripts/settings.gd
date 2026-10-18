extends "res://scripts/menu_panel.gd"
## Settings and accessibility: text size, high contrast, sound, vibration and screen shake. Also a short
## how-to-play and your stats.

var list: VBoxContainer


func _ready() -> void:
	title_label.text = "Settings"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)


func open() -> void:
	visible = true
	clear(list)
	var sizes := _row("Text size")
	for i in UiTheme.TEXT_SIZE_NAMES.size():
		var b := big_button(UiTheme.TEXT_SIZE_NAMES[i])
		b.toggle_mode = true
		b.button_pressed = int(GameState.settings["text_size"]) == i
		b.custom_minimum_size.x = 70
		b.pressed.connect(func(): _change("text_size", i))
		sizes.add_child(b)
	_toggle("High contrast", "Black backgrounds, white borders and brighter colors.", "contrast")
	_toggle("Sound", "Chiptune sound effects.", "sound")
	_toggle("Vibration", "A short buzz when you find something or get an answer.", "vibrate")
	_toggle("Screen shake", "A little shake when blocks break.", "shake")
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = ("How to play\n"
		+ "Tap open ground to walk; tap higher up to jump or climb walls.\n"
		+ "Tap a block once to dig it. Glittering veins give mineral samples; rock sometimes gives rock samples.\n"
		+ "Open the Bag, run tests, then name each sample for XP and coins. A streak of right answers pays more.\n"
		+ "Craft harder picks in the Workshop to dig through the hard bands into deeper, rarer rock.\n"
		+ "Stuck in a hole? Rope up takes you back to the surface.")
	list.add_child(help)
	var stats := Label.new()
	stats.theme_type_variation = "Muted"
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.text = "Your stats: %d blocks dug, deepest %d m, best streak %d, %d minerals and %d rocks found, daily streak %d." % [
		GameState.blocks_dug, GameState.max_depth, GameState.best_streak, GameState.identified_count("mineral"),
		GameState.identified_count("rock"), int(GameState.daily["streak"])]
	list.add_child(stats)


func _row(text: String, sub := "") -> HBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	list.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var l := Label.new()
	l.text = text
	v.add_child(l)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.theme_type_variation = "Muted"
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	return row


func _toggle(text: String, sub: String, key: String) -> void:
	var row := _row(text, sub)
	var b := big_button("On" if GameState.settings[key] else "Off")
	b.toggle_mode = true
	b.button_pressed = GameState.settings[key]
	b.custom_minimum_size.x = 80
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): _change(key, not GameState.settings[key]))
	row.add_child(b)


func _change(key: String, value: Variant) -> void:
	GameState.set_setting(key, value)
	Sfx.play("tap")
	if key == "vibrate" and value:
		GameState.buzz(50)
	open()
