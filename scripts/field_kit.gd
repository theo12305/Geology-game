extends "res://scripts/menu_panel.gd"
## Field kit: run physical tests on unknown samples, write the results in a notebook, then name the mineral.

var list: ItemList
var notes: RichTextLabel
var tests_grid: GridContainer
var choices_box: HBoxContainer
var identify_button: Button
var quartz_button: Button
var selected_uid := -1
var _result := ""


func _ready() -> void:
	title_label.text = "Field Kit"
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(150, 0)
	list.item_selected.connect(_on_selected)
	row.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	tests_grid = GridContainer.new()
	tests_grid.columns = 5
	right.add_child(tests_grid)
	_add_test("Streak", func(m): return GameData.streak_test(m))
	for tool in GameState.SCRATCH_TOOLS:
		var b := _add_test("%s %s" % [tool[3], tool[1]], func(m): return GameData.scratch_test(m, tool[0], tool[1]))
		if tool[2] != "":
			quartz_button = b
	_add_test("HCl", func(m): return GameData.acid_test(m))
	_add_test("Magnet", func(m): return GameData.magnet_test(m))
	_add_test("Lens", func(m): return GameData.lens_test(m))
	_add_test("Heft", func(m): return GameData.heft_test(m))
	_add_test("Taste", func(m): return GameData.taste_test(m))
	notes = RichTextLabel.new()
	notes.bbcode_enabled = true
	notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(notes)
	identify_button = Button.new()
	identify_button.text = "Identify this sample..."
	identify_button.pressed.connect(_show_choices)
	right.add_child(identify_button)
	choices_box = HBoxContainer.new()
	right.add_child(choices_box)


func open() -> void:
	visible = true
	_result = ""
	refresh()


func refresh() -> void:
	list.clear()
	var keep := -1
	for i in GameState.samples.size():
		var s: Dictionary = GameState.samples[i]
		list.add_item("Unknown #%d, %s, %d m" % [s["uid"], s["color"], s["depth"]], _swatch(GameData.color_of(s["color"])))
		if int(s["uid"]) == selected_uid:
			keep = i
	if keep < 0 and list.item_count > 0:
		keep = 0
	if keep >= 0:
		list.select(keep)
		selected_uid = int(GameState.samples[keep]["uid"])
	else:
		selected_uid = -1
	var quartz_known: bool = GameState.correct_ids.has("quartz")
	quartz_button.disabled = not quartz_known
	quartz_button.tooltip_text = "" if quartz_known else "Identify quartz once to use it as a scratch tool."
	_render()


func _on_selected(index: int) -> void:
	selected_uid = int(GameState.samples[index]["uid"])
	_result = ""
	_render()


func _add_test(label: String, test: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(func(): _run_test(test))
	tests_grid.add_child(b)
	return b


func _run_test(test: Callable) -> void:
	var s := GameState.sample_by_uid(selected_uid)
	if s.is_empty():
		return
	var line: String = test.call(GameData.mineral(s["mineral"]))
	if not s["notes"].has(line):
		s["notes"].append(line)
	_result = ""
	_render()


func _render() -> void:
	for c in choices_box.get_children():
		c.queue_free()
	var s := GameState.sample_by_uid(selected_uid)
	var has_sample := not s.is_empty()
	for b in tests_grid.get_children():
		b.visible = has_sample
	identify_button.disabled = not has_sample
	var text := _result
	if has_sample:
		text += "[b]Sample #%d[/b]: %s, found at %d m.\n" % [s["uid"], s["color"], s["depth"]]
		if s["notes"].is_empty():
			text += "Run some tests. Each result is written in your notebook.\n"
		for n in s["notes"]:
			text += "- %s\n" % n
	elif _result == "":
		text = "No samples. Hold on a glittering vein to chip one off."
	notes.text = text


func _show_choices() -> void:
	var s := GameState.sample_by_uid(selected_uid)
	if s.is_empty():
		return
	for c in choices_box.get_children():
		c.queue_free()
	for id in GameState.choices_for(s):
		var b := Button.new()
		b.text = GameData.mineral(id)["name"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _answer(id))
		choices_box.add_child(b)


func _answer(guess: String) -> void:
	var s := GameState.sample_by_uid(selected_uid)
	var m := GameData.mineral(s["mineral"])
	var clue: String = m["diagnostic"].trim_suffix(".") + "."
	if GameState.identify(selected_uid, guess):
		_result = "[color=#7fd67f][b]Correct: %s[/b][/color], %s. %s Added to your stock and Codex.\n\n" % [
			m["name"], m["formula"], clue]
	else:
		_result = "[color=#e07a6a][b]Not %s.[/b][/color] It was %s, %s. Key clue: %s It will turn up more often until you get it right.\n\n" % [
			GameData.mineral(guess)["name"], m["name"], m["formula"], clue]
	selected_uid = -1
	refresh()


func _swatch(color: Color) -> ImageTexture:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
