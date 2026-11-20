class_name Palette
extends RefCounted
## Liquid colours. Index = colour id in levels.json (levels use ids 0..8).
## Chosen to stay distinct on small screens: different hue AND brightness
## (no blue/cyan or red/pink pairs of similar lightness).

const LIQUIDS: Array[Color] = [
	Color("#e63946"),  # 0 red
	Color("#ffd23f"),  # 1 yellow
	Color("#2d6cdf"),  # 2 blue
	Color("#2ec4b6"),  # 3 teal
	Color("#8e44ec"),  # 4 purple
	Color("#ff8c1a"),  # 5 orange
	Color("#ffb3d1"),  # 6 light pink (pastel, far from red)
	Color("#7ed957"),  # 7 lime
	Color("#f4f4f8"),  # 8 white
	Color("#8b5a3c"),  # 9 brown
	Color("#4a4e69"),  # 10 slate
	Color("#0b3d91"),  # 11 navy
]

const BG_TOP := Color("#1b1f3b")
const BG_BOTTOM := Color("#43206b")
const ACCENT := Color("#ffd23f")
const GOOD := Color("#7ed957")
const BAD := Color("#ff5a6e")
const PANEL := Color(1, 1, 1, 0.08)
const TEXT := Color("#f8f9ff")
const TEXT_DIM := Color(1, 1, 1, 0.55)


static func liquid(id: int) -> Color:
	return LIQUIDS[id % LIQUIDS.size()]
