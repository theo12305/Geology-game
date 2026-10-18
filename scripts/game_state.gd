extends Node
## Player progress: samples, identifications, crafting, XP, coins, goals, upgrades and changes made to the
## world. Saved as JSON. Settings live in their own file so a new game keeps them.

signal changed
signal toast(text: String)
signal xp_gained(amount: int, coins: int)
signal leveled_up(level: int)
signal goal_completed(goal: Dictionary)
signal settings_changed

const PICKS := [
	{"name": "Bronze pick", "hardness": 3.5},
	{"name": "Steel pick", "hardness": 6.5},
	{"name": "Hardened pick", "hardness": 7.5},
]
## Scratch tools in the field kit: name, Mohs hardness, mineral that must be identified first ("" = always),
## short button label.
const SCRATCH_TOOLS := [
	["Fingernail", 2.5, "", "Nail"],
	["Copper coin", 3.5, "", "Coin"],
	["Steel knife", 5.5, "", "Knife"],
	["Quartz", 7.0, "quartz", "Quartz"],
]
const RECIPES := [
	{
		"id": "furnace", "name": "Furnace", "requires": "",
		"needs": [
			{"ids": ["calcite"], "count": 3, "label": "calcite (flux)"},
			{"ids": ["kaolinite"], "count": 2, "label": "kaolinite (fireclay bricks)"},
		],
		"info": "Limestone flux and fireclay bricks, the classic ingredients of an iron furnace.",
	},
	{
		"id": "steel_pick", "name": "Steel pick (hardness 6.5)", "requires": "furnace",
		"needs": [
			{"ids": ["hematite", "magnetite", "goethite"], "count": 3, "label": "iron oxides (hematite, magnetite, goethite)"},
		],
		"info": "Hard enough to cut the quartz-cemented sandstone band and reach the deep basin.",
	},
	{
		"id": "hardened_pick", "name": "Hardened pick (hardness 7.5)", "requires": "steel_pick",
		"needs": [
			{"ids": ["hematite", "magnetite", "goethite"], "count": 3, "label": "iron oxides"},
			{"ids": ["fluorite"], "count": 2, "label": "fluorite (fluorspar flux)"},
		],
		"info": "Fluorspar-fluxed steel, hard enough for the chert band and the metamorphic belt below it.",
	},
]
const MAX_SAMPLES := 20
## Chance that mining a host rock block also gives a rock sample (higher before you know that rock).
const ROCK_SAMPLE_CHANCE := 0.1
const NEW_ROCK_SAMPLE_CHANCE := 0.3
## Rank titles by level.
const RANKS := [[1, "Field assistant"], [3, "Undergraduate"], [6, "Graduate student"], [10, "Field geologist"],
	[15, "Senior geologist"], [20, "Professor"]]
## XP for actions. Naming a sample also scales with its tier and your streak.
const XP_DIG := 1
const XP_SAMPLE := 5
const XP_GEODE := 25
const XP_FIRST_FIND := 30
## Shop upgrades bought with coins. Cost of level n+1 is base * (n+1) * (n+2) / 2.
const UPGRADES := [
	{"id": "bag", "name": "Bigger sample bag", "icon": "bag", "max": 5, "base": 30, "info": "+6 sample slots per level."},
	{"id": "speed", "name": "Sharper pick edge", "icon": "pick", "max": 5, "base": 40, "info": "Dig 20% faster per level."},
	{"id": "lamp", "name": "Brighter headlamp", "icon": "lamp", "max": 4, "base": 25, "info": "Lights up more of the dark."},
	{"id": "luck", "name": "Prospector's eye", "icon": "star", "max": 5, "base": 50,
		"info": "More bonus samples, rock samples and gold flakes."},
]
## First goals, one at a time, that teach the controls.
const TUTORIAL := [
	{"event": "walk", "target": 1, "text": "Tap open ground to walk there", "hint": ""},
	{"event": "dig", "target": 5, "text": "Tap blocks to dig 5 of them", "hint": ""},
	{"event": "sample", "target": 1, "text": "Dig a glittering vein for a sample", "hint": ""},
	{"event": "test", "target": 2, "text": "Open your Bag and run 2 tests", "hint": "bag"},
	{"event": "identify", "target": 1, "text": "Name a sample correctly", "hint": "bag"},
	{"event": "codex", "target": 1, "text": "Read about your find in the Codex", "hint": "codex"},
]
## Goals that refresh after the tutorial. "max" goals track the best value rather than a running total.
const GOAL_TEMPLATES := [
	{"event": "dig", "text": "Dig %d blocks", "targets": [20, 35, 60]},
	{"event": "sample", "text": "Collect %d samples", "targets": [3, 5, 8]},
	{"event": "identify", "text": "Name %d samples correctly", "targets": [2, 3, 5]},
	{"event": "test", "text": "Run %d field tests", "targets": [6, 10, 15]},
	{"event": "streak", "text": "Get a streak of %d correct", "targets": [3, 4, 6], "max": true},
	{"event": "rock", "text": "Name %d rocks correctly", "targets": [1, 2, 3]},
	{"event": "build", "text": "Place %d blocks", "targets": [5, 10]},
	{"event": "depth", "text": "Reach %d m deep", "max": true},
	{"event": "class", "text": "Name a %s mineral"},
]
## Mineral class goals: word to match in mineral_class, and how the goal names it.
const CLASS_WORDS := [["carbonate", "carbonate"], ["sulfate", "sulfate"], ["oxide", "oxide"], ["sulfide", "sulfide"],
	["halide", "halide"], ["silicate", "silicate"], ["native", "native element"]]
const ACTIVE_GOALS := 3
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {"text_size": 1, "contrast": false, "sound": true, "vibrate": true, "shake": true}
## Minerals that grow as crystals inside geodes, with the variety color they show.
const GEODE_CRYSTALS := {"quartz": "purple", "calcite": "colorless", "fluorite": "purple", "barite": "blue"}

var save_path := "user://save.json"
var world_seed := 0
var samples: Array = []
var next_uid := 1
var correct_ids: Dictionary = {}      # mineral id -> times identified correctly
var pending_misses: Dictionary = {}   # mineral id -> wrong answers not yet made up for
var stock: Dictionary = {}            # mineral id -> identified samples available for crafting
var pick_level := 0
var built: Dictionary = {}
var changed_cells: Dictionary = {}    # "x,y" -> tile id
var player_pos: Array = []
var rubble := 0
var xp := 0
var coins := 0
var streak := 0
var best_streak := 0
var max_depth := 0
var blocks_dug := 0
var daily := {"day": -1, "streak": 0}
var upgrades := {}                    # upgrade id -> level
var goals: Array = []
var tutorial_step := 0
var settings := DEFAULT_SETTINGS.duplicate()
## What the last identify() paid out, for the result screen.
var last_reward := {}

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_settings()
	if not load_game():
		new_game()


func new_game(seed := -1) -> void:
	world_seed = seed if seed >= 0 else rng.randi_range(0, 999999)
	samples = []
	next_uid = 1
	correct_ids = {}
	pending_misses = {}
	stock = {}
	pick_level = 0
	built = {}
	changed_cells = {}
	player_pos = []
	rubble = 0
	xp = 0
	coins = 0
	streak = 0
	best_streak = 0
	max_depth = 0
	blocks_dug = 0
	daily = {"day": -1, "streak": 0}
	upgrades = {}
	tutorial_step = 0
	goals = []
	_fill_goals()
	changed.emit()


func pick_hardness() -> float:
	return PICKS[pick_level]["hardness"]


func pick_name() -> String:
	return PICKS[pick_level]["name"]


## Distinct minerals (or rocks) identified at least once.
func identified_count(kind := "mineral") -> int:
	var n := 0
	for id in correct_ids:
		if (kind == "rock") == GameData.rocks.has(id):
			n += 1
	return n


func total_correct() -> int:
	var n := 0
	for id in correct_ids:
		n += correct_ids[id]
	return n


func rank_name() -> String:
	var name: String = RANKS[0][1]
	for r in RANKS:
		if level() >= r[0]:
			name = r[1]
	return name


# --- XP, levels and coins ---

## Total XP needed to reach a level: 0, 50, 150, 300, 500, ...
static func xp_for_level(n: int) -> int:
	return 25 * n * (n - 1)


func level() -> int:
	var n := 1
	while xp >= xp_for_level(n + 1):
		n += 1
	return n


## Progress through the current level, 0 to 1.
func level_progress() -> float:
	var lo := xp_for_level(level())
	return float(xp - lo) / float(xp_for_level(level() + 1) - lo)


func add_xp(amount: int, coin_amount := 0) -> void:
	var old_level := level()
	var old_rank := rank_name()
	xp += amount
	coins += coin_amount
	xp_gained.emit(amount, coin_amount)
	if level() > old_level:
		Sfx.play("rank")
		leveled_up.emit(level())
		if rank_name() != old_rank:
			toast.emit("Promoted to %s!" % rank_name())
	changed.emit()


func add_coins(amount: int) -> void:
	coins += amount
	changed.emit()


## Daily reward, once per calendar day. Logging in on consecutive days grows it. Returns {} if already claimed.
func claim_daily() -> Dictionary:
	var today := _day_number()
	if int(daily["day"]) == today:
		return {}
	var days := int(daily["streak"]) + 1 if int(daily["day"]) == today - 1 else 1
	daily = {"day": today, "streak": days}
	var reward := {"days": days, "coins": 20 + 10 * mini(days, 7), "xp": 10 * mini(days, 7)}
	add_xp(reward["xp"], reward["coins"])
	save_game()
	return reward


func _day_number() -> int:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return int((Time.get_unix_time_from_system() + bias * 60) / 86400)


# --- Upgrades ---

func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_info(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


func upgrade_cost(id: String) -> int:
	var n := upgrade_level(id)
	return int(upgrade_info(id)["base"]) * (n + 1) * (n + 2) / 2


func can_buy(id: String) -> bool:
	return upgrade_level(id) < int(upgrade_info(id)["max"]) and coins >= upgrade_cost(id)


func buy_upgrade(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= upgrade_cost(id)
	upgrades[id] = upgrade_level(id) + 1
	Sfx.play("craft")
	track("upgrade")
	changed.emit()
	save_game()
	return true


func max_samples() -> int:
	return MAX_SAMPLES + 6 * upgrade_level("bag")


func dig_speed() -> float:
	return pow(1.25, upgrade_level("speed"))


func luck() -> int:
	return upgrade_level("luck")


# --- Goals ---

## Counts an event towards the active goals. Most events add `amount`; "max" goals keep the best value.
## data filters goals that need a particular kind (a mineral class).
func track(event: String, amount := 1, data := "") -> void:
	if event == "depth":
		max_depth = maxi(max_depth, amount)
	for g in goals.duplicate():
		if g["event"] != event:
			continue
		if g.get("filter", "") != "" and not data.to_lower().contains(g["filter"]):
			continue
		if g.get("max", false):
			g["progress"] = maxi(int(g["progress"]), amount)
		else:
			g["progress"] = int(g["progress"]) + amount
		if int(g["progress"]) >= int(g["target"]):
			_complete_goal(g)


func _complete_goal(g: Dictionary) -> void:
	goals.erase(g)
	if g.get("tutorial", false):
		tutorial_step += 1
	Sfx.play("goal")
	goal_completed.emit(g)
	add_xp(int(g["xp"]), int(g["coins"]))
	_fill_goals()
	changed.emit()


func in_tutorial() -> bool:
	return tutorial_step < TUTORIAL.size()


## Which HUD button the current tutorial goal points at, or "".
func tutorial_hint() -> String:
	for g in goals:
		if g.get("tutorial", false):
			return g.get("hint", "")
	return ""


func _fill_goals() -> void:
	if in_tutorial():
		if goals.is_empty():
			var t: Dictionary = TUTORIAL[tutorial_step].duplicate()
			t.merge({"progress": 0, "xp": 15 + 5 * tutorial_step, "coins": 10, "tutorial": true})
			goals.append(t)
		return
	var tries := 0
	while goals.size() < ACTIVE_GOALS and tries < 50:
		tries += 1
		var g := _random_goal()
		if g.is_empty():
			continue
		var clash := false
		for other in goals:
			clash = clash or other["event"] == g["event"]
		if not clash:
			goals.append(g)


func _random_goal() -> Dictionary:
	var tpl: Dictionary = GOAL_TEMPLATES[rng.randi_range(0, GOAL_TEMPLATES.size() - 1)]
	var g := {"event": tpl["event"], "progress": 0, "max": tpl.get("max", false)}
	var difficulty := 0
	match tpl["event"]:
		"depth":
			var deepest := deepest_reachable_m()
			if max_depth + 20 > deepest:
				return {}
			g["target"] = mini(deepest, (max_depth / 10 + 2 + rng.randi_range(0, 2)) * 10)
			g["text"] = tpl["text"] % g["target"]
			difficulty = 1
		"class":
			var options := []
			for pair in CLASS_WORDS:
				for id in GameData.mineral_ids_up_to_tier(reachable_tier()):
					if GameData.mineral(id)["mineral_class"].to_lower().contains(pair[0]):
						options.append(pair)
						break
			var pair: Array = options[rng.randi_range(0, options.size() - 1)]
			g.merge({"target": 1, "filter": pair[0], "text": tpl["text"] % pair[1]})
			difficulty = 1
		"build":
			if blocks_dug < 30:
				return {}
			difficulty = rng.randi_range(0, tpl["targets"].size() - 1)
			g["target"] = tpl["targets"][difficulty]
			g["text"] = tpl["text"] % g["target"]
		_:
			difficulty = rng.randi_range(0, tpl["targets"].size() - 1)
			g["target"] = tpl["targets"][difficulty]
			g["text"] = tpl["text"] % g["target"]
			if g["event"] == "streak":
				g["progress"] = 0
	var scale := 1.0 + 0.5 * difficulty
	g["xp"] = int((30 + 8 * level()) * scale)
	g["coins"] = int((15 + 4 * level()) * scale)
	return g


## Deepest tier the current pick can dig into.
func reachable_tier() -> int:
	return [1, 2, 4][pick_level]


## Depth in meters of the hard band that stops the current pick (bottom of the world for the last pick).
func deepest_reachable_m() -> int:
	return [68, 140, 300][pick_level]

## Chooses which mineral a vein yields. Minerals you got wrong come back more often until you
## name them correctly, which is the game's spaced-repetition loop.
func roll_mineral(tier: int) -> String:
	var pool := GameData.mineral_ids_up_to_tier(tier)
	return _weighted_pick(pool, tier, "mineral")


## Whether mining a block of this rock should also give a rock sample.
func roll_rock_sample(rock_id: String) -> bool:
	var chance := ROCK_SAMPLE_CHANCE if correct_ids.has(rock_id) else NEW_ROCK_SAMPLE_CHANCE
	chance += 0.03 * luck()
	chance += 0.2 * pending_misses.get(rock_id, 0)
	return rng.randf() < chance


func _weighted_pick(pool: Array, tier: int, kind: String) -> String:
	var weights := []
	var total := 0.0
	for id in pool:
		var w := 3.0 if int(GameData.entry(kind, id)["tier"]) == tier else 1.0
		if not correct_ids.has(id):
			w *= 1.5
		w += 4.0 * pending_misses.get(id, 0)
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in pool.size():
		pick -= weights[i]
		if pick <= 0.0:
			return pool[i]
	return pool[-1]


## A crystal from a geode: one of the minerals that line geode cavities.
func roll_geode_crystal() -> String:
	var ids := GEODE_CRYSTALS.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]


## Adds an unknown mineral sample. Returns {} when the bag is full.
func add_sample(mineral_id: String, depth_m: int, tier: int, color := "") -> Dictionary:
	if samples.size() >= max_samples():
		return {}
	var m := GameData.mineral(mineral_id)
	var colors: Array = m["colors"]
	if color == "":
		color = colors[rng.randi_range(0, colors.size() - 1)]
	var sample := {
		"uid": next_uid, "kind": "mineral", "id": mineral_id, "depth": depth_m, "tier": tier,
		"color": color, "notes": [], "choices": [],
	}
	next_uid += 1
	samples.append(sample)
	changed.emit()
	return sample


## Adds an unknown rock sample. swatch is the rock's color as hex, shown in the sample list.
func add_rock_sample(rock_id: String, depth_m: int, tier: int, swatch: String) -> Dictionary:
	if samples.size() >= max_samples():
		return {}
	var sample := {
		"uid": next_uid, "kind": "rock", "id": rock_id, "depth": depth_m,
		"tier": maxi(tier, int(GameData.rock(rock_id)["tier"])), "color": swatch, "notes": [], "choices": [],
	}
	next_uid += 1
	samples.append(sample)
	changed.emit()
	return sample


func sample_by_uid(uid: int) -> Dictionary:
	for s in samples:
		if int(s["uid"]) == uid:
			return s
	return {}


## Four names to choose from, fixed per sample so reopening the kit cannot be used to eliminate options.
func choices_for(sample: Dictionary) -> Array:
	if sample["choices"].is_empty():
		var others := GameData.ids_up_to_tier(sample["kind"], int(sample["tier"]))
		others.erase(sample["id"])
		others.shuffle()
		var choices := [sample["id"]]
		choices.append_array(others.slice(0, 3))
		choices.shuffle()
		sample["choices"] = choices
	return sample["choices"]


## Names a sample. Correct: it joins your stock and pays XP and coins, more on a streak and for a first find.
## Wrong: the sample is spent, the streak resets and that mineral returns more often.
func identify(uid: int, guess: String) -> bool:
	var sample := sample_by_uid(uid)
	if sample.is_empty():
		return false
	var answer: String = sample["id"]
	var kind: String = sample["kind"]
	samples.erase(sample)
	var correct := guess == answer
	last_reward = {"xp": 0, "coins": 0, "streak": 0, "first": false}
	if correct:
		var first := not correct_ids.has(answer)
		correct_ids[answer] = correct_ids.get(answer, 0) + 1
		stock[answer] = stock.get(answer, 0) + 1
		if pending_misses.get(answer, 0) > 0:
			pending_misses[answer] -= 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		var tier := int(sample["tier"])
		var gained := int((15 + 5 * tier) * (1.0 + 0.25 * mini(streak - 1, 8)))
		var gold := 5 + 3 * tier
		if first:
			gained += XP_FIRST_FIND
			gold += 10
		last_reward = {"xp": gained, "coins": gold, "streak": streak, "first": first}
		Sfx.play("correct")
		add_xp(gained, gold)
		track("identify")
		track("streak", streak)
		if kind == "rock":
			track("rock")
		else:
			track("class", 1, GameData.mineral(answer)["mineral_class"])
	else:
		pending_misses[answer] = pending_misses.get(answer, 0) + 1
		streak = 0
		last_reward = {"xp": 2, "coins": 0, "streak": 0, "first": false}
		Sfx.play("wrong")
		add_xp(2)
	changed.emit()
	return correct


func has_built(id: String) -> bool:
	return built.get(id, false)


func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == id:
			return r
	return {}


func have_for(need: Dictionary) -> int:
	var n := 0
	for id in need["ids"]:
		n += stock.get(id, 0)
	return n


func can_craft(r: Dictionary) -> bool:
	if has_built(r["id"]):
		return false
	if r["requires"] != "" and not has_built(r["requires"]):
		return false
	for need in r["needs"]:
		if have_for(need) < need["count"]:
			return false
	return true


func craft(id: String) -> bool:
	var r := recipe(id)
	if r.is_empty() or not can_craft(r):
		return false
	for need in r["needs"]:
		var left: int = need["count"]
		for mid in need["ids"]:
			var take := mini(left, stock.get(mid, 0))
			stock[mid] = stock.get(mid, 0) - take
			left -= take
	built[id] = true
	Sfx.play("craft")
	track("craft")
	if id == "steel_pick":
		pick_level = 1
	elif id == "hardened_pick":
		pick_level = 2
	changed.emit()
	save_game()
	return true


func save_game() -> void:
	var data := {
		"version": 1, "world_seed": world_seed, "samples": samples, "next_uid": next_uid,
		"correct_ids": correct_ids, "pending_misses": pending_misses, "stock": stock,
		"pick_level": pick_level, "built": built, "changed_cells": changed_cells, "player_pos": player_pos,
		"rubble": rubble, "xp": xp, "coins": coins, "streak": streak, "best_streak": best_streak,
		"max_depth": max_depth, "blocks_dug": blocks_dug, "daily": daily, "upgrades": upgrades, "goals": goals,
		"tutorial_step": tutorial_step,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	world_seed = int(parsed["world_seed"])
	samples = parsed["samples"]
	for s in samples:
		if not s.has("kind"):  # saves from before rock samples
			s["kind"] = "mineral"
			s["id"] = s["mineral"]
		s["uid"] = int(s["uid"])
		s["depth"] = int(s["depth"])
		s["tier"] = int(s["tier"])
	next_uid = int(parsed["next_uid"])
	correct_ids = _int_values(parsed["correct_ids"])
	pending_misses = _int_values(parsed["pending_misses"])
	stock = _int_values(parsed["stock"])
	pick_level = int(parsed["pick_level"])
	built = parsed["built"]
	changed_cells = _int_values(parsed["changed_cells"])
	player_pos = parsed["player_pos"]
	rubble = int(parsed.get("rubble", 0))
	xp = int(parsed.get("xp", 0))
	coins = int(parsed.get("coins", 0))
	streak = int(parsed.get("streak", 0))
	best_streak = int(parsed.get("best_streak", 0))
	max_depth = int(parsed.get("max_depth", 0))
	blocks_dug = int(parsed.get("blocks_dug", 0))
	var d: Dictionary = parsed.get("daily", {})
	daily = {"day": int(d.get("day", -1)), "streak": int(d.get("streak", 0))}
	upgrades = _int_values(parsed.get("upgrades", {}))
	goals = parsed.get("goals", [])
	for g in goals:
		for key in ["target", "progress", "xp", "coins"]:
			g[key] = int(g[key])
	if parsed.has("tutorial_step"):
		tutorial_step = int(parsed["tutorial_step"])
	else:
		# Saves from before goals: players who already named samples skip the tutorial, and get XP for them.
		tutorial_step = TUTORIAL.size() if total_correct() > 0 else 0
		xp = 25 * total_correct() + blocks_dug
	_fill_goals()
	changed.emit()
	return true


func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in settings:
				if parsed.has(k):
					settings[k] = parsed[k]
	settings["text_size"] = int(settings["text_size"])


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
	settings_changed.emit()


## A short buzz on phones, if vibration is on.
func buzz(ms := 30) -> void:
	if settings["vibrate"]:
		Input.vibrate_handheld(ms)


func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out
