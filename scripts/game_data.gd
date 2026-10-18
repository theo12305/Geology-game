extends Node
## Mineral, rock, fossil and lesson data loaded from res://data.
## Everything the game says about a mineral, every field test result, and the Field School come from here.

const MINERALS_PATH := "res://data/minerals.json"
const ROCKS_PATH := "res://data/rocks.json"
const CREDITS_PATH := "res://data/image_credits.json"
const FOSSILS_PATH := "res://data/fossils.json"
const LESSONS_PATH := "res://data/lessons.json"

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
var credits: Dictionary = {}
var fossils: Dictionary = {}
var lessons: Array = []        # in teaching order
var books: Dictionary = {}     # id -> {title, url}: open textbooks and databases for further study


func _ready() -> void:
	minerals = _load_entries(MINERALS_PATH, "minerals")
	rocks = _load_entries(ROCKS_PATH, "rocks")
	fossils = _load_entries(FOSSILS_PATH, "fossils")
	var school: Variant = JSON.parse_string(FileAccess.get_file_as_string(LESSONS_PATH))
	lessons = school["lessons"]
	books = school["books"]
	if FileAccess.file_exists(CREDITS_PATH):
		credits = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))


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


func rock(id: String) -> Dictionary:
	return rocks.get(id, {})


func fossil(id: String) -> Dictionary:
	return fossils.get(id, {})


func lesson(id: String) -> Dictionary:
	for l in lessons:
		if l["id"] == id:
			return l
	return {}


## A mineral, rock or fossil entry, by kind ("mineral", "rock" or "fossil").
func entry(kind: String, id: String) -> Dictionary:
	if kind == "fossil":
		return fossil(id)
	return rock(id) if kind == "rock" else mineral(id)


func wiki_url(article: String) -> String:
	return "https://en.wikipedia.org/wiki/" + article.replace(" ", "_").uri_encode()


## "Learn more" links for an entry or lesson, as BBCode [url] tags. RichTextLabels that show them open
## links with open_link().
func links_bbcode(article: String, book_ids: Array) -> String:
	var links := ["[url=%s]Wikipedia: %s[/url]" % [wiki_url(article), article]]
	for b in book_ids:
		if books.has(b):
			links.append("[url=%s]%s[/url]" % [books[b]["url"], books[b]["title"]])
	return "[b]Learn more[/b]\n" + "\n".join(links)


func entry_links_bbcode(kind: String, id: String) -> String:
	var e := entry(kind, id)
	if kind != "mineral":
		return links_bbcode(e["wiki"], ["physical"])
	var name: String = e["name"]
	return links_bbcode(e["wiki"], ["mineralogy"]) + "\n[url=https://www.mindat.org/search.php?search=%s]Mindat: %s[/url]" % [
		name.uri_encode(), name]


func open_link(meta: Variant) -> void:
	OS.shell_open(str(meta))


func ids_up_to_tier(kind: String, tier: int) -> Array:
	return rock_ids_up_to_tier(tier) if kind == "rock" else mineral_ids_up_to_tier(tier)


func rock_ids_up_to_tier(tier: int) -> Array:
	var ids := []
	for id in rocks:
		if int(rocks[id]["tier"]) <= tier:
			ids.append(id)
	ids.sort()
	return ids


## BBCode for the photo of a mineral or rock, or "" when there is none.
func photo_bbcode(id: String, width := 150) -> String:
	if not credits.has(id) or not ResourceLoader.exists(credits[id]["image"]):
		return ""
	return "[img=%d]%s[/img]" % [width, credits[id]["image"]]


func photo_credit(id: String) -> String:
	if not credits.has(id):
		return ""
	var c: Dictionary = credits[id]
	return "Photo: %s, %s, via Wikimedia Commons." % [c["author"], c["license"]]


## The full lesson for a mineral, rock or fossil: photo, explanation and photo credit.
func lesson_bbcode(kind: String, id: String, photo_width := 150) -> String:
	var e := entry(kind, id)
	var parts := []
	var photo := photo_bbcode(id, photo_width)
	if photo != "":
		parts.append(photo)
	parts.append(e.get("explanation", ""))
	var credit := photo_credit(id)
	if credit != "":
		parts.append("[color=#8f8597][font_size=10]%s[/font_size][/color]" % credit)
	return "\n".join(parts)


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


## Side-by-side properties of the real answer and a wrong guess, so a miss teaches how to tell them apart.
func comparison_bbcode(kind: String, answer: String, guess: String) -> String:
	var a := entry(kind, answer)
	var g := entry(kind, guess)
	var rows := []
	if kind == "mineral":
		rows = [
			["Hardness", hardness_text(a), hardness_text(g)],
			["Streak", a["streak"], g["streak"]],
			["Luster", a["luster"], g["luster"]],
			["Density", "%s" % a["specific_gravity"], "%s" % g["specific_gravity"]],
			["Cleavage", a["cleavage"], g["cleavage"]],
			["Key test", a["diagnostic"], g["diagnostic"]],
		]
	else:
		rows = [
			["Family", a["family"], g["family"]],
			["Texture", a["texture"], g["texture"]],
			["Grain size", a["grain_size"], g["grain_size"]],
			["Key test", a["diagnostic"], g["diagnostic"]],
		]
	var out := "[b]How to tell them apart[/b]\n[table=3]"
	out += "[cell] [/cell][cell][b]%s[/b]  [/cell][cell][b]%s[/b][/cell]" % [a["name"], g["name"]]
	for r in rows:
		out += "[cell]%s  [/cell][cell]%s  [/cell][cell]%s[/cell]" % r
	return out + "[/table]"


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


# --- Rock tests. ---

func rock_texture_test(r: Dictionary) -> String:
	return "Hand lens: %s texture." % r["texture"]


func rock_grain_test(r: Dictionary) -> String:
	return "Grain size: %s." % r["grain_size"]


func rock_minerals_test(r: Dictionary) -> String:
	if r["minerals"].is_empty():
		return "Minerals: none visible, it is all glass."
	var names := []
	for id in r["minerals"]:
		names.append(mineral(id)["name"].to_lower())
	return "Minerals you can make out: %s." % ", ".join(names)


func rock_acid_test(r: Dictionary) -> String:
	# The main mineral (listed first) decides the reaction.
	if r["minerals"].is_empty():
		return "Dilute HCl: no reaction."
	if r["minerals"][0] == "dolomite":
		return "Dilute HCl: no fizz on the surface, but scraped powder fizzes slowly."
	if "calcite" in r["minerals"]:
		return "Dilute HCl: fizzes strongly, so it contains calcite."
	return "Dilute HCl: no reaction."


func taste_test(m: Dictionary) -> String:
	if m["id"] == "halite":
		return "Taste: salty."
	return "Taste: nothing. Never lick a sample you suspect is toxic, like galena!"
