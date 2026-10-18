extends RefCounted
## The interface look: a rounded, high-legibility theme sized for phones, an optional high-contrast palette,
## and small pixel-art icons drawn from text maps so there are no image files.

## Base font size for each text size setting (Small, Normal, Large, Huge).
const FONT_SIZES := [13, 15, 18, 21]
const TEXT_SIZE_NAMES := ["Small", "Normal", "Large", "Huge"]
## Smallest height of anything you tap, in screen units (the screen is 360 units tall).
const TAP := 44

const NORMAL := {
	"bg": Color("1d1824"), "card": Color("2b2335"), "border": Color("5b4a6b"), "text": Color("f3ecf7"),
	"muted": Color("b9aec4"), "accent": Color("f2c230"), "accent_text": Color("1d1824"), "button": Color("3b3047"),
	"button_hover": Color("4a3d59"), "good": Color("6fd38a"), "bad": Color("ff8a7a"), "coin": Color("f7d64a"),
	"xp": Color("8fd3ff"), "hud": Color(0.08, 0.06, 0.1, 0.86), "bar_bg": Color("15111a"), "track": Color("4a3d59"),
}
const CONTRAST := {
	"bg": Color("000000"), "card": Color("000000"), "border": Color("ffffff"), "text": Color("ffffff"),
	"muted": Color("e6e6e6"), "accent": Color("ffd400"), "accent_text": Color("000000"), "button": Color("151515"),
	"button_hover": Color("2c2c2c"), "good": Color("44ff99"), "bad": Color("ff7070"), "coin": Color("ffe14d"),
	"xp": Color("7fdcff"), "hud": Color(0, 0, 0, 0.94), "bar_bg": Color("000000"), "track": Color("000000"),
}

## 12 x 12 icon maps. Letters are colors from ICON_PALETTE, dots are transparent.
const ICONS := {
	"bag": [
		"....dddd....", ".....cc.....", "....dccd....", "...dbbbbd...", "..dbbbbbbd..", ".dbbbbbbbbd.",
		".dbbbllbbbd.", ".dbbbllbbbd.", ".dbbbbbbbbd.", ".dbbbbbbbbd.", "..dbbbbbbd..", "...dddddd...",
	],
	"codex": [
		"............", ".ddd....ddd.", "dwwwd..dwwwd", "dwkwwddwwkwd", "dwwwwddwwwwd", "dwkkwddwkkwd",
		"dwwwwddwwwwd", "dwkkwddwkkwd", "dwwwwddwwwwd", "ddddwddwdddd", "....dddd....", "............",
	],
	"anvil": [
		"............", "............", "dddddddddd..", "dggggggggdd.", "dgggggggggdd", ".dggggggggd.",
		"...dggggd...", "....dggd....", "...dggggd...", "..dggggggd..", "..dddddddd..", "............",
	],
	"brick": [
		"............", "dddddddddddd", "mmmmmdmmmmmd", "mmmmmdmmmmmd", "dddddddddddd", "mmdmmmmmdmmm",
		"mmdmmmmmdmmm", "dddddddddddd", "mmmmmdmmmmmd", "mmmmmdmmmmmd", "dddddddddddd", "............",
	],
	"rope": [
		".....ww.....", "....wwww....", "...wwwwww...", "..ww.yy.ww..", ".....yy.....", "....yy......",
		".....yy.....", "......yy....", ".....yy.....", "....yy......", ".....yy.....", "......yy....",
	],
	"gear": [
		".....gg.....", "..g.gggg.g..", ".gggggggggg.", "..gggddggg..", ".gggd..dggg.", "gggd....dggg",
		"gggd....dggg", ".gggd..dggg.", "..gggddggg..", ".gggggggggg.", "..g.gggg.g..", ".....gg.....",
	],
	"star": [
		".....yy.....", ".....yy.....", "....yyyy....", "yyyyyyyyyyyy", ".yyyyyyyyyy.", "..yyyyyyyy..",
		"...yyyyyy...", "...yyyyyy...", "..yyy..yyy..", "..yy....yy..", ".yy......yy.", "............",
	],
	"flame": [
		".....r......", "....rr......", "....rrr.....", "...rrrr..r..", "..rrrrrr.r..", "..rrroorrr..",
		".rrrooorrrr.", ".rrooyyoorr.", ".rrooyyyorr.", ".rrooyyyorr.", "..rrooyoor..", "...rrrrrr...",
	],
	"depth": [
		".....uu.....", ".....uu.....", ".....uu.....", ".....uu.....", ".....uu.....", "..u..uu..u..",
		"..uu.uu.uu..", "...uuuuuu...", "....uuuu....", ".....uu.....", "bbbbbbbbbbbb", "dddddddddddd",
	],
	"pick": [
		"..gggggggg..", ".gg..bb..gg.", "gg...bb...gg", "g....bb....g", ".....bb.....", ".....bb.....",
		".....bb.....", ".....bb.....", ".....bb.....", ".....bb.....", ".....bb.....", "............",
	],
	"lamp": [
		"............", "....cccc....", "...cllllc...", "..cllllllc..", "..cllllllc..", "..cllllllc..",
		"...cllllc...", "....dccd....", "....dggd....", "....dggd....", ".....dd.....", "............",
	],
	"check": [
		"............", "..........ee", ".........ee.", "........eee.", ".......eee..", "ee....eee...",
		"eee..eee....", ".eeeeee.....", "..eeee......", "...ee.......", "............", "............",
	],
	"cross": [
		"rr........rr", "rrr......rrr", ".rrr....rrr.", "..rrr..rrr..", "...rrrrrr...", "....rrrr....",
		"....rrrr....", "...rrrrrr...", "..rrr..rrr..", ".rrr....rrr.", "rrr......rrr", "rr........rr",
	],
	"back": [
		"............", "............", "....w.......", "...ww.......", "..wwwwwwwww.", ".wwwwwwwwww.",
		"..wwwwwwwww.", "...ww.......", "....w.......", "............", "............", "............",
	],
	"close": [
		"............", ".ww......ww.", ".www....www.", "..www..www..", "...wwwwww...", "....wwww....",
		"....wwww....", "...wwwwww...", "..www..www..", ".www....www.", ".ww......ww.", "............",
	],
	"flask": [
		"....wwww....", ".....gg.....", ".....gg.....", ".....gg.....", "....gggg....", "...g.uu.g...",
		"..g.uuuu.g..", ".g.uuuuuu.g.", ".guuuuuuuug.", ".guuuuuuuug.", "..gggggggg..", "............",
	],
	"gift": [
		"...rr..rr...", "....rrrr....", "rrrrrrrrrrrr", "ccccrrrrcccc", "ccccrrrrcccc", "............",
		".cccrrrrccc.", ".cccrrrrccc.", ".cccrrrrccc.", ".cccrrrrccc.", ".cccrrrrccc.", "............",
	],
	"hand": [
		"....ww......", "....ww......", "....ww......", "....wwww....", "....wwwwww..", "ww..wwwwwww.",
		"www.wwwwwww.", ".wwwwwwwwww.", "..wwwwwwwww.", "..wwwwwwww..", "...wwwwww...", "...wwwwww...",
	],
}
const ICON_PALETTE := {
	"d": Color("1a1420"), "c": Color("f2c230"), "l": Color("fff3b0"), "b": Color("8a5a32"), "g": Color("b8bcc4"),
	"w": Color("f3ecf7"), "k": Color("7a6a8a"), "r": Color("e2553f"), "o": Color("f39a2e"), "y": Color("f7d64a"),
	"u": Color("6db3e0"), "e": Color("6fd38a"), "m": Color("b5523b"),
}

static var _icons := {}


## The current palette, following the high-contrast setting.
static func colors() -> Dictionary:
	return CONTRAST if GameState.settings["contrast"] else NORMAL


static func font_size() -> int:
	return FONT_SIZES[clampi(int(GameState.settings["text_size"]), 0, FONT_SIZES.size() - 1)]


static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	if name == "coin" or name == "goal":
		_draw_round_icon(img, name)
	else:
		var rows: Array = ICONS[name]
		for y in rows.size():
			for x in rows[y].length():
				img.set_pixel(x, y, ICON_PALETTE.get(rows[y][x], Color(0, 0, 0, 0)))
	var tex := ImageTexture.create_from_image(img)
	_icons[name] = tex
	return tex


static func _draw_round_icon(img: Image, name: String) -> void:
	for y in 12:
		for x in 12:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(6, 6))
			var c := Color(0, 0, 0, 0)
			if name == "coin":
				if d <= 6.0:
					c = Color("8a6510") if d > 4.9 else Color("f2c230")
				if d > 2.0 and d < 3.4 and x < 6 and y < 6:
					c = Color("fff3b0")
			else:
				if d <= 6.0:
					c = [Color("e2553f"), Color("f3ecf7")][int(d / 1.6) % 2]
			img.set_pixel(x, y, c)


static func flat(bg: Color, radius := 8, margin := 8, border := Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.anti_aliasing = false
	return sb


static func make() -> Theme:
	var c := colors()
	var contrast: bool = GameState.settings["contrast"]
	var fs := font_size()
	var bw := 2 if contrast else 1
	var t := Theme.new()
	t.default_font_size = fs

	t.set_stylebox("panel", "PanelContainer", flat(Color(c["bg"], 0.97), 10, 10, c["border"], 2))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", flat(c["card"], 8, 8, c["border"], bw))
	t.set_type_variation("HudCard", "PanelContainer")
	t.set_stylebox("panel", "HudCard", flat(c["hud"], 8, 6, c["border"] if contrast else Color(0, 0, 0, 0), bw if contrast else 0))
	t.set_type_variation("GoodBanner", "PanelContainer")
	t.set_stylebox("panel", "GoodBanner", flat(Color(c["good"], 0.22), 8, 8, c["good"], 2))
	t.set_type_variation("BadBanner", "PanelContainer")
	t.set_stylebox("panel", "BadBanner", flat(Color(c["bad"], 0.22), 8, 8, c["bad"], 2))

	t.set_color("font_color", "Label", c["text"])
	t.set_type_variation("Title", "Label")
	t.set_color("font_color", "Title", c["accent"])
	t.set_font_size("font_size", "Title", fs + 4)
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", c["muted"])
	t.set_font_size("font_size", "Muted", fs - 2)
	t.set_type_variation("Small", "Label")
	t.set_font_size("font_size", "Small", fs - 2)
	t.set_type_variation("HudLabel", "Label")
	t.set_color("font_outline_color", "HudLabel", Color.BLACK)
	t.set_constant("outline_size", "HudLabel", 4)

	var states := {"normal": c["button"], "hover": c["button_hover"], "pressed": c["accent"],
		"disabled": Color(c["button"], 0.45), "focus": Color(0, 0, 0, 0)}
	for state in states:
		var sb := flat(states[state], 8, 8, c["border"], 0 if state == "focus" else bw)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", c["text"])
	t.set_color("font_hover_color", "Button", c["text"])
	t.set_color("font_focus_color", "Button", c["text"])
	t.set_color("font_pressed_color", "Button", c["accent_text"])
	t.set_color("font_hover_pressed_color", "Button", c["accent_text"])
	t.set_color("font_disabled_color", "Button", Color(c["text"], 0.45))
	t.set_constant("h_separation", "Button", 6)
	t.set_constant("icon_max_width", "Button", 24)
	t.set_type_variation("Accent", "Button")
	for state in ["normal", "hover"]:
		var sb := flat(c["accent"] if state == "normal" else c["accent"].lightened(0.15), 8, 8, c["border"], bw)
		t.set_stylebox(state, "Accent", sb)
	t.set_color("font_color", "Accent", c["accent_text"])
	t.set_color("font_hover_color", "Accent", c["accent_text"])
	t.set_color("font_focus_color", "Accent", c["accent_text"])
	t.set_type_variation("HudButton", "Button")
	for state in ["normal", "hover"]:
		t.set_stylebox(state, "HudButton", flat(c["hud"] if state == "normal" else Color(c["button_hover"], 0.9), 10, 4,
			c["border"], bw))
	t.set_font_size("font_size", "HudButton", maxi(fs - 3, 11))
	t.set_color("font_outline_color", "HudButton", Color.BLACK)
	t.set_constant("outline_size", "HudButton", 3)
	t.set_constant("icon_max_width", "HudButton", 28)

	t.set_stylebox("background", "ProgressBar", flat(c["track"], 4, 0, c["border"], 1 if contrast else 0))
	t.set_stylebox("fill", "ProgressBar", flat(c["accent"], 4, 0))
	t.set_type_variation("XpBar", "ProgressBar")
	t.set_stylebox("fill", "XpBar", flat(c["xp"], 4, 0))
	t.set_type_variation("GoodBar", "ProgressBar")
	t.set_stylebox("fill", "GoodBar", flat(c["good"], 4, 0))

	var well := flat(c["bar_bg"], 8, 8, c["border"] if contrast else Color(0, 0, 0, 0), bw if contrast else 0)
	t.set_stylebox("normal", "RichTextLabel", well)
	t.set_color("default_color", "RichTextLabel", c["text"])
	t.set_stylebox("panel", "ItemList", well)
	t.set_stylebox("selected", "ItemList", flat(c["button_hover"], 6, 4))
	t.set_stylebox("selected_focus", "ItemList", flat(c["button_hover"], 6, 4, c["accent"], 1))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_constant("v_separation", "ItemList", 12)
	t.set_color("font_color", "ItemList", c["text"])
	t.set_color("font_selected_color", "ItemList", c["accent"])

	# Wide scroll bars that are easy to grab with a thumb.
	for bar in ["VScrollBar", "HScrollBar"]:
		var track := flat(Color(c["bar_bg"], 0.6), 4, 4)
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("grabber", bar, flat(c["border"], 4, 4))
		t.set_stylebox("grabber_highlight", bar, flat(c["muted"], 4, 4))
		t.set_stylebox("grabber_pressed", bar, flat(c["accent"], 4, 4))
	return t
