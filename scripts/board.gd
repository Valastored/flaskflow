class_name Board
extends RefCounted
## Pure game logic for the water-sort puzzle (no rendering).
## Each tube is an Array of color ids, index 0 = bottom.

var capacity: int = 4
var tubes: Array = []
var moves: int = 0
var _history: Array = []


func _init(p_tubes: Array = [], p_capacity: int = 4) -> void:
	capacity = p_capacity
	tubes = []
	for t in p_tubes:
		var tube: Array = []
		for c in t:
			tube.append(int(c))
		tubes.append(tube)


func tube_count() -> int:
	return tubes.size()


func top_color(i: int) -> int:
	var t: Array = tubes[i]
	return -1 if t.is_empty() else int(t[-1])


## Number of layers of the same color on top of tube i.
func top_run(i: int) -> int:
	var t: Array = tubes[i]
	if t.is_empty():
		return 0
	var c: int = t[-1]
	var n := 0
	for k in range(t.size() - 1, -1, -1):
		if t[k] != c:
			break
		n += 1
	return n


func is_tube_complete(i: int) -> bool:
	var t: Array = tubes[i]
	if t.size() != capacity:
		return false
	for c in t:
		if c != t[0]:
			return false
	return true


func can_pour(from: int, to: int) -> bool:
	if from == to or from < 0 or to < 0:
		return false
	var a: Array = tubes[from]
	var b: Array = tubes[to]
	if a.is_empty() or b.size() >= capacity:
		return false
	if is_tube_complete(from):
		return false
	return b.is_empty() or b[-1] == a[-1]


## Pours from -> to. Returns the number of layers moved (0 if illegal).
func pour(from: int, to: int) -> int:
	if not can_pour(from, to):
		return 0
	var a: Array = tubes[from]
	var b: Array = tubes[to]
	var k: int = mini(top_run(from), capacity - b.size())
	_history.append(_snapshot())
	for n in k:
		b.append(a.pop_back())
	moves += 1
	return k


func can_undo() -> bool:
	return not _history.is_empty()


func undo() -> bool:
	if _history.is_empty():
		return false
	tubes = _history.pop_back()
	moves -= 1
	return true


func is_solved() -> bool:
	for i in tubes.size():
		var t: Array = tubes[i]
		if not t.is_empty() and not is_tube_complete(i):
			return false
	return true


## True if at least one move changes something useful.
func has_any_move() -> bool:
	for i in tubes.size():
		for j in tubes.size():
			if can_pour(i, j):
				# Pouring a single-colour tube into an empty one changes nothing.
				if tubes[j].is_empty() and top_run(i) == tubes[i].size():
					continue
				return true
	return false


## Booster: adds an empty tube. Also added to the undo history so that
## undoing never removes it.
func add_empty_tube() -> void:
	tubes.append([])
	for snap in _history:
		snap.append([])


func _snapshot() -> Array:
	var copy: Array = []
	for t in tubes:
		copy.append(t.duplicate())
	return copy
