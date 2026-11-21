extends SceneTree
## 판 규칙 검사: GDD 인수 시나리오 AC-001~005, 007~012의 상태 변화와 오답 재제출, 되돌리기 범위, 직렬화 왕복.

const Board := preload("res://game/core/domain/fa_board.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("판 만들기", _creation)
	_section("AC-001 묶음 완성", _ac_001_group)
	_section("AC-002 한 장만 다름", _ac_002_one_away)
	_section("AC-003 같은 오답 재제출", _ac_003_repeat)
	_section("묶기 입력 검증", _submit_validation)
	_section("AC-004 임시 칸으로 옮기기", _ac_004_hold)
	_section("AC-005 옮길 수 없는 카드", _ac_005_fixed_cards)
	_section("AC-007 실수 4회와 이어하기", _ac_007_fail_and_continue)
	_section("AC-008 막힘", _ac_008_stuck)
	_section("AC-009 되돌리기", _ac_009_undo)
	_section("AC-010 칸 추가", _ac_010_slot)
	_section("AC-011 힌트", _ac_011_hint)
	_section("AC-012 저장 뒤 복원", _ac_012_roundtrip)
	_section("끝까지 풀기", _full_clear)
	print("Fa board probe: %d checks, %d failed" % [_checks, _failed.size()])
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


## classic 배치. 각 열은 뒤에서 앞 순서이고 마지막 원소가 열린 카드다.
func _level() -> Dictionary:
	return {
		"n": 7, "layout": "classic", "tier": 3, "f": 0.31,
		"groups": [
			{"cat": "A", "items": ["a1", "a2", "a3", "a4"]},
			{"cat": "B", "items": ["b1", "b2", "b3", "b4"]},
			{"cat": "C", "items": ["c1", "c2", "c3", "c4"]},
			{"cat": "D", "items": ["d1", "d2", "d3", "d4"]},
		],
		"cols": [["b1", "c1", "a1"], ["d1", "b2", "a2"], ["c2", "d2", "a3"], ["d3", "c3", "b3"]],
		"reserve": ["a4", "b4", "c4", "d4"],
	}


func _board() -> Board:
	return Board.create(_level(), Board.HOLD_SLOTS_BASE)


func _open_ids(board: Board) -> Array:
	var ids: Array = []
	for entry: Dictionary in board.open_cards():
		ids.append(entry["card"])
	return ids


func _creation() -> bool:
	var board: Board = _board()
	_check(board != null, "올바른 레벨로 판이 만들어진다")
	_check(board.column_count() == 4 and board.column_size(0) == 3 and board.hidden_count(0) == 2, "열 장수와 뒤집힌 장수")
	_check(board.front_card(0) == "a1" and board.front_card(3) == "b3", "각 열의 맨 앞 카드")
	_check(board.column_cards(0) == ["b1", "c1", "a1"], "탐색기용 열 전체 카드(뒤에서 앞 순서)")
	_check(board.reserve() == ["a4", "b4", "c4", "d4"], "예비 칸")
	_check(board.holds() == ["", ""] and board.slot_count() == 2, "임시 칸은 2개이고 비어 있다")
	_check(_open_ids(board) == ["a1", "a2", "a3", "b3", "a4", "b4", "c4", "d4"], "열린 카드는 열 맨 앞과 예비 카드")
	_check(board.open_cards()[0] == {"card": "a1", "zone": "column", "index": 0}, "열린 카드의 위치(열)")
	_check(board.open_cards()[5] == {"card": "b4", "zone": "reserve", "index": 1}, "열린 카드의 위치(예비)")
	_check(board.can_select("a1") and board.can_select("d4"), "열린 카드는 선택할 수 있다")
	_check(not board.can_select("c1") and not board.can_select("zz"), "뒤집힌 카드와 없는 카드는 선택할 수 없다")
	_check(board.mistakes() == 0 and board.solved().is_empty() and board.remaining_groups() == 4, "처음 상태")
	_check(not board.is_won() and not board.is_failed() and not board.is_stuck(), "처음에는 끝나지도 막히지도 않았다")
	_check(board.meta() == {"n": 7, "layout": "classic", "tier": 3, "f": 0.31}, "레벨 정보")
	_check(board.categories() == ["A", "B", "C", "D"] and board.group_items("B") == ["b1", "b2", "b3", "b4"], "묶음 정의")
	_check(board.category_of("c3") == "C" and board.category_of("zz") == "", "카드의 범주")
	_check(Board.create(_level(), 3).slot_count() == 3, "임시 칸 3개로 시작할 수 있다")
	_check(Board.create(_level(), 4) == null and Board.create(_level(), 1) == null, "임시 칸 수 범위 밖은 거부")

	var broken: Dictionary = _level()
	broken["reserve"] = ["a4", "b4", "c4"]
	_check(Board.create(broken, 2) == null, "카드가 빠진 레벨은 거부")
	broken = _level()
	broken["reserve"] = ["a4", "b4", "c4", "a1"]
	_check(Board.create(broken, 2) == null, "같은 카드가 두 번 나오는 레벨은 거부")
	broken = _level()
	broken["groups"][0]["items"] = ["a1", "a2", "a3"]
	_check(Board.create(broken, 2) == null, "4장이 아닌 묶음은 거부")
	broken = _level()
	broken["groups"][1]["cat"] = "A"
	_check(Board.create(broken, 2) == null, "범주가 겹치는 레벨은 거부")
	_check(Board.create({}, 2) == null, "빈 레벨은 거부")
	return true


func _ac_001_group() -> bool:
	var board: Board = _board()
	var result: Dictionary = board.submit(["a4", "a1", "a3", "a2"])
	_check(result["kind"] == "group" and result["category"] == "A", "같은 범주 4장은 완성")
	_check(result["mistakes"] == 0 and not result["won"] and not result["failed"], "완성은 실수를 더하지 않는다")
	_check(result["removed"].size() == 4, "제거된 카드 4장의 위치를 알려 준다")
	_check(result["removed"].has({"card": "a1", "zone": "column", "index": 0}), "열에서 제거된 카드 위치")
	_check(result["removed"].has({"card": "a4", "zone": "reserve", "index": 0}), "예비에서 제거된 카드 위치")
	_check(result["opened"] == [
		{"card": "c1", "zone": "column", "index": 0},
		{"card": "b2", "zone": "column", "index": 1},
		{"card": "d2", "zone": "column", "index": 2},
	], "가려진 카드가 열린다")
	_check(board.solved() == ["A"] and board.remaining_groups() == 3, "범주 띠가 완성 순서대로 쌓인다")
	_check(board.front_card(0) == "c1" and board.column_size(0) == 2 and board.hidden_count(0) == 1, "열에서 카드가 빠진다")
	_check(board.reserve() == ["", "b4", "c4", "d4"], "예비 칸의 자리는 유지되고 빈 자리가 된다")
	_check(not board.can_select("a1"), "제거된 카드는 선택할 수 없다")
	return true


func _ac_002_one_away() -> bool:
	var board: Board = _board()
	var before: Dictionary = board.to_dict()
	var result: Dictionary = board.submit(["a1", "a2", "a3", "b3"])
	_check(result["kind"] == "one_away", "3장만 같으면 한 장만 달라요")
	_check(result["mistakes"] == 1 and board.mistakes() == 1 and not result["failed"], "실수 1 증가")
	before["mistakes"] = 1
	before["tried"] = ["a1|a2|a3|b3"]
	_check(board.to_dict() == before, "카드 위치는 그대로다")

	result = board.submit(["a1", "a2", "b3", "b4"])
	_check(result["kind"] == "miss" and result["mistakes"] == 2, "2장씩 섞인 조합은 그냥 실수")
	result = board.submit(["a1", "b4", "c4", "d4"])
	_check(result["kind"] == "miss" and result["mistakes"] == 3, "모두 다른 조합도 실수")
	return true


func _ac_003_repeat() -> bool:
	var board: Board = _board()
	board.submit(["a1", "a2", "a3", "b3"])
	var result: Dictionary = board.submit(["b3", "a3", "a2", "a1"])
	_check(result["kind"] == "repeat", "같은 조합은 순서가 달라도 이미 해 본 조합")
	_check(result["mistakes"] == 1 and board.mistakes() == 1, "실수가 늘지 않는다")
	result = board.submit(["a1", "a2", "a3", "b4"])
	_check(result["kind"] == "one_away" and board.mistakes() == 2, "한 장이라도 다르면 새 조합")
	board.submit(["a1", "a2", "b3", "b4"])
	result = board.submit(["a1", "a2", "b3", "b4"])
	_check(result["kind"] == "repeat" and board.mistakes() == 3, "일반 오답도 재제출은 실수가 아니다")
	return true


func _submit_validation() -> bool:
	var board: Board = _board()
	_check(board.submit(["a1", "a2", "a3"])["kind"] == "invalid" and board.submit(["a1", "a2", "a3"])["reason"] == "count", "3장은 묶을 수 없다")
	_check(board.submit(["a1", "a2", "a3", "a4", "b3"])["reason"] == "count", "5장은 묶을 수 없다")
	_check(board.submit(["a1", "a2", "a3", "c1"])["reason"] == "not_open", "뒤집힌 카드는 묶을 수 없다")
	_check(board.submit(["a1", "a2", "a3", "zz"])["reason"] == "not_open", "없는 카드는 묶을 수 없다")
	_check(board.submit(["a1", "a2", "a3", "a1"])["reason"] == "duplicate", "같은 카드를 두 번 낼 수 없다")
	_check(board.mistakes() == 0, "거부된 입력은 실수가 아니다")
	return true


func _ac_004_hold() -> bool:
	var board: Board = _board()
	_check(board.can_hold("a1") and not board.can_hold("c1"), "열 맨 앞 카드만 옮길 수 있다")
	var result: Dictionary = board.hold("a1")
	_check(result == {"ok": true, "card": "a1", "column": 0, "slot": 0, "opened": "c1"}, "카드가 첫 빈 칸으로 가고 다음 카드가 열린다")
	_check(board.holds() == ["a1", ""] and board.front_card(0) == "c1" and board.hidden_count(0) == 1, "칸과 열의 상태")
	_check(board.can_select("a1") and board.can_select("c1"), "옮긴 카드와 새로 열린 카드를 선택할 수 있다")
	_check(board.open_cards().has({"card": "a1", "zone": "hold", "index": 0}), "임시 칸 카드의 위치")
	_check(board.hold_moves() == 1, "임시 칸 사용 횟수")
	result = board.hold("c1")
	_check(result["ok"] and result["slot"] == 1 and result["opened"] == "b1", "두 번째 칸")
	result = board.hold("b1")
	_check(result == {"ok": false, "reason": "no_slot"}, "칸이 가득 차면 옮길 수 없다")
	_check(board.front_card(0) == "b1" and board.column_size(0) == 1 and board.hidden_count(0) == 0, "마지막 한 장은 뒤집힌 카드가 없다")

	board = Board.create(_level(), 3)
	board.hold("a1")
	board.hold("c1")
	result = board.hold("b1")
	_check(result["ok"] and result["opened"] == "" and board.column_size(0) == 0 and board.front_card(0) == "", "열의 마지막 카드를 옮기면 열이 빈다")
	return true


func _ac_005_fixed_cards() -> bool:
	var board: Board = _board()
	_check(board.hold("a4") == {"ok": false, "reason": "not_front"}, "예비 카드는 옮겨지지 않는다")
	_check(board.reserve() == ["a4", "b4", "c4", "d4"] and board.holds() == ["", ""], "예비 카드는 제자리에 있다")
	_check(board.can_select("a4") and not board.can_hold("a4"), "예비 카드는 선택만 된다")
	board.hold("a1")
	_check(board.hold("a1") == {"ok": false, "reason": "not_front"}, "임시 칸의 카드는 다시 옮겨지지 않는다")
	_check(board.holds() == ["a1", ""] and board.can_select("a1") and not board.can_hold("a1"), "임시 칸 카드는 선택만 된다")
	_check(board.hold("b1") == {"ok": false, "reason": "not_front"}, "뒤집힌 카드는 옮겨지지 않는다")
	return true


func _fail(board: Board) -> void:
	board.submit(["a1", "a2", "a3", "b3"])
	board.submit(["a1", "a2", "a3", "b4"])
	board.submit(["a1", "a2", "a3", "c4"])
	board.submit(["a1", "a2", "a3", "d4"])


func _ac_007_fail_and_continue() -> bool:
	var board: Board = _board()
	board.submit(["a1", "a2", "a3", "b3"])
	board.submit(["a1", "a2", "a3", "b4"])
	board.submit(["a1", "a2", "a3", "c4"])
	_check(not board.is_failed() and not board.can_continue(), "실수 3회까지는 실패가 아니다")
	_check(not board.apply_continue(), "실패하지 않았으면 이어하기를 쓸 수 없다")
	var result: Dictionary = board.submit(["a1", "a2", "a3", "d4"])
	_check(result["failed"] and result["mistakes"] == 4 and board.is_failed(), "4번째 실수에서 실패")
	_check(board.submit(["a1", "a2", "a3", "a4"]) == {"kind": "invalid", "reason": "failed", "mistakes": 4, "won": false, "failed": true}, "실패한 판은 묶을 수 없다")
	_check(board.hold("a1") == {"ok": false, "reason": "failed"}, "실패한 판은 카드를 옮길 수 없다")
	_check(board.can_continue() and board.apply_continue(), "이어하기를 받는다")
	_check(board.mistakes() == 2 and not board.is_failed() and board.continue_used(), "실수가 2로 돌아가 판이 이어진다")
	_check(board.submit(["a1", "a2", "a3", "d4"])["kind"] == "repeat", "이어한 뒤에도 해 본 조합은 기억한다")
	board.submit(["a1", "a2", "b3", "b4"])
	board.submit(["a1", "a2", "b3", "c4"])
	_check(board.is_failed(), "다시 실수 4회가 되면 실패")
	_check(not board.can_continue() and not board.apply_continue() and board.mistakes() == 4, "두 번째 실패에는 이어하기가 없다")
	return true


func _ac_008_stuck() -> bool:
	var board: Board = _board()
	board.hold("b3")
	_check(not board.is_stuck(), "칸이 남아 있으면 막힌 것이 아니다")
	board.hold("c3")
	_check(_open_ids(board) == ["a1", "a2", "a3", "d3", "a4", "b4", "c4", "d4", "b3", "c3"], "두 칸을 채운 뒤 열린 카드")
	_check(not board.is_stuck(), "칸이 가득 차도 완성할 묶음이 있으면 막힌 것이 아니다")
	board.submit(["a1", "a2", "a3", "a4"])
	_check(_open_ids(board) == ["c1", "b2", "d2", "d3", "b4", "c4", "d4", "b3", "c3"], "묶음 완성 뒤 열린 카드")
	_check(board.is_stuck(), "칸이 가득 차고 완성할 묶음이 없으면 막힘")
	_check(not board.can_undo() and board.can_unlock_slot(), "묶음 완성 뒤라 되돌리기는 없고 칸 추가는 가능하다")
	_check(board.unlock_slot() and not board.is_stuck(), "칸을 추가하면 막힘이 풀린다")

	board = _board()
	board.hold("b3")
	board.hold("a1")
	board.submit(["a2", "a3", "a4", "a1"])
	_check(board.holds() == ["b3", ""] and not board.is_stuck(), "묶음이 임시 칸을 비우면 막히지 않는다")
	board.hold("c3")
	_check(board.is_stuck() and board.can_undo(), "다시 가득 차면 막힘이고 마지막 이동은 되돌릴 수 있다")
	board.undo()
	_check(not board.is_stuck(), "되돌리면 막힘이 풀린다")
	board.hold("c3")
	for last: String in ["d3", "b4", "c4", "d4"]:
		board.submit(["c1", "b2", "d2", last])
	_check(board.is_failed() and board.is_stuck(), "막힘은 실수 횟수와 무관하다")
	return true


func _ac_009_undo() -> bool:
	var board: Board = _board()
	_check(not board.can_undo() and board.undo() == {"ok": false, "reason": "nothing"}, "옮긴 적이 없으면 되돌릴 것이 없다")
	var before: Dictionary = board.to_dict()
	board.hold("a1")
	_check(board.can_undo(), "옮긴 뒤에는 되돌릴 수 있다")
	var result: Dictionary = board.undo()
	_check(result == {"ok": true, "card": "a1", "column": 0, "slot": 0, "closed": "c1"}, "카드가 원래 열로 돌아가고 열렸던 카드가 뒤집힌다")
	_check(board.to_dict() == before, "되돌리면 옮기기 전 상태와 같다")
	_check(not board.can_select("c1") and board.front_card(0) == "a1" and board.hold_moves() == 0, "열렸던 카드는 다시 뒤집힌다")
	_check(not board.can_undo() and not board.undo()["ok"], "한 번 되돌린 뒤에는 더 되돌릴 수 없다")

	board.hold("a1")
	board.hold("a2")
	result = board.undo()
	_check(result["ok"] and result["card"] == "a2" and result["slot"] == 1 and result["closed"] == "b2", "마지막 이동만 되돌린다")
	_check(board.holds() == ["a1", ""] and not board.can_undo(), "그 전 이동은 되돌릴 수 없다")

	board = _board()
	board.hold("b3")
	board.submit(["a1", "a2", "a3", "b4"])
	_check(board.can_undo(), "오답은 되돌리기 기록을 지우지 않는다")
	board.submit(["a1", "a2", "a3", "a4"])
	_check(not board.can_undo() and board.undo() == {"ok": false, "reason": "nothing"}, "묶음이 완성되면 기록을 비운다")
	_check(board.holds() == ["b3", ""], "완성 전에 옮긴 카드는 임시 칸에 남는다")

	board = Board.create(_level(), 3)
	board.hold("a1")
	board.hold("c1")
	board.hold("b1")
	result = board.undo()
	_check(result == {"ok": true, "card": "b1", "column": 0, "slot": 2, "closed": ""}, "빈 열로 돌아갈 때는 뒤집히는 카드가 없다")
	return true


func _ac_010_slot() -> bool:
	var board: Board = _board()
	_check(board.can_unlock_slot() and board.unlock_slot(), "칸 추가")
	_check(board.slot_count() == 3 and board.holds() == ["", "", ""], "3번째 칸이 열린다")
	_check(not board.can_unlock_slot() and not board.unlock_slot() and board.slot_count() == 3, "판당 1회")
	board.hold("a1")
	board.hold("a2")
	_check(board.hold("a3")["slot"] == 2, "3번째 칸에 카드를 넣을 수 있다")
	board.submit(["a1", "a2", "a3", "a4"])
	_check(board.slot_count() == 3 and board.holds() == ["", "", ""], "그 판 동안 유지된다")
	_check(_board().slot_count() == 2, "다음 판에서는 다시 잠긴다")
	return true


func _ac_011_hint() -> bool:
	var board: Board = _board()
	_check(board.hint_pair() == ["a1", "a2"], "열린 카드가 가장 많은 묶음의 앞 두 장을 알려 준다")
	board.submit(["a1", "a2", "a3", "a4"])
	_check(board.hint_pair() == ["b2", "b3"], "남은 열린 카드에서 같은 범주 2장")
	var pair: Array = board.hint_pair()
	_check(board.can_select(pair[0]) and board.can_select(pair[1]) and board.category_of(pair[0]) == board.category_of(pair[1]), "힌트의 두 장은 열려 있고 같은 범주다")

	var spread: Dictionary = _level()
	spread["cols"] = [["a2", "a3", "a1"], ["b2", "b3", "b1"], ["c2", "c3", "c1"], ["d2", "d3", "d1"]]
	_check(Board.create(spread, 2).hint_pair() == ["a1", "a4"], "열린 장수가 같으면 레벨의 묶음 순서를 따르고 예비 카드와의 짝도 찾는다")
	spread["cols"] = [["a2", "a3", "a1"], ["a4", "b3", "b1"], ["c2", "c3", "c1"], ["d2", "d3", "d1"]]
	spread["reserve"] = ["b2", "b4", "c4", "d4"]
	_check(Board.create(spread, 2).hint_pair() == ["b1", "b2"], "열린 카드가 더 많은 묶음을 먼저 알려 준다")
	var none: Dictionary = {
		"n": 1, "layout": "x", "tier": 1, "f": 1.0,
		"groups": [{"cat": "A", "items": ["a1", "a2", "a3", "a4"]}, {"cat": "B", "items": ["b1", "b2", "b3", "b4"]}],
		"cols": [["a4", "a3", "a2", "a1"], ["b4", "b3", "b2", "b1"]],
		"reserve": [],
	}
	_check(Board.create(none, 2).hint_pair() == [], "같은 범주 2장이 없으면 빈 배열")
	return true


func _ac_012_roundtrip() -> bool:
	var board: Board = _board()
	board.unlock_slot()
	board.submit(["a1", "a2", "a3", "b3"])
	board.submit(["a1", "a2", "a3", "a4"])
	board.hold("c1")
	board.hold("b2")
	var saved: Dictionary = board.to_dict()
	var text: String = JSON.stringify(saved)
	var restored: Board = Board.from_dict(JSON.parse_string(text))
	_check(restored != null, "저장한 판을 복원한다")
	_check(restored.to_dict() == saved, "복원한 판은 저장한 상태와 같다")
	_check(JSON.stringify(restored.to_dict()) == text, "다시 저장해도 같은 글자다")
	_check(restored.front_card(0) == "b1" and restored.holds() == ["c1", "b2", ""] and restored.reserve() == ["", "b4", "c4", "d4"], "카드 위치가 그대로다")
	_check(restored.mistakes() == 1 and restored.solved() == ["A"] and restored.slot_count() == 3, "실수, 완성한 묶음, 3번째 칸이 그대로다")
	_check(restored.meta() == {"n": 7, "layout": "classic", "tier": 3, "f": 0.31} and restored.hold_moves() == 2, "레벨 정보와 임시 칸 사용 횟수")
	_check(restored.can_undo() and restored.undo()["card"] == "b2", "되돌리기 기록이 그대로다")
	_check(restored.submit(["b1", "d2", "b3", "b4"])["kind"] == "one_away", "복원한 판에서 계속 진행한다")
	_check(restored.mistakes() == 2 and board.mistakes() == 1, "복원한 판은 원래 판과 따로 움직인다")

	board = _board()
	_fail(board)
	board.apply_continue()
	restored = Board.from_dict(JSON.parse_string(JSON.stringify(board.to_dict())))
	_check(restored.continue_used() and restored.mistakes() == 2, "이어하기 사용 여부가 그대로다")
	_check(restored.submit(["a1", "a2", "a3", "b3"])["kind"] == "repeat", "낸 오답 조합이 그대로다")

	var damaged: Dictionary = _board().to_dict()
	damaged["cols"][0] = ["b1", "c1"]
	_check(Board.from_dict(damaged) == null, "카드가 빠진 저장은 거부")
	damaged = _board().to_dict()
	damaged["holds"] = ["a1", ""]
	_check(Board.from_dict(damaged) == null, "같은 카드가 두 곳에 있는 저장은 거부")
	damaged = _board().to_dict()
	damaged["mistakes"] = 9
	_check(Board.from_dict(damaged) == null, "실수 수가 범위 밖인 저장은 거부")
	damaged = _board().to_dict()
	damaged["solved"] = ["A"]
	_check(Board.from_dict(damaged) == null, "완성했다는 묶음의 카드가 남아 있는 저장은 거부")
	damaged = _board().to_dict()
	damaged["undo"] = {"card": "a1", "column": 0, "slot": 0}
	_check(Board.from_dict(damaged) == null, "임시 칸에 없는 카드의 되돌리기 기록은 거부")
	damaged = _board().to_dict()
	damaged.erase("holds")
	_check(Board.from_dict(damaged) == null and Board.from_dict({}) == null, "필드가 빠진 저장은 거부")
	return true


func _full_clear() -> bool:
	var board: Board = _board()
	board.submit(["a1", "a2", "a3", "a4"])
	board.hold("c1")
	board.hold("d2")
	_check(board.submit(["b1", "b2", "b3", "b4"])["kind"] == "group", "두 번째 묶음")
	_check(_open_ids(board) == ["d1", "c2", "c3", "c4", "d4", "c1", "d2"], "두 묶음 뒤 열린 카드")
	var result: Dictionary = board.submit(["c1", "c2", "c3", "c4"])
	_check(result["kind"] == "group" and not result["won"] and result["opened"] == [{"card": "d3", "zone": "column", "index": 3}], "세 번째 묶음")
	result = board.submit(["d1", "d2", "d3", "d4"])
	_check(result["kind"] == "group" and result["won"] and result["opened"].is_empty(), "마지막 묶음에서 판이 끝난다")
	_check(board.is_won() and not board.is_stuck() and board.remaining_groups() == 0, "모든 묶음 완성")
	_check(board.solved() == ["A", "B", "C", "D"] and board.open_cards().is_empty(), "완성 순서와 빈 판")
	_check(board.submit(["a1", "a2", "a3", "a4"])["reason"] == "finished", "끝난 판은 묶을 수 없다")
	_check(not board.unlock_slot() and board.hint_pair() == [] and not board.can_undo(), "끝난 판에서는 부스터가 듣지 않는다")
	var restored: Board = Board.from_dict(JSON.parse_string(JSON.stringify(board.to_dict())))
	_check(restored != null and restored.is_won(), "끝난 판도 저장하고 복원한다")
	return true
