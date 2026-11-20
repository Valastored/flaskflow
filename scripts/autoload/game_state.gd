extends Node
## Levels + player progress (saved to user://save.json).

const LEVELS_PATH := "res://data/levels.json"
const SAVE_PATH := "user://save.json"

var capacity: int = 4
var levels: Array = []
var data: Dictionary = {
	"stars": {},      # "level_index" -> best stars (1..3)
	"no_ads": false,  # set by the "Remove ads" purchase
	"locale": "",     # "" = follow the device language
}


func _ready() -> void:
	_load_levels()
	load_save()


func _load_levels() -> void:
	var text := FileAccess.get_file_as_string(LEVELS_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cannot read %s" % LEVELS_PATH)
		return
	capacity = int(parsed.get("capacity", 4))
	levels = parsed.get("levels", [])


func level_count() -> int:
	return levels.size()


func get_level(i: int) -> Dictionary:
	return levels[i]


func stars_for(i: int) -> int:
	return int(data["stars"].get(str(i), 0))


func is_unlocked(i: int) -> bool:
	return i == 0 or stars_for(i - 1) > 0


func total_stars() -> int:
	var n := 0
	for v in data["stars"].values():
		n += int(v)
	return n


func first_unsolved() -> int:
	for i in level_count():
		if stars_for(i) == 0:
			return i
	return level_count() - 1


func record_result(i: int, stars: int) -> void:
	if stars > stars_for(i):
		data["stars"][str(i)] = stars
		save()


func no_ads() -> bool:
	return bool(data["no_ads"])


func set_no_ads(value: bool) -> void:
	data["no_ads"] = value
	save()


func set_locale(locale: String) -> void:
	data["locale"] = locale
	save()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed:
			data[k] = parsed[k]


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func reset_progress() -> void:
	data["stars"] = {}
	save()
