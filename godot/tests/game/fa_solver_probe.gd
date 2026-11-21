extends SceneTree
## 해법 탐색기 검사: 참고용 Python 탐색기로 구한 기대값과 비교하고, 풀린다고 한 판을 next_hold로 끝까지 따라간다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Random := preload("res://game/core/domain/fa_random.gd")

## python3 tools/levels/solver_fixtures.py 출력. 카드는 묶음 번호이고 min_holds -1은 풀 수 없음이다.
const FIXTURES: Array[Dictionary] = [
	{"cols": [[1, 0], [2, 1], [2, 0], [2, 0]], "reserve": [1, 1, 0, 2], "held": [], "slots": 2, "min_holds": 0, "forgiveness": 1.0, "next_hold": -1},
	{"cols": [[2, 0], [0, 0], [1, 1], [2, 1]], "reserve": [2, 2, 0, 1], "held": [], "slots": 2, "min_holds": 2, "forgiveness": 0.75, "next_hold": 1},
	{"cols": [[0, 1], [1, 2], [2, 2], [0, 0]], "reserve": [1, 2, 1, 0], "held": [], "slots": 2, "min_holds": 2, "forgiveness": 0.7708333333333333, "next_hold": 2},
	{"cols": [[2, 0], [1, 1], [2, 1], [0, 0]], "reserve": [0, 1, 2, 2], "held": [], "slots": 2, "min_holds": 2, "forgiveness": 0.75, "next_hold": 1},
	{"cols": [[3, 1], [0, 0], [3, 2], [0, 0]], "reserve": [1, 3, 1, 2, 2, 3, 1, 2], "held": [], "slots": 2, "min_holds": 2, "forgiveness": 0.5, "next_hold": 1},
	{"cols": [[1, 2], [2, 0], [1, 0], [0, 3]], "reserve": [1, 2, 3, 2, 0, 3, 1, 3], "held": [], "slots": 2, "min_holds": 0, "forgiveness": 1.0, "next_hold": -1},
	{"cols": [[3, 0], [2, 3], [0, 2], [2, 1]], "reserve": [3, 1, 2, 0, 3, 0, 1, 1], "held": [], "slots": 2, "min_holds": 1, "forgiveness": 1.0, "next_hold": 0},
	{"cols": [[1, 3], [3, 2], [0, 0], [0, 1]], "reserve": [2, 0, 2, 3, 2, 3, 1, 1], "held": [], "slots": 2, "min_holds": 1, "forgiveness": 1.0, "next_hold": 2},
	{"cols": [[1, 2, 0], [1, 3, 1], [0, 3], [3, 0]], "reserve": [2, 1, 3, 2, 0, 2], "held": [], "slots": 2, "min_holds": 2, "forgiveness": 0.3125, "next_hold": 1},
	{"cols": [[1, 0, 2], [3, 0, 0], [1, 0], [3, 1]], "reserve": [2, 3, 2, 1, 2, 3], "held": [], "slots": 2, "min_holds": 1, "forgiveness": 0.4375, "next_hold": 1},
	{"cols": [[1, 0, 1], [1, 1, 3], [3, 2], [3, 3]], "reserve": [2, 2, 0, 0, 2, 0], "held": [], "slots": 2, "min_holds": 3, "forgiveness": 0.22916666666666666, "next_hold": 0},
	{"cols": [[0, 2, 1], [0, 1, 1], [3, 3], [2, 0]], "reserve": [2, 0, 3, 1, 3, 2], "held": [], "slots": 2, "min_holds": 3, "forgiveness": 0.5555555555555556, "next_hold": 1},
	{"cols": [[3, 2, 0], [0, 3, 2], [1, 0, 3], [1, 2, 0]], "reserve": [3, 1, 2, 1], "held": [], "slots": 2, "min_holds": 2, "forgiveness": 0.125, "next_hold": 0},
	{"cols": [[2, 3, 0], [0, 2, 2], [0, 2, 1], [3, 3, 1]], "reserve": [0, 1, 3, 1], "held": [], "slots": 2, "min_holds": 3, "forgiveness": 0.041666666666666664, "next_hold": 0},
	{"cols": [[0, 0, 3], [3, 1, 0], [2, 0, 1], [1, 2, 2]], "reserve": [1, 3, 2, 3], "held": [], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[3, 3, 1], [2, 0, 3], [0, 1, 0], [1, 2, 1]], "reserve": [2, 3, 2, 0], "held": [], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[1, 1, 3, 2], [3, 2, 0], [0, 3, 1], [2, 2]], "reserve": [0, 3, 1, 0], "held": [], "slots": 2, "min_holds": 4, "forgiveness": 0.041666666666666664, "next_hold": 1},
	{"cols": [[3, 0, 2, 3], [1, 2, 0], [0, 1, 1], [2, 3]], "reserve": [1, 3, 0, 2], "held": [], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[0, 2, 0, 2], [0, 3, 3], [3, 1, 1], [1, 2]], "reserve": [0, 3, 2, 1], "held": [], "slots": 2, "min_holds": 4, "forgiveness": 0.005208333333333333, "next_hold": 0},
	{"cols": [[3, 0, 1, 2], [0, 2, 0], [1, 1, 3], [2, 0]], "reserve": [3, 1, 3, 2], "held": [], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[0, 1, 3, 2], [2, 3, 2], [2, 1, 3], [1, 0]], "reserve": [1, 0, 0, 3], "held": [], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[0, 1, 3, 2], [2, 3, 2], [2, 1, 3], [1, 0]], "reserve": [1, 0, 0, 3], "held": [], "slots": 3, "min_holds": 3, "forgiveness": 0.2265625, "next_hold": 0},
	{"cols": [[3, 2], [0, 3, 2], [3, 1, 0], [2, 0, 1]], "reserve": [0, 3, 1, 2], "held": [1], "slots": 2, "min_holds": 2, "forgiveness": 0.0625, "next_hold": 2},
	{"cols": [[2, 1, 0, 3], [2, 0], [1, 0, 1], [1]], "reserve": [3, 3, 2, 0], "held": [2, 3], "slots": 2, "min_holds": 1, "forgiveness": 0.25, "next_hold": 2},
	{"cols": [[3, 0, 0], [3, 3, 2], [2, 1], [1, 2, 2]], "reserve": [1, 3, 0, 0], "held": [1], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[1, 3, 2, 2], [3, 0], [0, 3, 1], [0]], "reserve": [3, 0, 1, 2], "held": [1, 2], "slots": 2, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1},
	{"cols": [[1, 2], [2, 0, 3], [0, 3, 1], [2, 1, 0]], "reserve": [2, 0, 3, 1], "held": [3], "slots": 3, "min_holds": 2, "forgiveness": 0.5625, "next_hold": 0},
	{"cols": [[1, 3, 0, 3], [1, 2], [3, 0], [0, 3]], "reserve": [2, 1, 1, 0], "held": [2, 2], "slots": 3, "min_holds": 2, "forgiveness": 0.3680555555555556, "next_hold": 0},
	{"cols": [[3, 0, 0], [1, 1, 2], [3, 3, 0], [0, 2]], "reserve": [1, 2, 2, 3], "held": [1], "slots": 3, "min_holds": 3, "forgiveness": 0.6932870370370371, "next_hold": 0},
	{"cols": [[0, 1, 1, 3], [0, 1, 3], [2, 2], [1]], "reserve": [2, 0, 0, 2], "held": [3, 3], "slots": 3, "min_holds": 2, "forgiveness": 0.8055555555555556, "next_hold": 0},
]

const LAYOUTS: Array[Dictionary] = [
	{"columns": [2, 2, 2, 2], "reserve": 4, "groups": 3},
	{"columns": [2, 2, 2, 2], "reserve": 8, "groups": 4},
	{"columns": [3, 3, 2, 2], "reserve": 6, "groups": 4},
	{"columns": [3, 3, 3, 3], "reserve": 4, "groups": 4},
	{"columns": [4, 3, 3, 2], "reserve": 4, "groups": 4},
]
const RANDOM_DEALS := 200

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("참고 구현 기대값", _fixtures)
	_section("판 상태 분석", _board_analysis)
	_section("무작위 판 따라가기", _follow_random_deals)
	print("Fa solver probe: %d checks, %d failed" % [_checks, _failed.size()])
	for line: String in _failed:
		print("  FAILED ", line)
	quit(0 if _failed.is_empty() else 1)


func _section(title: String, body: Callable) -> void:
	if body.call() != true:
		_failed.append(title + ": 끝까지 실행되지 않음")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


func _fixtures() -> bool:
	for index: int in FIXTURES.size():
		var row: Dictionary = FIXTURES[index]
		var result: Dictionary = Solver.solve(row["cols"], row["reserve"], row["held"], row["slots"])
		var label: String = "기대값 %d: " % index
		_check(result["solvable"] == (row["min_holds"] != -1), label + "풀림 여부")
		_check(result["min_holds"] == row["min_holds"], label + "최소 이동 수 %d" % result["min_holds"])
		_check(absf(result["forgiveness"] - row["forgiveness"]) < 1e-12, label + "관대함 %f" % result["forgiveness"])
		_check(result["next_hold"] == row["next_hold"], label + "첫 이동 열 %d" % result["next_hold"])
	return true


## 묶음 번호 배치를 카드 id로 바꾼 레벨. 묶음 g의 카드는 g0~g3이다.
func _level(cols: Array, reserve: Array, groups: int) -> Dictionary:
	var used: Array[int] = []
	used.resize(groups)
	used.fill(0)
	var named_cols: Array = []
	for column: Array in cols:
		named_cols.append(_named(column, used))
	var named_reserve: Array = _named(reserve, used)
	var level_groups: Array = []
	for group: int in groups:
		level_groups.append({"cat": "g%d" % group, "items": ["%d0" % group, "%d1" % group, "%d2" % group, "%d3" % group]})
	return {"n": 1, "layout": "probe", "tier": 1, "f": 0.0, "groups": level_groups, "cols": named_cols, "reserve": named_reserve}


func _named(cards: Array, used: Array[int]) -> Array:
	var named: Array = []
	for group: int in cards:
		named.append("%d%d" % [group, used[group]])
		used[group] += 1
	return named


func _submit_open_groups(board: Board) -> void:
	var found: bool = true
	while found:
		found = false
		var by_category: Dictionary = {}
		for entry: Dictionary in board.open_cards():
			var category: String = board.category_of(entry["card"])
			if not by_category.has(category):
				by_category[category] = []
			by_category[category].append(entry["card"])
		for cards: Array in by_category.values():
			if cards.size() == Board.GROUP_SIZE:
				found = board.submit(cards)["kind"] == "group"
				break


func _board_analysis() -> bool:
	var row: Dictionary = FIXTURES[12]
	var board: Board = Board.create(_level(row["cols"], row["reserve"], 4), 2)
	var result: Dictionary = Solver.solve_board(board, board.slot_count())
	_check(result == {"solvable": true, "min_holds": 2, "forgiveness": 0.125, "next_hold": 0}, "판을 그대로 분석한다")
	_check(Solver.solve_board(board, 3)["forgiveness"] > 0.125, "임시 칸이 3개면 더 관대하다")

	board.hold(board.front_card(1))
	result = Solver.solve_board(board, board.slot_count())
	_check(result == Solver.solve([[3, 2, 0], [0, 3], [1, 0, 3], [1, 2, 0]], [3, 1, 2, 1], [2], 2), "임시 칸에 카드가 있는 판은 같은 배치의 직접 분석과 같다")
	_check(result == {"solvable": false, "min_holds": -1, "forgiveness": 0.0, "next_hold": -1}, "잘못 옮기면 풀 수 없는 판이 된다")
	_check(not board.is_stuck(), "둘 수 있는 수는 남아 있어 막힘과는 다르다")

	board.undo()
	board.hold(board.front_card(0))
	result = Solver.solve_board(board, board.slot_count())
	_check(result == {"solvable": true, "min_holds": 1, "forgiveness": 0.25, "next_hold": 3}, "최소 해법의 첫 수를 두면 남은 이동이 하나 준다")

	var dead: Dictionary = FIXTURES[20]
	board = Board.create(_level(dead["cols"], dead["reserve"], 4), 2)
	_check(not Solver.solve_board(board, 2)["solvable"] and Solver.solve_board(board, 2)["next_hold"] == -1, "임시 칸 2개로는 풀 수 없는 판")
	_check(Solver.solve_board(board, 3)["solvable"], "칸을 추가하면 풀 수 있다")
	board.unlock_slot()
	_check(Solver.solve_board(board, board.slot_count())["min_holds"] == 3, "칸을 추가한 판의 최소 이동 수")

	var done: Board = Board.create(_level([[0], [0], [0], [0]], [], 1), 2)
	_check(Solver.solve_board(done, 2) == {"solvable": true, "min_holds": 0, "forgiveness": 1.0, "next_hold": -1}, "묶기만 남은 판")
	done.submit(["00", "01", "02", "03"])
	_check(Solver.solve_board(done, 2) == {"solvable": true, "min_holds": 0, "forgiveness": 1.0, "next_hold": -1}, "끝난 판")
	return true


func _follow_random_deals() -> bool:
	var random: Random = Random.new(20261121)
	var solvable_count: int = 0
	var finished: int = 0
	var exact: int = 0
	for index: int in RANDOM_DEALS:
		var layout: Dictionary = LAYOUTS[index % LAYOUTS.size()]
		var cards: Array = []
		for group: int in layout["groups"]:
			for _copy: int in Board.GROUP_SIZE:
				cards.append(group)
		random.shuffle(cards)
		var cols: Array = []
		var used: int = 0
		for depth: int in layout["columns"]:
			cols.append(cards.slice(used, used + depth))
			used += depth
		var board: Board = Board.create(_level(cols, cards.slice(used), layout["groups"]), 2)
		var first: Dictionary = Solver.solve_board(board, 2)
		if not first["solvable"]:
			continue
		solvable_count += 1
		var holds: int = 0
		var remaining: int = first["min_holds"]
		var consistent: bool = true
		_submit_open_groups(board)
		while not board.is_won() and holds <= 16:
			var step: Dictionary = Solver.solve_board(board, 2)
			if not step["solvable"] or step["min_holds"] != remaining or step["next_hold"] == -1:
				consistent = false
				break
			if not board.hold(board.front_card(step["next_hold"]))["ok"]:
				consistent = false
				break
			holds += 1
			remaining -= 1
			_submit_open_groups(board)
		if board.is_won() and consistent:
			finished += 1
			if holds == first["min_holds"]:
				exact += 1
	_check(solvable_count >= RANDOM_DEALS / 2, "무작위 판의 절반 이상은 풀린다(%d)" % solvable_count)
	_check(finished == solvable_count, "풀린다고 한 판은 next_hold를 따라가면 끝난다(%d / %d)" % [finished, solvable_count])
	_check(exact == solvable_count, "따라간 이동 수는 최소 이동 수와 같다(%d / %d)" % [exact, solvable_count])
	return true
