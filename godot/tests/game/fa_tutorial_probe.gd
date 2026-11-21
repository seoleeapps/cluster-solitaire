extends SceneTree
## 튜토리얼 판(godot/data/levels/tutorial.json)의 프로브. 코어의 판과 해법 탐색기로 안내 순서를 그대로 두어 본다.
## 형식과 범주 조건의 독립 검증은 tools/levels/verify_packs.py가 한다.

const Content := preload("res://game/core/domain/fa_content.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Session := preload("res://game/bootstrap/fa_session.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	var pack: Dictionary = _read(Session.TUTORIAL_PATH)
	var content := Content.new(_read(Session.ITEMS_PATH), _read(Session.CATEGORIES_PATH))
	var levels: Array = pack.get("levels", [])
	var guide: Dictionary = pack.get("guide", {})
	_check(pack.get("version") == 1 and pack.get("content_version") == content.version() and levels.size() == 1, "pack header and a single level")
	var board: Board = Board.create(levels[0], Board.HOLD_SLOTS_BASE) if levels.size() == 1 else null
	_check(board != null, "the level loads as a board")
	if board != null:
		_shape(board, content)
		_guide(board, guide)
	for line: String in _failed:
		print("FAILED: " + line)
	print("Tutorial probe: %d checks, %d failed" % [_checks, _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


func _shape(board: Board, content: Content) -> void:
	var shape: Dictionary = Difficulty.layout("intro")
	var columns: Array = []
	for column: int in board.column_count():
		columns.append(board.column_size(column))
	_check(board.meta()["layout"] == "intro" and columns == shape["columns"] and board.reserve().size() == shape["reserve"], "intro layout: columns 2, 2, 2, 2 and four reserve cards")
	_check(board.categories().size() == shape["groups"], "three categories")
	for category: String in board.categories():
		_check(content.has_category(category) and content.category_tier(category) == 1, category + " is a tier 1 category")
		for card: String in board.group_items(category):
			_check(content.category_members(category).has(card), card + " is a member of " + category)
			_check(not content.item_name(card, "en").is_empty() and not content.item_name(card, "ko").is_empty(), card + " has both names")
			for other: String in board.categories():
				_check(other == category or not content.is_candidate(other, card), card + " does not read as " + other)
	var solved: Dictionary = Solver.solve_board(board, Board.HOLD_SLOTS_BASE)
	_check(solved["solvable"] and solved["min_holds"] == 1, "solvable with two slots in one holding move")
	_check(is_equal_approx(snappedf(solved["forgiveness"], 0.01), board.meta()["f"]), "stored forgiveness matches the solver")


## 안내 순서: 예비 카드 네 장으로 첫 묶음, 맨 앞 카드 하나를 임시 칸으로 옮겨 숨은 카드를 열고 둘째 묶음, 남은 네 장.
func _guide(board: Board, guide: Dictionary) -> void:
	var order: Array = guide.get("order", [])
	var hold: String = guide.get("hold", "")
	_check(order.size() == 3 and board.categories().all(func(category: String) -> bool: return order.has(category)), "the guide orders every category")
	if order.size() != 3:
		return
	var first: Array = board.group_items(order[0])
	var reserve: Array = board.reserve()
	_check(first.all(func(card: String) -> bool: return reserve.has(card)), "step 1: the first group is the four reserve cards")
	_check(board.hint_pair().size() == 2 and board.category_of(board.hint_pair()[0]) == order[0], "step 1: the only open pair to hint is the first group")
	_check(board.submit(first)["kind"] == Board.KIND_GROUP, "step 1: grouping the reserve cards completes the first group")
	var second: Array = board.group_items(order[1])
	_check(not second.all(func(card: String) -> bool: return board.can_select(card)), "step 2: the second group is not open yet")
	_check(board.can_hold(hold) and board.category_of(hold) == order[2], "step 2: the guide card is a front card of the last group")
	_check(Solver.solve_board(board, Board.HOLD_SLOTS_BASE)["next_hold"] == _column_of(board, hold), "step 2: the solver would move the same card")
	var held: Dictionary = board.hold(hold)
	_check(held["ok"] and board.category_of(held["opened"]) == order[1], "step 2: holding it opens a card of the second group")
	_check(board.submit(second)["kind"] == Board.KIND_GROUP, "step 2: the second group completes")
	var last: Array = board.group_items(order[2])
	_check(last.all(func(card: String) -> bool: return board.can_select(card)), "step 3: the last four are all open")
	var outcome: Dictionary = board.submit(last)
	_check(outcome["kind"] == Board.KIND_GROUP and outcome["won"] and board.mistakes() == 0, "step 3: the last group wins the board without a mistake")


func _column_of(board: Board, card: String) -> int:
	for column: int in board.column_count():
		if board.front_card(column) == card:
			return column
	return -1


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
