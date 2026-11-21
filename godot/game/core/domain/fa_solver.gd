class_name FaSolver
extends RefCounted
## 해법 탐색기. 한 묶음의 4장이 모두 보이면 항상 먼저 묶는다고 보고 임시 칸 이동만 분기한다.
## 묶은 뒤의 상태는 열마다 남은 장수만으로 정해지므로 그 값을 열쇠로 결과를 기억한다.
## 결과는 {solvable, min_holds, forgiveness, next_hold}다.
##   min_holds: 끝내는 데 필요한 최소 임시 칸 이동 수. 풀 수 없으면 -1.
##   forgiveness: 임시 칸에 넣을 열을 균등 무작위로 고를 때 끝까지 풀리는 확률(관대함).
##   next_hold: 최소 이동 해법의 첫 이동 열. 옮길 필요가 없거나 풀 수 없으면 -1.

const Self := preload("res://game/core/domain/fa_solver.gd")
const Board := preload("res://game/core/domain/fa_board.gd")

const GROUP_SIZE := Board.GROUP_SIZE
const UNSOLVABLE := -1

var _cols: Array[PackedInt32Array] = []
var _loose: Array[int] = []
var _held_start: Array[int] = []
var _total: Array[int] = []
var _slots: int = 0
var _radix: int = 1
var _held: int = 0
var _left: int = 0
var _holds_memo: Dictionary = {}
var _chance_memo: Dictionary = {}


## 묶음 번호(0 이상의 정수)로 나타낸 배치를 분석한다. 각 열은 뒤에서 앞 순서다.
static func solve(cols: Array, reserve: Array, held: Array, slots: int) -> Dictionary:
	var solver: Self = new()
	return solver._analyze(cols, reserve, held, slots)


## 진행 중인 판을 임시 칸 slots개 기준으로 분석한다. 칸을 추가했을 때를 미리 보려면 slots를 더 크게 준다.
static func solve_board(board: Board, slots: int) -> Dictionary:
	var group_of: Dictionary = {}
	var categories: Array[String] = board.categories()
	for index: int in categories.size():
		group_of[categories[index]] = index
	var to_groups: Callable = func(cards: Array[String]) -> Array:
		var groups: Array = []
		for card: String in cards:
			if not card.is_empty():
				groups.append(group_of[board.category_of(card)])
		return groups
	var cols: Array = []
	for column: int in board.column_count():
		cols.append(to_groups.call(board.column_cards(column)))
	return solve(cols, to_groups.call(board.reserve()), to_groups.call(board.holds()), slots)


func _analyze(cols: Array, reserve: Array, held: Array, slots: int) -> Dictionary:
	_slots = slots
	var group_count: int = 0
	for cards: Array in cols + [reserve, held]:
		for group: int in cards:
			group_count = maxi(group_count, group + 1)
	for counts: Array[int] in [_total, _loose, _held_start]:
		counts.resize(group_count)
		counts.fill(0)
	var depths: Array[int] = []
	for column: Array in cols:
		_cols.append(PackedInt32Array(column))
		depths.append(column.size())
		_radix = maxi(_radix, column.size() + 1)
		for group: int in column:
			_total[group] += 1
	for group: int in reserve:
		_total[group] += 1
		_loose[group] += 1
	for group: int in held:
		_total[group] += 1
		_loose[group] += 1
		_held_start[group] += 1

	var key: int = _best(depths)
	var min_holds: int = _holds_memo[key]
	var next_hold: int = -1
	if min_holds > 0:
		_settle(depths)
		for column: int in depths.size():
			if depths[column] == 0:
				continue
			depths[column] -= 1
			var child: int = _best(depths)
			depths[column] += 1
			if _holds_memo[child] == min_holds - 1:
				next_hold = column
				break
	return {
		"solvable": min_holds != UNSOLVABLE, "min_holds": min_holds,
		"forgiveness": _chance_memo[key], "next_hold": next_hold,
	}


## 열마다 남은 장수로 나타낸 상태의 결과를 구해 기억하고 그 열쇠를 돌려준다.
func _best(depths: Array[int]) -> int:
	var key: int = _key(depths)
	if _holds_memo.has(key):
		return key
	var settled: Array[int] = depths.duplicate()
	_settle(settled)
	var settled_key: int = _key(settled)
	if not _holds_memo.has(settled_key):
		var min_holds: int = UNSOLVABLE
		var chance: float = 0.0
		if _left == 0:
			min_holds = 0
			chance = 1.0
		elif _held < _slots:
			var moves: int = 0
			for column: int in settled.size():
				if settled[column] == 0:
					continue
				settled[column] -= 1
				var child: int = _best(settled)
				settled[column] += 1
				moves += 1
				chance += _chance_memo[child]
				var child_holds: int = _holds_memo[child]
				if child_holds != UNSOLVABLE and (min_holds == UNSOLVABLE or child_holds + 1 < min_holds):
					min_holds = child_holds + 1
			if moves > 0:
				chance /= moves
		_holds_memo[settled_key] = min_holds
		_chance_memo[settled_key] = chance
	_holds_memo[key] = _holds_memo[settled_key]
	_chance_memo[key] = _chance_memo[settled_key]
	return key


func _key(depths: Array[int]) -> int:
	var key: int = 0
	for depth: int in depths:
		key = key * _radix + depth
	return key


## 보이는 묶음을 더 없을 때까지 묶어 depths를 고치고, 임시 칸의 카드 수(_held)와 남은 카드 수(_left)를 센다.
## 열에서 빠진 카드는 묶여 사라졌거나 임시 칸에 있고, 어느 쪽이든 그 묶음의 보이는 카드로 센다.
func _settle(depths: Array[int]) -> void:
	var visible: Array[int] = []
	var changed: bool = true
	while changed:
		changed = false
		visible = _loose.duplicate()
		for column: int in depths.size():
			for index: int in range(maxi(depths[column] - 1, 0), _cols[column].size()):
				visible[_cols[column][index]] += 1
		for column: int in depths.size():
			if depths[column] > 0 and visible[_cols[column][depths[column] - 1]] == GROUP_SIZE:
				depths[column] -= 1
				changed = true
	_left = 0
	_held = 0
	for group: int in _total.size():
		if visible[group] != GROUP_SIZE:
			_left += _total[group]
			_held += _held_start[group]
	for column: int in depths.size():
		for index: int in range(depths[column], _cols[column].size()):
			if visible[_cols[column][index]] != GROUP_SIZE:
				_held += 1
