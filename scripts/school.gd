extends "res://scripts/menu_panel.gd"
## Field School: short university-level lessons with a picture, links to open textbooks and Wikipedia,
## and a three-question quiz. Lessons unlock as you level up, discover zones and find fossils. Passing a
## quiz (all answers right) pays a big reward the first time.

var page := "list"
var lesson_id := ""
var question := 0
var right := 0

var list_scroll: ScrollContainer
var list_box: VBoxContainer
var lesson_page: VBoxContainer
var lesson_text: RichTextLabel
var lesson_pic: TextureRect
var lesson_credit: Label
var quiz_page: VBoxContainer
var quiz_question: Label
var quiz_grid: GridContainer
var quiz_feedback: RichTextLabel
var quiz_next: Button


func _ready() -> void:
	title_label.text = "Field School"
	list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(list_box)

	lesson_page = VBoxContainer.new()
	lesson_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lesson_page)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	lesson_page.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(210, 0)
	row.add_child(left)
	lesson_pic = TextureRect.new()
	lesson_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lesson_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lesson_pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(lesson_pic)
	lesson_credit = Label.new()
	lesson_credit.theme_type_variation = "Muted"
	lesson_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_credit.add_theme_font_size_override("font_size", 10)
	left.add_child(lesson_credit)
	lesson_text = RichTextLabel.new()
	lesson_text.bbcode_enabled = true
	lesson_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lesson_text.meta_clicked.connect(GameData.open_link)
	row.add_child(lesson_text)
	var take := big_button("Take the quiz", "check", true)
	take.pressed.connect(_start_quiz)
	lesson_page.add_child(take)

	quiz_page = VBoxContainer.new()
	quiz_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(quiz_page)
	quiz_question = Label.new()
	quiz_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_page.add_child(quiz_question)
	quiz_grid = GridContainer.new()
	quiz_grid.columns = 2
	quiz_grid.add_theme_constant_override("h_separation", 6)
	quiz_grid.add_theme_constant_override("v_separation", 6)
	quiz_page.add_child(quiz_grid)
	quiz_feedback = RichTextLabel.new()
	quiz_feedback.bbcode_enabled = true
	quiz_feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quiz_page.add_child(quiz_feedback)
	quiz_next = big_button("Next question", "", true)
	quiz_next.pressed.connect(_next)
	quiz_page.add_child(quiz_next)


func open() -> void:
	visible = true
	_show("list")


func go_back() -> void:
	_show("list")


func _show(p: String) -> void:
	page = p
	list_scroll.visible = p == "list"
	lesson_page.visible = p == "lesson"
	quiz_page.visible = p == "quiz"
	back_button.visible = p != "list"
	if p == "list":
		title_label.text = "Field School: %d of %d quizzes passed" % [GameState.lessons_passed.size(), GameData.lessons.size()]
		_render_list()


func _render_list() -> void:
	clear(list_box)
	var intro := Label.new()
	intro.theme_type_variation = "Muted"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Short lessons at university level. Read one, then pass its quiz (3 out of 3) for +%d XP and coins. New lessons unlock as you level up, find fossils and discover deeper zones." % GameState.XP_LESSON_PASS
	list_box.add_child(intro)
	for l in GameData.lessons:
		var unlocked := GameState.lesson_unlocked(l)
		var passed := GameState.lessons_passed.has(l["id"])
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		list_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(56, 40)
		var key: String = "lesson_" + l["id"]
		if unlocked and GameData.credits.has(key) and ResourceLoader.exists(GameData.credits[key]["image"]):
			pic.texture = load(GameData.credits[key]["image"])
		else:
			pic.texture = UiTheme.icon("check" if passed else "cap")
		row.add_child(pic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var t := Label.new()
		t.text = l["title"]
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		var sub := Label.new()
		sub.theme_type_variation = "Muted"
		if not unlocked:
			sub.text = "Locked: %s." % GameState.lesson_lock_text(l)
		elif passed:
			sub.text = "Quiz passed."
		elif GameState.lessons_read.has(l["id"]):
			sub.text = "Read. Quiz not passed yet."
		else:
			sub.text = "New!"
		v.add_child(sub)
		var b := big_button("Open" if unlocked else "Locked", "" if unlocked else "close", unlocked and not passed)
		b.custom_minimum_size.x = 96
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not unlocked
		var id: String = l["id"]
		b.pressed.connect(func(): open_lesson(id))
		row.add_child(b)


func open_lesson(id: String) -> void:
	lesson_id = id
	var l := GameData.lesson(id)
	Sfx.play("tap")
	GameState.read_lesson(id)
	title_label.text = l["title"]
	var key: String = "lesson_" + id
	var has_pic: bool = GameData.credits.has(key) and ResourceLoader.exists(GameData.credits[key]["image"])
	lesson_pic.get_parent().visible = has_pic
	if has_pic:
		lesson_pic.texture = load(GameData.credits[key]["image"])
		lesson_credit.text = GameData.photo_credit(key)
	var parts := []
	parts.append(l["text"])
	parts.append("")
	parts.append(GameData.links_bbcode(l["wiki"], l["books"]))
	lesson_text.text = "\n".join(parts)
	lesson_text.scroll_to_line(0)
	_show("lesson")


func _start_quiz() -> void:
	question = 0
	right = 0
	Sfx.play("tap")
	_show("quiz")
	_render_question()


func _render_question() -> void:
	var q: Dictionary = GameData.lesson(lesson_id)["quiz"][question]
	title_label.text = "Quiz: question %d of 3" % (question + 1)
	quiz_question.text = q["q"]
	clear(quiz_grid)
	for i in q["options"].size():
		var b := big_button(q["options"][i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): _answer(i))
		quiz_grid.add_child(b)
	quiz_feedback.text = ""
	quiz_next.visible = false


func _answer(choice: int) -> void:
	var quiz: Array = GameData.lesson(lesson_id)["quiz"]
	var q: Dictionary = quiz[question]
	var answer := int(q["answer"])
	var buttons := quiz_grid.get_children()
	for i in buttons.size():
		buttons[i].disabled = true
		if i == answer:
			buttons[i].icon = UiTheme.icon("check")
		elif i == choice:
			buttons[i].icon = UiTheme.icon("cross")
	var c := UiTheme.colors()
	if choice == answer:
		right += 1
		Sfx.play("correct")
		quiz_feedback.text = "[color=#%s][b]Right![/b][/color] %s" % [c["good"].to_html(false), q["why"]]
	else:
		Sfx.play("wrong")
		quiz_feedback.text = "[color=#%s][b]Not quite.[/b][/color] The answer is: %s. %s" % [c["bad"].to_html(false),
			q["options"][answer], q["why"]]
	var last := question == quiz.size() - 1
	quiz_next.text = "See result" if last else "Next question"
	quiz_next.visible = true


func _next() -> void:
	var quiz: Array = GameData.lesson(lesson_id)["quiz"]
	if question < quiz.size() - 1:
		question += 1
		_render_question()
		return
	var first_pass := not GameState.lessons_passed.has(lesson_id)
	var passed := GameState.finish_quiz(lesson_id, right, quiz.size())
	clear(quiz_grid)
	quiz_next.visible = false
	title_label.text = "Quiz result"
	var c := UiTheme.colors()
	if passed:
		quiz_question.text = "%d of %d right. Passed!" % [right, quiz.size()]
		quiz_feedback.text = "[color=#%s][b]%s[/b][/color]" % [c["good"].to_html(false),
			("+%d XP and +25 coins for passing." % GameState.XP_LESSON_PASS) if first_pass else "You had already passed this one. Well remembered!"]
	else:
		quiz_question.text = "%d of %d right. You need all 3 to pass." % [right, quiz.size()]
		quiz_feedback.text = "Read the lesson again and have another go; the explanations above each answer are the key points."
	var retry := big_button("Read again" if not passed else "Back to lessons", "codex")
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func():
		if passed:
			_show("list")
		else:
			open_lesson(lesson_id))
	quiz_grid.add_child(retry)
