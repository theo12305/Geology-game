extends "res://scripts/menu_panel.gd"
## The Bag (field kit). Three pages: a grid of sample cards; a sample page where you run tests, read your
## notebook and name the sample; and a result page with the reward, the key clue and the full lesson.

const HINT_COST := 10

var page := "bag"
var selected_uid := -1
var choosing := false

# Bag page
var bag_page: VBoxContainer
var bag_info: Label
var bag_grid: GridContainer
var empty_box: VBoxContainer
# Sample page
var sample_page: VBoxContainer
var sample_swatch: TextureRect
var sample_desc: Label
var tests_scroll: ScrollContainer
var tests_grid: GridContainer
var choice_box: VBoxContainer
var choice_grid: GridContainer
var hint_button: Button
var notes: RichTextLabel
var name_button: Button
var tip_label: Label
# Result page
var result_page: VBoxContainer
var result_banner: PanelContainer
var result_icon: TextureRect
var result_title: Label
var result_reward: Label
var result_lesson: RichTextLabel
var next_button: Button


func _ready() -> void:
	_build_bag_page()
	_build_sample_page()
	_build_result_page()


func _build_bag_page() -> void:
	bag_page = VBoxContainer.new()
	bag_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(bag_page)
	bag_info = Label.new()
	bag_info.theme_type_variation = "Muted"
	bag_page.add_child(bag_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_page.add_child(scroll)
	bag_grid = GridContainer.new()
	bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(bag_grid)
	empty_box = VBoxContainer.new()
	empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_page.add_child(empty_box)
	var hand := TextureRect.new()
	hand.texture = UiTheme.icon("hand")
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.custom_minimum_size = Vector2(48, 48)
	empty_box.add_child(hand)
	var empty := Label.new()
	empty.text = "Your bag is empty.\nTap a glittering vein (sparkly block) to collect a mineral.\nDigging ordinary rock sometimes gives a rock sample too."
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_box.add_child(empty)


func _build_sample_page() -> void:
	sample_page = VBoxContainer.new()
	sample_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sample_page)
	var desc_row := HBoxContainer.new()
	sample_page.add_child(desc_row)
	sample_swatch = TextureRect.new()
	sample_swatch.custom_minimum_size = Vector2(22, 22)
	sample_swatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desc_row.add_child(sample_swatch)
	sample_desc = Label.new()
	sample_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sample_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_row.add_child(sample_desc)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	sample_page.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	row.add_child(left)
	tests_scroll = ScrollContainer.new()
	tests_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tests_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(tests_scroll)
	tests_grid = GridContainer.new()
	tests_grid.columns = 3
	tests_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tests_grid.add_theme_constant_override("h_separation", 4)
	tests_grid.add_theme_constant_override("v_separation", 4)
	tests_scroll.add_child(tests_grid)
	choice_box = VBoxContainer.new()
	choice_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(choice_box)
	var q := Label.new()
	q.text = "What is it? Check your notebook, then choose."
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_box.add_child(q)
	choice_grid = GridContainer.new()
	choice_grid.columns = 2
	choice_grid.add_theme_constant_override("h_separation", 6)
	choice_grid.add_theme_constant_override("v_separation", 6)
	choice_box.add_child(choice_grid)
	var choice_actions := HBoxContainer.new()
	choice_box.add_child(choice_actions)
	var more := big_button("More tests", "flask")
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.pressed.connect(func():
		choosing = false
		_render_sample())
	choice_actions.add_child(more)
	hint_button = big_button("Hint", "coin")
	hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_button.pressed.connect(_use_hint)
	choice_actions.add_child(hint_button)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var nb := Label.new()
	nb.text = "Notebook"
	nb.theme_type_variation = "Muted"
	right.add_child(nb)
	notes = RichTextLabel.new()
	notes.bbcode_enabled = true
	notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes.scroll_following = true
	right.add_child(notes)
	var bottom := HBoxContainer.new()
	sample_page.add_child(bottom)
	tip_label = Label.new()
	tip_label.theme_type_variation = "Muted"
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(tip_label)
	name_button = big_button("Name it!", "check", true)
	name_button.custom_minimum_size.x = 150
	name_button.pressed.connect(func():
		choosing = true
		Sfx.play("tap")
		_render_sample())
	bottom.add_child(name_button)


func _build_result_page() -> void:
	result_page = VBoxContainer.new()
	result_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(result_page)
	result_banner = PanelContainer.new()
	result_page.add_child(result_banner)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	result_banner.add_child(bh)
	result_icon = TextureRect.new()
	result_icon.custom_minimum_size = Vector2(36, 36)
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bh.add_child(result_icon)
	var bv := VBoxContainer.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bv)
	result_title = Label.new()
	result_title.theme_type_variation = "Title"
	result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(result_title)
	result_reward = Label.new()
	result_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(result_reward)
	result_lesson = RichTextLabel.new()
	result_lesson.bbcode_enabled = true
	result_lesson.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_lesson.meta_clicked.connect(GameData.open_link)
	result_page.add_child(result_lesson)
	var actions := HBoxContainer.new()
	result_page.add_child(actions)
	var to_bag := big_button("Back to bag", "bag")
	to_bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_bag.pressed.connect(func(): _show_page("bag"))
	actions.add_child(to_bag)
	next_button = big_button("Next sample", "flask", true)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(func():
		if not GameState.samples.is_empty():
			_open_sample(int(GameState.samples[0]["uid"])))
	actions.add_child(next_button)


func open() -> void:
	visible = true
	_show_page("bag")


func go_back() -> void:
	_show_page("bag")


func _show_page(p: String) -> void:
	page = p
	bag_page.visible = p == "bag"
	sample_page.visible = p == "sample"
	result_page.visible = p == "result"
	back_button.visible = p == "sample"
	if p == "bag":
		_render_bag()


func refresh() -> void:
	if page == "sample":
		_render_sample()
	else:
		_render_bag()


# --- Bag page ---

func _render_bag() -> void:
	title_label.text = "Bag"
	clear(bag_grid)
	var n := GameState.samples.size()
	bag_info.text = "%d of %d slots used. Tap a sample to study it." % [n, GameState.max_samples()]
	empty_box.visible = n == 0
	bag_info.visible = n > 0
	var width := get_viewport().get_visible_rect().size.x - 40
	bag_grid.columns = maxi(2, int(width / 150))
	for s in GameState.samples:
		bag_grid.add_child(_sample_card(s))


func _sample_card(s: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var uid := int(s["uid"])
	b.pressed.connect(func(): _open_sample(uid))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var sw := TextureRect.new()
	sw.texture = _swatch(s)
	sw.custom_minimum_size = Vector2(28, 28)
	sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sw)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var t := Label.new()
	t.text = ("Rock" if s["kind"] == "rock" else "Mineral") + (" #%d" % uid)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var sub := Label.new()
	sub.theme_type_variation = "Muted"
	sub.text = "%d m%s" % [s["depth"], ("  %d notes" % s["notes"].size()) if s["notes"].size() > 0 else "  new"]
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	return b


# --- Sample page ---

func _open_sample(uid: int) -> void:
	selected_uid = uid
	choosing = false
	Sfx.play("tap")
	_show_page("sample")
	_render_sample()


## The tests for a sample: [button label, callable taking the entry, disabled reason or ""].
func _tests_for(kind: String) -> Array:
	if kind == "rock":
		return [
			["Texture", func(r): return GameData.rock_texture_test(r), ""],
			["Grain size", func(r): return GameData.rock_grain_test(r), ""],
			["Minerals", func(r): return GameData.rock_minerals_test(r), ""],
			["Acid", func(r): return GameData.rock_acid_test(r), ""],
		]
	var list := [["Streak", func(m): return GameData.streak_test(m), ""]]
	for tool in GameState.SCRATCH_TOOLS:
		var locked: bool = tool[2] != "" and not GameState.correct_ids.has(tool[2])
		list.append(["%s %s" % [tool[3], tool[1]], func(m): return GameData.scratch_test(m, tool[0], tool[1]),
			"Name quartz once to use it as a scratch tool." if locked else ""])
	list.append_array([
		["Acid", func(m): return GameData.acid_test(m), ""],
		["Magnet", func(m): return GameData.magnet_test(m), ""],
		["Lens", func(m): return GameData.lens_test(m), ""],
		["Heft", func(m): return GameData.heft_test(m), ""],
		["Taste", func(m): return GameData.taste_test(m), ""],
	])
	return list


func _render_sample() -> void:
	var s := GameState.sample_by_uid(selected_uid)
	if s.is_empty():
		_show_page("bag")
		return
	var kind: String = s["kind"]
	var e := GameData.entry(kind, s["id"])
	title_label.text = "Unknown %s #%d" % [kind, s["uid"]]
	sample_swatch.texture = _swatch(s)
	if kind == "rock":
		sample_desc.text = "Hand specimen from %d m down." % s["depth"]
	else:
		sample_desc.text = "%s crystal from %d m down." % [String(s["color"]).capitalize(), s["depth"]]
	tests_scroll.visible = not choosing
	choice_box.visible = choosing
	name_button.visible = not choosing
	tip_label.visible = not choosing
	clear(tests_grid)
	for test in _tests_for(kind):
		var line: String = test[1].call(e)
		var done: bool = s["notes"].has(line)
		var b := big_button(test[0], "check" if done else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = test[2] != ""
		b.tooltip_text = test[2]
		b.pressed.connect(func(): _run_test(line))
		tests_grid.add_child(b)
	tip_label.text = _tip(s)
	clear(choice_grid)
	if choosing:
		for id in GameState.choices_for(s):
			var c := big_button(GameData.entry(kind, id)["name"])
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.custom_minimum_size.y = 52
			c.pressed.connect(func(): _answer(id))
			choice_grid.add_child(c)
		hint_button.text = "Hint: drop one (%d)" % HINT_COST
		hint_button.disabled = GameState.coins < HINT_COST or GameState.choices_for(s).size() <= 2
	_render_notes(s)


func _render_notes(s: Dictionary) -> void:
	var c := UiTheme.colors()
	if s["notes"].is_empty():
		notes.text = "[color=#%s]Tap a test on the left. Each result is written here.[/color]" % c["muted"].to_html(false)
		return
	var lines := []
	for i in s["notes"].size():
		var n: String = s["notes"][i]
		if i == s["notes"].size() - 1:
			lines.append("[color=#%s]> %s[/color]" % [c["accent"].to_html(false), n])
		else:
			lines.append("- %s" % n)
	notes.text = "\n".join(lines)


func _tip(s: Dictionary) -> String:
	var n: int = s["notes"].size()
	if s["kind"] == "rock":
		return "Tip: texture tells you the rock family; acid finds calcite." if n < 2 else "Ready? Name it for XP and coins."
	if n == 0:
		return "Tip: start with streak and a scratch test."
	if n < 3:
		return "Tip: each test rules out more minerals."
	return "Ready? Name it for XP and coins."


func _run_test(line: String) -> void:
	var s := GameState.sample_by_uid(selected_uid)
	if s.is_empty():
		return
	if not s["notes"].has(line):
		s["notes"].append(line)
		GameState.track("test")
	Sfx.play("tap")
	_render_sample()


func _use_hint() -> void:
	var s := GameState.sample_by_uid(selected_uid)
	var choices: Array = GameState.choices_for(s)
	if GameState.coins < HINT_COST or choices.size() <= 2:
		return
	var wrong := choices.filter(func(id): return id != s["id"])
	choices.erase(wrong[GameState.rng.randi_range(0, wrong.size() - 1)])
	GameState.add_coins(-HINT_COST)
	Sfx.play("coin")
	_render_sample()


func _answer(guess: String) -> void:
	var s := GameState.sample_by_uid(selected_uid)
	var kind: String = s["kind"]
	var id: String = s["id"]
	var e := GameData.entry(kind, id)
	var what: String = ("%s (%s)" % [e["name"], e["formula"]]) if kind == "mineral" else e["name"]
	var correct := GameState.identify(selected_uid, guess)
	var r := GameState.last_reward
	if correct:
		GameState.buzz(40)
		result_banner.theme_type_variation = "GoodBanner"
		result_icon.texture = UiTheme.icon("check")
		result_title.text = "Correct! It is %s." % what
		var parts := ["+%d XP" % r["xp"], "+%d coins" % r["coins"]]
		if r["streak"] >= 2:
			parts.append("Streak x%d" % r["streak"])
		if r["first"]:
			parts.append("New Codex entry!")
		if r.get("mastery", 0) > 0:
			parts.append("%s mastery!" % GameState.MASTERY_NAMES[r["mastery"]].capitalize())
		result_reward.text = "   ".join(parts)
	else:
		GameState.buzz(120)
		result_banner.theme_type_variation = "BadBanner"
		result_icon.texture = UiTheme.icon("cross")
		result_title.text = "Not %s. It was %s." % [GameData.entry(kind, guess)["name"], what]
		result_reward.text = "Streak reset. You will find %s more often until you get it right." % e["name"]
	var clue: String = e["diagnostic"].trim_suffix(".") + "."
	var text := "[b]Key clue:[/b] %s\n\n" % clue
	if not correct:
		text += GameData.comparison_bbcode(kind, id, guess) + "\n\n"
	text += GameData.lesson_bbcode(kind, id, 200) + "\n\n" + GameData.entry_links_bbcode(kind, id)
	result_lesson.text = text
	result_lesson.scroll_to_line(0)
	title_label.text = "Result"
	next_button.visible = not GameState.samples.is_empty()
	selected_uid = -1
	_show_page("result")


func _swatch(s: Dictionary) -> ImageTexture:
	var color: Color = Color(s["color"]) if s["kind"] == "rock" else GameData.color_of(s["color"])
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for i in 8:
		for edge in [Vector2i(i, 0), Vector2i(i, 7), Vector2i(0, i), Vector2i(7, i)]:
			img.set_pixelv(edge, color.darkened(0.5))
	img.set_pixel(2, 2, color.lightened(0.5))
	return ImageTexture.create_from_image(img)
