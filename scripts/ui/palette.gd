class_name Palette
extends RefCounted
## Minimal, vivid colour set. Index = colour id in levels.json.

const LIQUIDS: Array[Color] = [
	Color("#ff4d6d"),  # 0 red
	Color("#ffd60a"),  # 1 yellow
	Color("#3a86ff"),  # 2 blue
	Color("#06d6a0"),  # 3 mint
	Color("#8338ec"),  # 4 purple
	Color("#ff9f1c"),  # 5 orange
	Color("#ff70a6"),  # 6 pink
	Color("#70e000"),  # 7 lime
	Color("#00bbf9"),  # 8 cyan
	Color("#f1faee"),  # 9 white
	Color("#a0522d"),  # 10 brown
	Color("#5e548e"),  # 11 slate
]

const BG_TOP := Color("#1b1f3b")
const BG_BOTTOM := Color("#43206b")
const ACCENT := Color("#ffd60a")
const PANEL := Color(1, 1, 1, 0.08)
const TEXT := Color("#f8f9ff")
const TEXT_DIM := Color(1, 1, 1, 0.55)


static func liquid(id: int) -> Color:
	return LIQUIDS[id % LIQUIDS.size()]
