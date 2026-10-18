extends "res://scripts/menu_panel.gd"
## Workshop: craft tools from identified minerals, and buy upgrades with coins.

var list: VBoxContainer
var coin_label: Label


func _ready() -> void:
	title_label.text = "Workshop"
	var coins := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.texture = UiTheme.icon("coin")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(22, 22)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.add_child(ic)
	coin_label = Label.new()
	coin_label.theme_type_variation = "Title"
	coins.add_child(coin_label)
	header.add_child(coins)
	header.move_child(coins, 2)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)


func open() -> void:
	visible = true
	clear(list)
	coin_label.text = "%d  " % GameState.coins
	_section("Tools: made from minerals you have named correctly")
	for r in GameState.RECIPES:
		var lines := []
		for need in r["needs"]:
			lines.append("%d / %d %s" % [mini(GameState.have_for(need), need["count"]), need["count"], need["label"]])
		if r["requires"] != "" and not GameState.has_built(r["requires"]):
			lines.append("Needs the %s first." % GameState.recipe(r["requires"])["name"])
		var built := GameState.has_built(r["id"])
		var b := big_button("Built" if built else "Craft", "check" if built else "anvil", GameState.can_craft(r))
		b.disabled = not GameState.can_craft(r)
		b.pressed.connect(func():
			if GameState.craft(r["id"]):
				GameState.buzz(60)
				GameState.toast.emit("Crafted %s." % r["name"])
			open())
		_card("pick" if r["id"].ends_with("pick") else "anvil", r["name"], "\n".join(lines), r["info"], b,
			_need_fraction(r) if not built else 1.0)
	_section("Upgrades: bought with coins from naming samples, goals and gold flakes")
	for u in GameState.UPGRADES:
		var lvl := GameState.upgrade_level(u["id"])
		var maxed := lvl >= int(u["max"])
		var b := big_button("Max" if maxed else "%d" % GameState.upgrade_cost(u["id"]), "" if maxed else "coin",
			GameState.can_buy(u["id"]))
		b.disabled = not GameState.can_buy(u["id"])
		b.pressed.connect(func():
			if GameState.buy_upgrade(u["id"]):
				GameState.buzz(60)
				GameState.toast.emit("%s is now level %d." % [u["name"], GameState.upgrade_level(u["id"])])
			open())
		_card(u["icon"], "%s  (level %d of %d)" % [u["name"], lvl, u["max"]], "", u["info"], b,
			float(lvl) / int(u["max"]))


func _need_fraction(r: Dictionary) -> float:
	var have := 0
	var total := 0
	for need in r["needs"]:
		have += mini(GameState.have_for(need), need["count"])
		total += need["count"]
	return float(have) / total


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Muted"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(l)


func _card(icon: String, name: String, needs: String, info: String, button: Button, progress: float) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UiTheme.icon(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(32, 32)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title := Label.new()
	title.text = name
	v.add_child(title)
	if needs != "":
		var n := Label.new()
		n.text = needs
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	if progress >= 0.0:
		var bar := ProgressBar.new()
		bar.theme_type_variation = "GoodBar"
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = progress
		bar.custom_minimum_size = Vector2(0, 6)
		v.add_child(bar)
	var i := Label.new()
	i.text = info
	i.theme_type_variation = "Muted"
	i.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(i)
	button.custom_minimum_size = Vector2(100, UiTheme.TAP)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
