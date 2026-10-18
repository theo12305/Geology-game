extends Node
## Headless smoke test. Run: godot --headless --path . res://tests/smoke_test.tscn

var failures := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _ready() -> void:
	GameState.save_path = "user://smoke_test_save.json"
	GameState.new_game(1234)

	# Data
	check(GameData.minerals.size() == 30, "30 minerals loaded")
	check(GameData.rocks.size() == 15, "15 rocks loaded")
	for id in GameData.minerals:
		var m := GameData.mineral(id)
		for key in ["name", "formula", "crystal_system", "hardness", "streak", "luster", "cleavage", "specific_gravity", "colors", "diagnostic", "tier"]:
			check(m.has(key), "%s has %s" % [id, key])
		for line in [GameData.streak_test(m), GameData.scratch_test(m, "Steel knife", 5.5), GameData.acid_test(m),
				GameData.magnet_test(m), GameData.lens_test(m), GameData.heft_test(m), GameData.taste_test(m)]:
			check(line.length() > 5, "%s test text" % id)
	check(GameData.scratch_test(GameData.mineral("gypsum"), "Fingernail", 2.5).contains("softer"), "gypsum softer than nail")
	check(GameData.scratch_test(GameData.mineral("quartz"), "Steel knife", 5.5).contains("harder"), "quartz harder than knife")
	check(GameData.acid_test(GameData.mineral("calcite")).contains("Fizzes"), "calcite fizzes")

	# World
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var world = main.world
	for x in range(1, world.WIDTH - 1):
		for y in range(world.BAND_TOP, world.BAND_BOTTOM):
			check(world.get_tile(Vector2i(x, y)) == world.SANDSTONE, "sandstone band intact at %d,%d" % [x, y])
	var veins := {1: 0, 2: 0}
	var first_vein := Vector2i(-1, -1)
	for y in world.HEIGHT:
		for x in world.WIDTH:
			var t: int = world.get_tile(Vector2i(x, y))
			if world.is_vein(t):
				veins[world.tier_at(y)] += 1
				if first_vein.x < 0 and world.tier_at(y) == 1:
					first_vein = Vector2i(x, y)
	print("veins per tier: ", veins)
	check(veins[1] > 20 and veins[2] > 20, "enough veins in both tiers")

	# Mining a vein gives a sample
	main.finish_mining(first_vein)
	check(GameState.samples.size() == 1, "vein gave a sample")
	var s: Dictionary = GameState.samples[0]
	check(s["tier"] == 1 and int(GameData.mineral(s["mineral"])["tier"]) == 1, "tier 1 vein gives tier 1 mineral")
	var choices: Array = GameState.choices_for(s)
	check(choices.size() == 4 and choices.has(s["mineral"]), "four choices including the answer")
	check(GameState.choices_for(s) == choices, "choices stay fixed")

	# Wrong answer spends the sample and raises that mineral's weight
	var wrong: String = choices[0] if choices[0] != s["mineral"] else choices[1]
	var answer: String = s["mineral"]
	check(not GameState.identify(s["uid"], wrong), "wrong guess rejected")
	check(GameState.pending_misses.get(answer, 0) == 1, "miss recorded")
	var hits := 0
	for i in 400:
		if GameState.roll_mineral(1) == answer:
			hits += 1
	print("missed mineral share after one miss: ", hits / 400.0)
	check(hits > 400 / GameData.mineral_ids_up_to_tier(1).size(), "missed mineral comes back more often")

	# Correct answer adds stock; crafting chain
	var s2 := GameState.add_sample("calcite", 10, 1)
	check(GameState.identify(s2["uid"], "calcite"), "correct guess accepted")
	check(GameState.stock["calcite"] == 1, "stock added")
	check(not GameState.can_craft(GameState.recipe("furnace")), "furnace locked without materials")
	GameState.stock["calcite"] = 3
	GameState.stock["kaolinite"] = 2
	check(GameState.craft("furnace"), "furnace crafted")
	check(not GameState.can_craft(GameState.recipe("steel_pick")), "pick locked without iron")
	GameState.stock["hematite"] = 2
	GameState.stock["goethite"] = 1
	check(GameState.craft("steel_pick"), "steel pick crafted from mixed iron oxides")
	check(GameState.pick_hardness() == 6.5, "pick upgraded")
	check(GameState.stock["hematite"] == 0 and GameState.stock["goethite"] == 0, "materials consumed")

	# UI panels open without errors
	for i in 3:
		main.hud.open_panel(i)
	main.hud.panels[0].visible = false

	# Save and load round trip
	main.save()
	var cells := GameState.changed_cells.size()
	GameState.new_game(1)
	check(GameState.load_game(), "save loads")
	check(GameState.world_seed == 1234 and GameState.pick_level == 1, "progress restored")
	check(GameState.changed_cells.size() == cells, "world changes restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))

	print("smoke test: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	get_tree().quit(1 if failures else 0)
