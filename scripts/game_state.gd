extends Node
## Player progress: samples, identifications, crafting, and changes made to the world. Saved as JSON.

signal changed
signal toast(text: String)

const PICKS := [
	{"name": "Bronze pick", "hardness": 3.5},
	{"name": "Steel pick", "hardness": 6.5},
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
]
const MAX_SAMPLES := 24
## Rank titles by total correct identifications.
const RANKS := [[0, "Field assistant"], [5, "Undergraduate"], [15, "Graduate student"], [30, "Field geologist"], [60, "Professor"]]
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

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
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
	changed.emit()


func pick_hardness() -> float:
	return PICKS[pick_level]["hardness"]


func pick_name() -> String:
	return PICKS[pick_level]["name"]


func identified_count() -> int:
	return correct_ids.size()


func total_correct() -> int:
	var n := 0
	for id in correct_ids:
		n += correct_ids[id]
	return n


func rank_name() -> String:
	var name: String = RANKS[0][1]
	for r in RANKS:
		if total_correct() >= r[0]:
			name = r[1]
	return name


## Chooses which mineral a vein yields. Minerals you got wrong come back more often until you
## name them correctly, which is the game's spaced-repetition loop.
func roll_mineral(tier: int) -> String:
	var pool := GameData.mineral_ids_up_to_tier(tier)
	var weights := []
	var total := 0.0
	for id in pool:
		var w := 3.0 if int(GameData.mineral(id)["tier"]) == tier else 1.0
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


## Adds an unknown sample. Returns {} when the bag is full.
func add_sample(mineral_id: String, depth_m: int, tier: int, color := "") -> Dictionary:
	if samples.size() >= MAX_SAMPLES:
		return {}
	var m := GameData.mineral(mineral_id)
	var colors: Array = m["colors"]
	if color == "":
		color = colors[rng.randi_range(0, colors.size() - 1)]
	var sample := {
		"uid": next_uid, "mineral": mineral_id, "depth": depth_m, "tier": tier,
		"color": color, "notes": [], "choices": [],
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
		var others := GameData.mineral_ids_up_to_tier(int(sample["tier"]))
		others.erase(sample["mineral"])
		others.shuffle()
		var choices := [sample["mineral"]]
		choices.append_array(others.slice(0, 3))
		choices.shuffle()
		sample["choices"] = choices
	return sample["choices"]


## Names a sample. Correct: it joins your stock. Wrong: the sample is spent and that mineral returns more often.
func identify(uid: int, guess: String) -> bool:
	var sample := sample_by_uid(uid)
	if sample.is_empty():
		return false
	var answer: String = sample["mineral"]
	samples.erase(sample)
	var correct := guess == answer
	var old_rank := rank_name()
	if correct:
		correct_ids[answer] = correct_ids.get(answer, 0) + 1
		stock[answer] = stock.get(answer, 0) + 1
		if pending_misses.get(answer, 0) > 0:
			pending_misses[answer] -= 1
	else:
		pending_misses[answer] = pending_misses.get(answer, 0) + 1
	Sfx.play("correct" if correct else "wrong")
	if rank_name() != old_rank:
		Sfx.play("rank")
		toast.emit("Promoted to %s!" % rank_name())
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
	if id == "steel_pick":
		pick_level = 1
	changed.emit()
	save_game()
	return true


func save_game() -> void:
	var data := {
		"version": 1, "world_seed": world_seed, "samples": samples, "next_uid": next_uid,
		"correct_ids": correct_ids, "pending_misses": pending_misses, "stock": stock,
		"pick_level": pick_level, "built": built, "changed_cells": changed_cells, "player_pos": player_pos,
		"rubble": rubble,
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
	changed.emit()
	return true


func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out
