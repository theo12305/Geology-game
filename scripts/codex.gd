extends "res://scripts/menu_panel.gd"
## Codex: photo, explanation, reference data and study links for every mineral, rock and fossil you have
## found, with bronze, silver and gold mastery stars. Unknown entries stay hidden until you find them.
## The photo quiz shows real photos of things you have found and asks you to name them.

const MASTERY_COLORS := [Color(0, 0, 0, 0), Color("cd8a4a"), Color("d6dbe2"), Color("f2c230")]
const KIND_NAMES := {"mineral": "minerals", "rock": "rocks", "fossil": "fossils"}

var kind := "mineral"
var list: ItemList
var details: RichTextLabel
var tab_buttons := {}
var ids: Array = []
var progress: ProgressBar
var quiz_button: Button
var browse: HBoxContainer
# Photo quiz
var quiz: HBoxContainer
var quiz_photo: TextureRect
var quiz_prompt: Label
var quiz_choices: GridContainer
var quiz_feedback: RichTextLabel
var quiz_next: Button
var quiz_id := ""
var quiz_streak := 0


func _ready() -> void:
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for k in ["mineral", "rock", "fossil"]:
		var b := big_button(KIND_NAMES[k].capitalize())
		b.toggle_mode = true
		b.custom_minimum_size.x = 96
		b.pressed.connect(func():
			kind = k
			Sfx.play("tap")
			open())
		tabs.add_child(b)
		tab_buttons[k] = b
	progress = ProgressBar.new()
	progress.theme_type_variation = "GoodBar"
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(60, 8)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(progress)
	quiz_button = big_button("Photo quiz", "star", true)
	quiz_button.pressed.connect(_start_quiz)
	tabs.add_child(quiz_button)
	browse = HBoxContainer.new()
	browse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(browse)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(190, 0)
	list.item_selected.connect(_on_selected)
	browse.add_child(list)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.meta_clicked.connect(GameData.open_link)
	browse.add_child(details)
	_build_quiz()


func _build_quiz() -> void:
	quiz = HBoxContainer.new()
	quiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quiz.add_theme_constant_override("separation", 10)
	quiz.visible = false
	body.add_child(quiz)
	quiz_photo = TextureRect.new()
	quiz_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quiz_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quiz_photo.custom_minimum_size = Vector2(240, 0)
	quiz_photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiz.add_child(quiz_photo)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiz.add_child(right)
	quiz_prompt = Label.new()
	quiz_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(quiz_prompt)
	quiz_choices = GridContainer.new()
	quiz_choices.columns = 2
	quiz_choices.add_theme_constant_override("h_separation", 6)
	quiz_choices.add_theme_constant_override("v_separation", 6)
	right.add_child(quiz_choices)
	quiz_feedback = RichTextLabel.new()
	quiz_feedback.bbcode_enabled = true
	quiz_feedback.fit_content = false
	quiz_feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(quiz_feedback)
	var actions := HBoxContainer.new()
	right.add_child(actions)
	var done := big_button("Back to Codex", "codex")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(func(): open())
	actions.add_child(done)
	quiz_next = big_button("Next photo", "star", true)
	quiz_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiz_next.pressed.connect(_next_question)
	actions.add_child(quiz_next)


func _source() -> Dictionary:
	if kind == "fossil":
		return GameData.fossils
	return GameData.minerals if kind == "mineral" else GameData.rocks


func _found(id: String) -> bool:
	return GameState.fossils_found.has(id) if kind == "fossil" else GameState.correct_ids.has(id)


func _found_count() -> int:
	return GameState.fossils_found.size() if kind == "fossil" else GameState.identified_count(kind)


## Found entries of this kind that have a photo, for the quiz.
func _quiz_pool() -> Array:
	return ids.filter(func(id): return _found(id) and GameData.photo_bbcode(id) != "")


func open() -> void:
	visible = true
	browse.visible = true
	quiz.visible = false
	back_button.visible = false
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == kind
	var source := _source()
	ids = source.keys()
	ids.sort_custom(func(a, b):
		var ta := int(source[a]["tier"])
		var tb := int(source[b]["tier"])
		return a < b if ta == tb else ta < tb)
	title_label.text = "Codex: %d of %d %s found" % [_found_count(), ids.size(), KIND_NAMES[kind]]
	progress.max_value = ids.size()
	progress.value = _found_count()
	quiz_button.visible = kind != "fossil" and _quiz_pool().size() >= 4
	list.clear()
	for id in ids:
		if _found(id):
			list.add_item(source[id]["name"])
			var m := GameState.mastery(id) if kind != "fossil" else 0
			if m > 0:
				list.set_item_icon(list.item_count - 1, UiTheme.icon("star"))
				list.set_item_icon_modulate(list.item_count - 1, MASTERY_COLORS[m])
		else:
			list.add_item("???  (depth tier %d)" % int(source[id]["tier"]))
	details.text = "Tap an entry. Name samples in your Bag (or dig up fossils) to unlock their photo and explanation."
	for i in ids.size():
		if _found(ids[i]):
			list.select(i)
			_on_selected(i)
			break


## Opens the Codex on one entry.
func show_entry(entry_kind: String, id: String) -> void:
	kind = entry_kind
	open()
	var i := ids.find(id)
	if i >= 0:
		list.select(i)
		list.ensure_current_is_visible()
		_on_selected(i)


func _on_selected(index: int) -> void:
	var id: String = ids[index]
	if not _found(id):
		details.text = "Not found yet. Dig deeper, and name more samples, to unlock it."
		return
	var e := GameData.entry(kind, id)
	var lines := []
	match kind:
		"mineral":
			lines = [
				"[b]%s[/b]  %s" % [e["name"], e["formula"]],
				GameData.lesson_bbcode(kind, id, 220),
				"",
				"Class: %s" % e["mineral_class"],
				"Crystal system: %s" % e["crystal_system"],
				"Hardness: %s   Density: %s g/cm3" % [GameData.hardness_text(e), e["specific_gravity"]],
				"Streak: %s   Luster: %s" % [e["streak"], e["luster"]],
				"Cleavage: %s" % e["cleavage"],
				"Colors: %s" % ", ".join(e["colors"]),
				"Key test: %s" % e["diagnostic"],
				"Found in: %s" % e["occurrence"],
			]
		"rock":
			var names := []
			for m in e["minerals"]:
				names.append(GameData.mineral(m)["name"])
			lines = [
				"[b]%s[/b]  (%s, %s)" % [e["name"], e["family"], e["subtype"]],
				GameData.lesson_bbcode(kind, id, 220),
				"",
				"Texture: %s" % e["texture"],
				"Grain size: %s" % e["grain_size"],
				"Minerals: %s" % (", ".join(names) if names else "none (glass)"),
				"Key test: %s" % e["diagnostic"],
				"Forms in: %s" % e["setting"],
			]
			if e.get("protolith"):
				lines.append("Formed from: %s" % e["protolith"])
		"fossil":
			lines = [
				"[b]%s[/b]  (%s)" % [e["name"], e["group"]],
				"Lived: %s" % e["age"],
				GameData.lesson_bbcode(kind, id, 220),
				"",
				"Did you know? %s" % e["fact"],
				"Found in: %s" % ", ".join(e["hosts"]),
				"Found %d times." % GameState.fossils_found[id],
			]
	if kind != "fossil":
		var n: int = GameState.correct_ids[id]
		var m := GameState.mastery(id)
		var next := ""
		if m < GameState.MASTERY.size():
			next = ", %s at %d" % [GameState.MASTERY_NAMES[m + 1], GameState.MASTERY[m]]
		lines.append("Named correctly %d times. Mastery: %s%s." % [n, GameState.MASTERY_NAMES[m] if m > 0 else "none yet",
			next])
	lines.append("")
	lines.append(GameData.entry_links_bbcode(kind, id))
	details.text = "\n".join(lines)
	details.scroll_to_line(0)


# --- Photo quiz: name real photos of minerals or rocks you have already found. ---

func _start_quiz() -> void:
	Sfx.play("tap")
	quiz_streak = 0
	browse.visible = false
	quiz.visible = true
	_next_question()


func _next_question() -> void:
	var pool := _quiz_pool()
	pool.shuffle()
	if pool[0] == quiz_id and pool.size() > 1:
		pool.reverse()
	quiz_id = pool[0]
	var choices: Array = pool.slice(0, 4)
	choices.shuffle()
	quiz_photo.texture = load(GameData.credits[quiz_id]["image"])
	title_label.text = "Photo quiz%s" % ("   streak x%d" % quiz_streak if quiz_streak >= 2 else "")
	quiz_prompt.text = "Which %s is this? Look at color, luster, crystal shape and texture." % kind
	clear(quiz_choices)
	for id in choices:
		var b := big_button(GameData.entry(kind, id)["name"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _quiz_answer(id))
		quiz_choices.add_child(b)
	quiz_feedback.text = ""
	quiz_next.visible = false


func _quiz_answer(guess: String) -> void:
	var correct := guess == quiz_id
	var e := GameData.entry(kind, quiz_id)
	for b in quiz_choices.get_children():
		b.disabled = true
		if b.text == e["name"]:
			b.icon = UiTheme.icon("check")
		elif b.text == GameData.entry(kind, guess)["name"]:
			b.icon = UiTheme.icon("cross")
	var c := UiTheme.colors()
	if correct:
		quiz_streak += 1
		Sfx.play("correct")
		GameState.photo_quiz_answer(true)
		quiz_feedback.text = "[color=#%s][b]Right![/b][/color] +%d XP. Key clue: %s." % [c["good"].to_html(false),
			GameState.XP_PHOTO_QUIZ, e["diagnostic"].trim_suffix(".")]
	else:
		quiz_streak = 0
		Sfx.play("wrong")
		quiz_feedback.text = "[color=#%s][b]Not quite.[/b][/color] It is %s. Key clue: %s." % [c["bad"].to_html(false),
			e["name"], e["diagnostic"].trim_suffix(".")]
	quiz_feedback.text += "\n[color=#%s][font_size=11]%s[/font_size][/color]" % [c["muted"].to_html(false),
		GameData.photo_credit(quiz_id)]
	quiz_next.visible = true
