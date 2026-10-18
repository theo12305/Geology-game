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
	check(GameData.rocks.size() == 16, "16 rocks loaded")
	check(GameData.fossils.size() == 8, "8 fossils loaded")
	check(GameData.lessons.size() == 12, "12 lessons loaded")
	for id in GameData.fossils:
		var f := GameData.fossil(id)
		check(f.get("explanation", "").length() > 100 and f.has("fact") and f.has("age"), "%s fossil text" % id)
	for l in GameData.lessons:
		check(l["text"].length() > 600, "%s lesson text" % l["id"])
		check(l["quiz"].size() == 3, "%s has 3 questions" % l["id"])
		for q in l["quiz"]:
			check(q["options"].size() == 4 and int(q["answer"]) >= 0 and int(q["answer"]) < 4 and q["why"] != "",
				"%s question well formed" % l["id"])
		for b in l["books"]:
			check(GameData.books.has(b), "%s book %s exists" % [l["id"], b])
		var u: Dictionary = l["unlock"]
		check(u["type"] in ["start", "level", "zone", "fossil"], "%s unlock type" % l["id"])
		if u["type"] == "zone":
			check(load("res://scripts/world.gd").ZONES.has(u["value"]), "%s zone exists" % l["id"])
	for id in GameData.minerals:
		check(GameData.mineral(id).get("explanation", "").length() > 100, "%s has an explanation" % id)
	for id in GameData.rocks:
		var r := GameData.rock(id)
		check(r.get("explanation", "").length() > 100, "%s has an explanation" % id)
		for mid in r["minerals"]:
			check(GameData.minerals.has(mid), "%s mineral %s exists" % [id, mid])
		for line in [GameData.rock_texture_test(r), GameData.rock_grain_test(r), GameData.rock_minerals_test(r), GameData.rock_acid_test(r)]:
			check(line.length() > 5, "%s rock test text" % id)
	for id in GameData.credits:
		check(ResourceLoader.exists(GameData.credits[id]["image"]), "photo for %s loads" % id)
	print("photos: ", GameData.credits.size())
	check(GameData.rock_acid_test(GameData.rock("dolostone")).contains("powder"), "dolostone fizzes only as powder")
	check(GameData.rock_acid_test(GameData.rock("marble")).contains("strongly"), "marble fizzes")
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
	var veins := {1: 0, 2: 0, 3: 0, 4: 0}
	for x in range(1, world.WIDTH - 1):
		for y in range(world.CHERT_TOP, world.CHERT_BOTTOM):
			check(world.get_tile(Vector2i(x, y)) == world.CHERT, "chert band intact at %d,%d" % [x, y])
	var first_vein := Vector2i(-1, -1)
	for y in world.HEIGHT:
		for x in world.WIDTH:
			var t: int = world.get_tile(Vector2i(x, y))
			if world.is_vein(t):
				veins[world.tier_at(y)] += 1
				if first_vein.x < 0 and world.tier_at(y) == 1:
					first_vein = Vector2i(x, y)
	print("veins per tier: ", veins)
	var counts := {"fossil": 0, "crystal": 0}
	for y in world.HEIGHT:
		for x in world.WIDTH:
			var t2: int = world.get_tile(Vector2i(x, y))
			if t2 == world.FOSSIL:
				counts["fossil"] += 1
			elif t2 == world.CRYSTAL:
				counts["crystal"] += 1
	print("fossils, crystals, decorations: ", counts, " ", world.deco.size())
	check(counts["fossil"] > 20 and counts["crystal"] > 20 and world.deco.size() > 50, "fossils, caverns and formations exist")
	check(world.zone_at(world.SURFACE_Y + 10) == "beds" and world.zone_at(world.GRANITE_TOP + 1) == "pluton", "zones by depth")
	for tier in veins:
		check(veins[tier] > 20, "enough veins in tier %d" % tier)

	# Mining a vein gives a sample
	main.finish_mining(first_vein)
	check(GameState.samples.size() == 1, "vein gave a sample")
	var s: Dictionary = GameState.samples[0]
	check(s["tier"] == 1 and int(GameData.mineral(s["id"])["tier"]) == 1, "tier 1 vein gives tier 1 mineral")
	var choices: Array = GameState.choices_for(s)
	check(choices.size() == 4 and choices.has(s["id"]), "four choices including the answer")
	check(GameState.choices_for(s) == choices, "choices stay fixed")

	# Wrong answer spends the sample and raises that mineral's weight
	var wrong: String = choices[0] if choices[0] != s["id"] else choices[1]
	var answer: String = s["id"]
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
	GameState.stock["magnetite"] = 3
	GameState.stock["fluorite"] = 2
	check(GameState.craft("hardened_pick"), "hardened pick crafted")
	check(GameState.pick_hardness() == 7.5, "pick upgraded to 7.5")

	# Rock samples: digging host rock can give one, identified against other rocks
	GameState.samples.clear()
	var rock_cell := Vector2i(30, world.SLATE_BOTTOM + 4)
	var got_rock := false
	for i in 40:
		world.set_tile(rock_cell, world.SCHIST)
		main.finish_mining(rock_cell)
		if not GameState.samples.is_empty():
			got_rock = true
			break
	check(got_rock, "digging schist gives a rock sample")
	if got_rock:
		var rs0: Dictionary = GameState.samples[0]
		check(rs0["kind"] == "rock" and rs0["id"] == "schist", "rock sample is schist")
		var rc: Array = GameState.choices_for(rs0)
		check(rc.size() == 4 and rc.has("schist") and GameData.rocks.has(rc[0]), "rock choices are rocks")
		check(GameState.identify(rs0["uid"], "schist"), "rock identified")
		check(GameState.identified_count("rock") == 1, "rock counted in codex")

	# Digging gives rubble; building places it; geodes give two crystal samples
	var dig_cell := Vector2i(-1, -1)
	for y in range(world.SURFACE_Y - 8, world.HEIGHT):
		var c := Vector2i(int(main.player.position.x / 16) + 1, y)
		if world.get_tile(c) == world.DIRT or world.get_tile(c) == world.GRASS:
			dig_cell = c
			break
	var rubble_before: int = GameState.rubble
	main.finish_mining(dig_cell)
	check(world.get_tile(dig_cell) == world.AIR and GameState.rubble == rubble_before + 1, "digging gives rubble")
	main.player.position = world.cell_center(dig_cell) + Vector2(-32, -16)
	check(main.try_place(dig_cell), "rubble placed back")
	check(world.get_tile(dig_cell) == world.RUBBLE and GameState.rubble == rubble_before, "placing uses rubble")
	GameState.samples.clear()
	var geode := Vector2i(5, 40)
	world.set_tile(geode, world.GEODE)
	main.finish_mining(geode)
	check(GameState.samples.size() == 2 and world.get_tile(geode) == world.AIR, "geode gives two samples")
	for gs in GameState.samples:
		check(GameState.choices_for(gs).has(gs["id"]), "geode sample choices include answer")
	var deep: Vector2 = world.cell_center(Vector2i(80, 70))
	main.player.position = deep
	main.rope_to_surface()
	check(main.player.position.y < deep.y - 16 * 20, "rope returns to surface")
	# XP, levels, streaks, coins
	GameState.xp = 0
	GameState.streak = 0
	check(GameState.level() == 1 and GameState.rank_name() == "Field assistant", "starting level and rank")
	var coins_before: int = GameState.coins
	for i in 5:
		var rs := GameState.add_sample("halite", 1, 1)
		GameState.identify(rs["uid"], "halite")
	check(GameState.streak == 5 and GameState.best_streak >= 5, "streak counts")
	check(GameState.last_reward["xp"] > 20, "streak raises the reward")
	check(GameState.coins > coins_before, "naming pays coins")
	check(GameState.level() >= 3 and GameState.rank_name() == "Undergraduate", "levels up to Undergraduate")
	var miss := GameState.add_sample("halite", 1, 1)
	GameState.identify(miss["uid"], "gypsum")
	check(GameState.streak == 0, "wrong answer resets the streak")
	check(GameState.xp_for_level(2) == 50 and GameState.xp_for_level(3) == 150, "level curve")

	# Tutorial goals advance, then three random goals take over
	GameState.tutorial_step = 0
	GameState.goals.clear()
	GameState._fill_goals()
	check(GameState.goals.size() == 1 and GameState.goals[0]["event"] == "walk", "tutorial starts with walking")
	var xp_before: int = GameState.xp
	GameState.track("walk")
	check(GameState.tutorial_step == 1 and GameState.xp > xp_before, "tutorial goal pays and advances")
	for event in ["dig", "sample", "test", "identify", "codex"]:
		GameState.track(event, 10)
	check(not GameState.in_tutorial() and GameState.goals.size() == 3, "three goals after the tutorial")
	for i in 30:
		var g: Dictionary = GameState.goals[0]
		GameState.track(g["event"], int(g["target"]), g.get("filter", ""))
	check(GameState.goals.size() == 3, "goals refill as they complete")
	GameState.goals = [{"event": "class", "filter": "sulfide", "target": 1, "progress": 0, "xp": 1, "coins": 1, "text": "x"}]
	GameState.track("class", 1, "Carbonate")
	check(GameState.goals[0]["progress"] == 0, "class goal ignores other classes")
	GameState.track("class", 1, "Sulfide")
	check(GameState.goals.size() == 3 and GameState.goals[0]["text"] != "x", "class goal completes")

	# Upgrades and the daily reward
	GameState.coins = 1000
	var slots: int = GameState.max_samples()
	check(GameState.buy_upgrade("bag") and GameState.max_samples() == slots + 6, "bag upgrade adds slots")
	check(GameState.upgrade_cost("bag") == 90, "upgrade cost rises")
	check(GameState.buy_upgrade("speed") and GameState.dig_speed() > 1.0, "speed upgrade")

	# Fossils, zones, lessons and mastery
	var fossil := GameState.find_fossil(1)
	check(fossil["first"] and GameState.fossils_found.has(fossil["id"]), "first fossil recorded")
	check(int(GameData.fossil(fossil["id"])["tier"]) == 1, "tier 1 rock gives a tier 1 fossil")
	check(GameState.discover_zone("beds") and not GameState.discover_zone("beds"), "zone discovered once")
	var sed := GameData.lesson("sedimentary_rocks")
	check(GameState.lesson_unlocked(sed), "zone unlocks its lesson")
	check(not GameState.lesson_unlocked(GameData.lesson("igneous_rocks")), "deeper lesson still locked")
	check(GameState.lesson_unlocked(GameData.lesson("fossils_and_time")), "fossil unlocks the fossil lesson")
	var xp_quiz: int = GameState.xp
	check(not GameState.finish_quiz("sedimentary_rocks", 2, 3), "2 of 3 does not pass")
	check(GameState.finish_quiz("sedimentary_rocks", 3, 3) and GameState.xp >= xp_quiz + GameState.XP_LESSON_PASS, "passing pays")
	check(GameState.lessons_passed.has("sedimentary_rocks"), "pass recorded")
	GameState.correct_ids["quartz"] = 5
	var q6 := GameState.add_sample("quartz", 1, 1)
	GameState.identify(q6["uid"], "quartz")
	check(GameState.mastery("quartz") == 2 and GameState.last_reward["mastery"] == 2, "silver mastery at 6")
	check(GameData.comparison_bbcode("mineral", "quartz", "calcite").contains("Streak"), "comparison table")
	check(GameData.comparison_bbcode("rock", "granite", "basalt").contains("Texture"), "rock comparison table")

	# Climbing out of a shaft
	var sx := 70
	var top_y := 0
	while world.get_tile(Vector2i(sx, top_y)) == world.AIR:
		top_y += 1
	for y in range(top_y, top_y + 8):
		world.set_tile(Vector2i(sx, y), world.AIR)
	main.player.position = world.cell_center(Vector2i(sx, top_y + 7))
	main.player.velocity = Vector2.ZERO
	main.player.stop_walking()
	for i in 20:
		await get_tree().physics_frame
	var bottom_y: float = main.player.position.y
	main.player.climb_to(world.cell_center(Vector2i(sx, top_y - 2)).y)
	for i in 180:
		await get_tree().physics_frame
	print("climbed from ", bottom_y, " to ", main.player.position.y)
	check(main.player.position.y < bottom_y - 16 * 5, "climbed out of an 8-deep shaft")

	# One tap mines a block in reach without holding
	var tap_cell: Vector2i = world.cell_at(main.player.position) + Vector2i(1, 0)
	world.set_tile(tap_cell, world.DIRT)
	main.target_block(tap_cell)
	main.release_pointer()
	for i in 30:
		await get_tree().process_frame
	check(world.get_tile(tap_cell) == world.AIR, "a single tap mines the block")

	# UI panels open without errors, including every Bag, Codex and School page
	for i in 5:
		main.hud.open_panel(i)
	var codex = main.hud.panels[1]
	codex.show_entry("fossil", fossil["id"])
	check(codex.details.text.contains(GameData.fossil(fossil["id"])["name"]), "codex shows the fossil")
	for id in ["calcite", "halite", "gypsum", "hematite", "quartz"]:
		GameState.correct_ids[id] = maxi(GameState.correct_ids.get(id, 0), 1)
	codex.kind = "mineral"
	codex.open()
	check(codex.quiz_button.visible, "photo quiz available")
	codex._start_quiz()
	var xp_photo: int = GameState.xp
	codex._quiz_answer(codex.quiz_id)
	check(GameState.xp > xp_photo, "photo quiz pays")
	var school = main.hud.panels[4]
	main.hud.open_panel(4)
	school.open_lesson("what_is_a_mineral")
	check(GameState.lessons_read.has("what_is_a_mineral"), "lesson marked read")
	school._start_quiz()
	for qi in 3:
		school._answer(int(GameData.lesson("what_is_a_mineral")["quiz"][qi]["answer"]))
		school._next()
	check(GameState.lessons_passed.has("what_is_a_mineral"), "school quiz passed through the UI")
	school.close_panel()
	main.hud.show_card("Test", "sub", "body", "trilobite", "More", func(): pass)
	check(main.hud.panel_open(), "card blocks taps")
	main.hud.close_card()
	var kit = main.hud.panels[0]
	var ks := GameState.add_sample("quartz", 5, 1)
	main.hud.open_panel(0)
	kit._open_sample(ks["uid"])
	kit._run_test(GameData.streak_test(GameData.mineral("quartz")))
	check(ks["notes"].size() == 1, "test result written in the notebook")
	kit.choosing = true
	kit._render_sample()
	GameState.coins = 50
	kit._use_hint()
	check(GameState.choices_for(ks).size() == 3 and GameState.choices_for(ks).has("quartz"), "hint drops a wrong answer")
	kit._answer("quartz")
	check(kit.page == "result", "result page shown")
	kit.close_panel()
	GameState.set_setting("contrast", true)
	GameState.set_setting("text_size", 3)
	check(main.hud.root.theme.default_font_size == 21, "text size setting applies")
	GameState.set_setting("contrast", false)
	GameState.set_setting("text_size", 1)

	# Save and load round trip
	main.save()
	var cells := GameState.changed_cells.size()
	GameState.new_game(1)
	check(GameState.load_game(), "save loads")
	check(GameState.world_seed == 1234 and GameState.pick_level == 2, "progress restored")
	check(GameState.upgrade_level("bag") == 1 and GameState.coins > 0 and GameState.xp > 0, "XP, coins and upgrades restored")
	check(GameState.goals.size() == 3 and not GameState.in_tutorial(), "goals restored")
	check(not GameState.fossils_found.is_empty() and "beds" in GameState.zones_found and GameState.lessons_passed.size() == 2,
		"fossils, zones and lessons restored")
	check(GameState.changed_cells.size() == cells, "world changes restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))

	print("smoke test: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	get_tree().quit(1 if failures else 0)
