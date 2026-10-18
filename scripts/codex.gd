extends "res://scripts/menu_panel.gd"
## Codex: the minerals you have identified, with full reference data. Unknown ones stay hidden.

var list: ItemList
var details: RichTextLabel
var ids: Array = []


func _ready() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(190, 0)
	list.item_selected.connect(_on_selected)
	row.add_child(list)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)


func open() -> void:
	visible = true
	ids = GameData.minerals.keys()
	ids.sort_custom(func(a, b):
		var ta := int(GameData.mineral(a)["tier"])
		var tb := int(GameData.mineral(b)["tier"])
		return a < b if ta == tb else ta < tb)
	title_label.text = "Codex: %d of %d minerals identified" % [GameState.identified_count(), ids.size()]
	list.clear()
	for id in ids:
		var known: bool = GameState.correct_ids.has(id)
		list.add_item(GameData.mineral(id)["name"] if known else "??? (tier %d)" % int(GameData.mineral(id)["tier"]))
	details.text = "Identify samples in the Field Kit to fill the Codex."


func _on_selected(index: int) -> void:
	var id: String = ids[index]
	if not GameState.correct_ids.has(id):
		details.text = "Not identified yet."
		return
	var m := GameData.mineral(id)
	details.text = "\n".join([
		"[b]%s[/b]  %s" % [m["name"], m["formula"]],
		"Class: %s" % m["mineral_class"],
		"Crystal system: %s" % m["crystal_system"],
		"Hardness: %s   Density: %s g/cm3" % [GameData.hardness_text(m), m["specific_gravity"]],
		"Streak: %s   Luster: %s" % [m["streak"], m["luster"]],
		"Cleavage: %s" % m["cleavage"],
		"Colors: %s" % ", ".join(m["colors"]),
		"Key test: %s" % m["diagnostic"],
		"Found in: %s" % m["occurrence"],
		"Identified %d times. In stock: %d." % [GameState.correct_ids[id], GameState.stock.get(id, 0)],
	])
