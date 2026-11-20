extends Node
## Levels, player progress, power-up inventory and events
## (daily reward, daily missions, star chest). Saved to user://save.json.

signal inventory_changed

const LEVELS_PATH := "res://data/levels.json"
const SAVE_PATH := "user://save.json"

# --- Power-ups ---------------------------------------------------------------
## "tube": +1 empty tube in a level.  "undo": +3 undos in a level.
const ITEMS := ["tube", "undo"]
const START_INVENTORY := {"tube": 1, "undo": 1}

# --- Events ------------------------------------------------------------------
## 7-day login calendar. Missing a day restarts at day 1.
const DAILY_REWARDS := [
	{"undo": 1},
	{"tube": 1},
	{"undo": 2},
	{"tube": 1},
	{"undo": 3},
	{"tube": 2},
	{"tube": 2, "undo": 3},
]
## Daily missions, reset every day.
const MISSIONS := [
	{"id": "win", "goal": 3, "reward": {"tube": 1}},
	{"id": "stars", "goal": 7, "reward": {"undo": 2}},
	{"id": "perfect", "goal": 1, "reward": {"tube": 1}},
]
const CHEST_STARS := 15
const CHEST_REWARD := {"tube": 1, "undo": 2}

var capacity: int = 4
var levels: Array = []
var data: Dictionary = {}
## Tests can force the date ("YYYY-MM-DD").
var debug_today := ""


func _ready() -> void:
	_load_levels()
	data = _default_data()
	load_save()


func _default_data() -> Dictionary:
	return {
		"stars": {},      # "level_index" -> best stars (1..3)
		"no_ads": false,  # "Remove ads" purchase
		"locale": "",     # "" = device language
		"inventory": START_INVENTORY.duplicate(),
		"daily": {"last_claim": "", "streak": 0},
		"missions": {"date": "", "progress": {}, "claimed": []},
		"chests_claimed": 0,
	}


func _load_levels() -> void:
	var text := FileAccess.get_file_as_string(LEVELS_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cannot read %s" % LEVELS_PATH)
		return
	capacity = int(parsed.get("capacity", 4))
	levels = parsed.get("levels", [])


# ============================================================ levels & stars

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


## Called on every win (feeds the daily missions).
func on_level_won(stars: int, used_undo: bool) -> void:
	_ensure_missions_today()
	var p: Dictionary = data["missions"]["progress"]
	p["win"] = int(p.get("win", 0)) + 1
	p["stars"] = int(p.get("stars", 0)) + stars
	if stars == 3 and not used_undo:
		p["perfect"] = int(p.get("perfect", 0)) + 1
	save()


# ============================================================ inventory

func item_count(item: String) -> int:
	return int(data["inventory"].get(item, 0))


func use_item(item: String) -> bool:
	if item_count(item) <= 0:
		return false
	data["inventory"][item] = item_count(item) - 1
	save()
	inventory_changed.emit()
	return true


func add_rewards(reward: Dictionary) -> void:
	for item in reward:
		data["inventory"][item] = item_count(item) + int(reward[item])
	save()
	inventory_changed.emit()


# ============================================================ dates

func today() -> String:
	return debug_today if debug_today != "" else Time.get_date_string_from_system()


func _day_before(date: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)


# ============================================================ daily reward

## {"claimable": bool, "index": day to claim (or last claimed) 0..6,
##  "claimed_upto": number of days already claimed in the current cycle}
func daily_state() -> Dictionary:
	var d: Dictionary = data["daily"]
	var last: String = d.get("last_claim", "")
	var streak: int = int(d.get("streak", 0))
	if last == today():
		var idx := (streak - 1) % DAILY_REWARDS.size()
		return {"claimable": false, "index": idx, "claimed_upto": idx + 1}
	var continues := last != "" and last == _day_before(today())
	var next := streak % DAILY_REWARDS.size() if continues else 0
	return {"claimable": true, "index": next, "claimed_upto": next}


func claim_daily() -> Dictionary:
	var st := daily_state()
	if not st["claimable"]:
		return {}
	var d: Dictionary = data["daily"]
	var last: String = d.get("last_claim", "")
	var continues := last != "" and last == _day_before(today())
	d["streak"] = int(d.get("streak", 0)) + 1 if continues else 1
	d["last_claim"] = today()
	var reward: Dictionary = DAILY_REWARDS[st["index"]]
	add_rewards(reward)
	return reward


# ============================================================ missions

func _ensure_missions_today() -> void:
	var m: Dictionary = data["missions"]
	if m.get("date", "") != today():
		data["missions"] = {"date": today(), "progress": {}, "claimed": []}


## {"progress": int, "goal": int, "done": bool, "claimed": bool, "reward": Dictionary}
func mission_status(i: int) -> Dictionary:
	_ensure_missions_today()
	var def: Dictionary = MISSIONS[i]
	var m: Dictionary = data["missions"]
	var prog := mini(int(m["progress"].get(def["id"], 0)), int(def["goal"]))
	return {
		"id": def["id"],
		"progress": prog,
		"goal": int(def["goal"]),
		"done": prog >= int(def["goal"]),
		"claimed": def["id"] in m["claimed"],
		"reward": def["reward"],
	}


func claim_mission(i: int) -> Dictionary:
	var st := mission_status(i)
	if not st["done"] or st["claimed"]:
		return {}
	data["missions"]["claimed"].append(st["id"])
	add_rewards(st["reward"])
	return st["reward"]


# ============================================================ star chest

func chests_available() -> int:
	return maxi(total_stars() / CHEST_STARS - int(data["chests_claimed"]), 0)


## Stars collected towards the next chest (0..CHEST_STARS).
func chest_progress() -> int:
	if chests_available() > 0:
		return CHEST_STARS
	return total_stars() - int(data["chests_claimed"]) * CHEST_STARS


func claim_chest() -> Dictionary:
	if chests_available() <= 0:
		return {}
	data["chests_claimed"] = int(data["chests_claimed"]) + 1
	add_rewards(CHEST_REWARD)
	return CHEST_REWARD


## True if something can be claimed in the Events screen (menu badge).
func has_claimable() -> bool:
	if daily_state()["claimable"] or chests_available() > 0:
		return true
	for i in MISSIONS.size():
		var st := mission_status(i)
		if st["done"] and not st["claimed"]:
			return true
	return false


# ============================================================ misc

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


## Wipes everything (used by tests).
func reset_all() -> void:
	data = _default_data()
	save()


func reset_progress() -> void:
	data["stars"] = {}
	save()
