extends "res://scripts/menu_panel.gd"
## Codex: photo, explanation and reference data for every mineral and rock you have identified.
## Unknown entries stay hidden until you name one correctly.

var kind := "mineral"
var list: ItemList
var details: RichTextLabel
var tab_buttons := {}
var ids: Array = []


func _ready() -> void:
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for k in ["mineral", "rock"]:
		var b := Button.new()
		b.text = "Minerals" if k == "mineral" else "Rocks"
		b.toggle_mode = true
		b.pressed.connect(func():
			kind = k
			open())
		tabs.add_child(b)
		tab_buttons[k] = b
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(150, 0)
	list.item_selected.connect(_on_selected)
	row.add_child(list)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)


func open() -> void:
	visible = true
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == kind
	var source: Dictionary = GameData.minerals if kind == "mineral" else GameData.rocks
	ids = source.keys()
	ids.sort_custom(func(a, b):
		var ta := int(source[a]["tier"])
		var tb := int(source[b]["tier"])
		return a < b if ta == tb else ta < tb)
	title_label.text = "Codex: %d of %d %s identified" % [GameState.identified_count(kind), ids.size(),
		"minerals" if kind == "mineral" else "rocks"]
	list.clear()
	for id in ids:
		var known: bool = GameState.correct_ids.has(id)
		list.add_item(source[id]["name"] if known else "??? (tier %d)" % int(source[id]["tier"]))
	details.text = "Identify samples in the Field Kit to unlock their photo and explanation."


func _on_selected(index: int) -> void:
	var id: String = ids[index]
	if not GameState.correct_ids.has(id):
		details.text = "Not identified yet."
		return
	var e := GameData.entry(kind, id)
	var lines := []
	if kind == "mineral":
		lines = [
			"[b]%s[/b]  %s" % [e["name"], e["formula"]],
			GameData.lesson_bbcode(kind, id),
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
	else:
		var names := []
		for m in e["minerals"]:
			names.append(GameData.mineral(m)["name"])
		lines = [
			"[b]%s[/b]  (%s, %s)" % [e["name"], e["family"], e["subtype"]],
			GameData.lesson_bbcode(kind, id),
			"",
			"Texture: %s" % e["texture"],
			"Grain size: %s" % e["grain_size"],
			"Minerals: %s" % (", ".join(names) if names else "none (glass)"),
			"Key test: %s" % e["diagnostic"],
			"Forms in: %s" % e["setting"],
		]
		if e.get("protolith"):
			lines.append("Formed from: %s" % e["protolith"])
	lines.append("Identified %d times." % GameState.correct_ids[id])
	details.text = "\n".join(lines)
	details.scroll_to_line(0)
