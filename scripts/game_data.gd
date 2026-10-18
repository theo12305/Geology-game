extends Node
## Mineral and rock reference data loaded from res://data.
## Everything the game says about a mineral, and every field test result, comes from here.

const MINERALS_PATH := "res://data/minerals.json"
const ROCKS_PATH := "res://data/rocks.json"

## Swatch colors for the color words used in minerals.json, checked in order.
const COLOR_KEYWORDS := [
	["colorless", Color("dbe7ec")], ["white", Color("f0ede2")], ["cream", Color("eadcb8")],
	["smoky", Color("6b625a")], ["purple", Color("8e5bb5")], ["pink", Color("e39aac")],
	["blue", Color("5b80c9")], ["green", Color("4f9a4a")], ["brass", Color("d4b545")],
	["yellow-brown", Color("a87a2c")], ["yellow", Color("e3c93b")], ["copper", Color("c7703a")],
	["red", Color("b8352e")], ["brown", Color("7a4b2a")], ["silver", Color("b5b8bd")],
	["steel", Color("6e7378")], ["grey", Color("9a9a9a")], ["black", Color("26262b")],
]

const ACID_REACTIONS := {
	"calcite": "Fizzes vigorously in cold dilute HCl.",
	"dolomite": "Barely reacts. Scrape some to powder and the powder fizzes slowly.",
	"malachite": "Fizzes, and the acid turns faintly green.",
	"sphalerite": "Weak reaction with a rotten-egg (H2S) smell.",
}

var minerals: Dictionary = {}
var rocks: Dictionary = {}


func _ready() -> void:
	minerals = _load_entries(MINERALS_PATH, "minerals")
	rocks = _load_entries(ROCKS_PATH, "rocks")


func _load_entries(path: String, key: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var out := {}
	for entry in parsed[key]:
		out[entry["id"]] = entry
	return out


func mineral(id: String) -> Dictionary:
	return minerals.get(id, {})


## Mineral ids that occur at this tier or shallower, sorted for stable ordering.
func mineral_ids_up_to_tier(tier: int) -> Array:
	var ids := []
	for id in minerals:
		if int(minerals[id]["tier"]) <= tier:
			ids.append(id)
	ids.sort()
	return ids


func color_of(word: String) -> Color:
	for pair in COLOR_KEYWORDS:
		if word.contains(pair[0]):
			return pair[1]
	return Color("9a9a9a")


func hardness_text(m: Dictionary) -> String:
	var lo: float = m["hardness"]["min"]
	var hi: float = m["hardness"]["max"]
	return ("%s" % lo) if lo == hi else ("%s to %s" % [lo, hi])


# --- Field tests. Each returns one line of notebook text for mineral m. ---

func streak_test(m: Dictionary) -> String:
	return "Streak plate: %s streak." % m["streak"]


func scratch_test(m: Dictionary, tool_name: String, tool_hardness: float) -> String:
	var lo: float = m["hardness"]["min"]
	var hi: float = m["hardness"]["max"]
	if hi < tool_hardness:
		return "%s (%s) scratches it: softer than %s." % [tool_name, tool_hardness, tool_hardness]
	if lo > tool_hardness:
		return "%s (%s) leaves no mark, the sample scratches it: harder than %s." % [tool_name, tool_hardness, tool_hardness]
	return "%s (%s) and the sample scratch each other: hardness close to %s." % [tool_name, tool_hardness, tool_hardness]


func acid_test(m: Dictionary) -> String:
	return "Dilute HCl: " + ACID_REACTIONS.get(m["id"], "No reaction.")


func magnet_test(m: Dictionary) -> String:
	if m["id"] == "magnetite":
		return "Magnet: snaps on hard. Strongly magnetic."
	return "Magnet: no attraction."


func lens_test(m: Dictionary) -> String:
	return "Hand lens: %s luster. Cleavage: %s." % [m["luster"], m["cleavage"]]


func heft_test(m: Dictionary) -> String:
	var sg: float = m["specific_gravity"]
	var feel := "about average for a rock"
	if sg < 2.4:
		feel = "light"
	elif sg >= 4.5:
		feel = "very heavy"
	elif sg >= 3.2:
		feel = "noticeably heavy"
	return "Heft: feels %s (estimated density %.1f g/cm3)." % [feel, sg]


func taste_test(m: Dictionary) -> String:
	if m["id"] == "halite":
		return "Taste: salty."
	return "Taste: nothing. Never lick a sample you suspect is toxic, like galena!"
