extends "res://scripts/menu_panel.gd"
## Crafting: turn identified minerals into tools that open up deeper rock.


func _ready() -> void:
	title_label.text = "Craft"


func open() -> void:
	visible = true
	for c in body.get_children():
		c.queue_free()
	for r in GameState.RECIPES:
		var row := HBoxContainer.new()
		body.add_child(row)
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lines := [r["name"]]
		for need in r["needs"]:
			lines.append("  %d / %d %s" % [mini(GameState.have_for(need), need["count"]), need["count"], need["label"]])
		if r["requires"] != "":
			lines.append("  Needs: %s" % GameState.recipe(r["requires"])["name"])
		lines.append("  " + r["info"])
		info.text = "\n".join(lines)
		row.add_child(info)
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 0)
		b.text = "Built" if GameState.has_built(r["id"]) else "Craft"
		b.disabled = not GameState.can_craft(r)
		b.pressed.connect(func():
			if GameState.craft(r["id"]):
				GameState.toast.emit("Crafted %s." % r["name"])
			open())
		row.add_child(b)
		body.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "Only correctly identified samples count. Wrong guesses are lost."
	hint.add_theme_color_override("font_color", Color("a99bb3"))
	body.add_child(hint)
