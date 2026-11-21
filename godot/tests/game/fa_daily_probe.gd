extends SceneTree
## 일일 도전 검사: 날짜 계산, 도전 번호와 팩 순환, 연속 기록(월말과 연말 넘김 포함).

const Daily := preload("res://game/core/domain/fa_daily.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("날짜", _dates)
	_section("도전 번호", _numbers)
	_section("연속 기록", _streaks)
	_section("지난 날짜와 재도전", _past_dates)
	_section("상태 정리", _state)
	print("Fa daily probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _dates() -> bool:
	_check(Daily.is_date("2026-12-01") and Daily.is_date("2028-02-29") and Daily.is_date("2000-02-29"), "올바른 날짜")
	_check(not Daily.is_date("2026-02-29") and not Daily.is_date("2100-02-29"), "윤년이 아닌 해의 2월 29일")
	_check(not Daily.is_date("2026-13-01") and not Daily.is_date("2026-00-10") and not Daily.is_date("2026-04-31"), "없는 월과 일")
	_check(not Daily.is_date("2026-1-01") and not Daily.is_date("20261201") and not Daily.is_date("2026/12/01"), "형식이 다른 글자")
	_check(not Daily.is_date("") and not Daily.is_date("abcd-ef-gh") and not Daily.is_date("2026-12-0x"), "날짜가 아닌 글자")
	_check(Daily.add_days("2026-12-31", 1) == "2027-01-01", "연말 다음 날")
	_check(Daily.add_days("2027-01-01", -1) == "2026-12-31", "새해 전날")
	_check(Daily.add_days("2028-02-28", 1) == "2028-02-29" and Daily.add_days("2027-02-28", 1) == "2027-03-01", "2월 말")
	_check(Daily.add_days("2026-12-01", 365) == "2027-12-01" and Daily.add_days("2026-12-01", 0) == "2026-12-01", "여러 날 더하기")
	_check(Daily.days_between("2026-12-01", "2027-01-01") == 31 and Daily.days_between("2027-01-01", "2026-12-31") == -1, "두 날짜 사이의 날 수")
	_check(Daily.weekday("2026-12-01") == 2, "2026-12-01은 화요일")
	_check(Daily.weekday("2026-11-21") == 6 and Daily.weekday("2026-11-22") == 0, "토요일과 일요일")
	_check(Daily.weekday("1970-01-01") == 4 and Daily.weekday("2000-01-01") == 6, "알려진 요일")
	_check(Daily.same_month("2026-12-01", "2026-12-31") and not Daily.same_month("2026-12-31", "2027-12-31") and not Daily.same_month("2026-11-30", "2026-12-01"), "같은 달 판별")
	return true


func _numbers() -> bool:
	_check(Daily.BASE_DATE == "2026-12-01", "기준일")
	_check(Daily.challenge_number("2026-12-01") == 1, "기준일이 1번")
	_check(Daily.challenge_number("2026-12-31") == 31 and Daily.challenge_number("2027-01-01") == 32, "연말을 넘는 번호")
	_check(Daily.challenge_number("2027-12-01") == 366 and Daily.challenge_number("2028-12-01") == 732, "윤년을 넘는 번호")
	_check(Daily.challenge_number("2026-11-30") == 0 and Daily.challenge_number("nope") == 0, "기준일 전과 잘못된 날짜는 0")
	_check(Daily.challenge_date(1) == "2026-12-01" and Daily.challenge_date(32) == "2027-01-01", "번호에서 날짜")
	_check(Daily.challenge_date(1100) == "2029-12-04" and Daily.challenge_number("2029-12-04") == 1100, "팩의 마지막 날")
	_check(Daily.pack_number(1, 1100) == 1 and Daily.pack_number(1100, 1100) == 1100, "팩 안의 번호는 그대로")
	_check(Daily.pack_number(1101, 1100) == 1 and Daily.pack_number(2200, 1100) == 1100 and Daily.pack_number(2201, 1100) == 1, "팩 길이를 넘으면 순환")
	_check(Daily.pack_number(0, 1100) == 0 and Daily.pack_number(5, 0) == 0, "번호나 팩이 없으면 0")
	return true


func _summary(mistakes: int) -> Dictionary:
	return {"mistakes": mistakes, "holds": 5, "seconds": 95, "order": ["fruits", "birds", "tools", "planets"]}


func _play(state: Dictionary, date: String) -> Dictionary:
	return Daily.record_success(state, date, date, _summary(0))


func _streaks() -> bool:
	var state: Dictionary = Daily.default_state()
	_check(state == {"results": {}, "streak": 0, "best": 0, "last": ""}, "처음 상태")
	_check(Daily.streak(state, "2026-12-30") == 0, "기록이 없으면 0")
	_check(_play(state, "2026-12-30") == {"recorded": true, "counted": true, "streak": 1}, "첫 성공")
	_check(_play(state, "2026-12-31")["streak"] == 2, "다음 날 성공하면 1 오른다")
	_check(_play(state, "2027-01-01")["streak"] == 3, "연말을 넘어 이어진다")
	_check(state["last"] == "2027-01-01" and state["best"] == 3, "마지막 성공일과 최고 기록")
	_check(Daily.streak(state, "2027-01-01") == 3 and Daily.streak(state, "2027-01-02") == 3, "오늘이나 어제 성공했으면 기록이 살아 있다")
	_check(Daily.streak(state, "2027-01-03") == 0, "하루를 건너뛰면 끊긴다")
	_check(_play(state, "2027-01-03") == {"recorded": true, "counted": true, "streak": 1}, "끊긴 뒤에는 1부터")
	_check(state["best"] == 3, "최고 기록은 남는다")

	state = Daily.default_state()
	_play(state, "2027-01-30")
	_play(state, "2027-01-31")
	_check(_play(state, "2027-02-01")["streak"] == 3, "월말을 넘어 이어진다")
	state = Daily.default_state()
	_play(state, "2028-02-28")
	_play(state, "2028-02-29")
	_check(_play(state, "2028-03-01")["streak"] == 3, "윤년 2월 말을 넘어 이어진다")
	state = Daily.default_state()
	_play(state, "2027-02-28")
	_check(_play(state, "2027-03-01")["streak"] == 2, "평년 2월 말 다음 날은 3월 1일")
	return true


func _past_dates() -> bool:
	var state: Dictionary = Daily.default_state()
	_play(state, "2027-01-01")
	_play(state, "2027-01-02")
	_check(_play(state, "2027-01-02") == {"recorded": false, "counted": false, "streak": 2}, "같은 날 다시 성공해도 바뀌지 않는다")
	_check(state["results"]["2027-01-02"] == _summary(0), "결과 요약을 날짜별로 남긴다")

	var result: Dictionary = Daily.record_success(state, "2027-01-04", "2027-01-05", _summary(2))
	_check(result == {"recorded": true, "counted": false, "streak": 0}, "지난 날짜 성공은 기록하되 연속 기록에 넣지 않는다")
	_check(state["streak"] == 2 and state["last"] == "2027-01-02" and state["results"].has("2027-01-04"), "연속 기록 상태는 그대로다")
	result = Daily.record_success(state, "2027-01-05", "2027-01-05", _summary(1))
	_check(result == {"recorded": true, "counted": true, "streak": 1}, "어제 것을 뒤늦게 풀어도 오늘은 1부터다")

	_check(Daily.record_success(state, "2027-01-07", "2027-01-06", _summary(0))["recorded"] == false, "앞날의 판은 기록하지 않는다")
	_check(Daily.record_success(state, "2026-11-30", "2027-01-06", _summary(0))["recorded"] == false, "기준일 전의 판은 기록하지 않는다")
	_check(Daily.record_success(state, "bad", "2027-01-06", _summary(0))["recorded"] == false, "잘못된 날짜는 기록하지 않는다")
	_check(Daily.record_success(state, "2027-01-06", "2027-01-06", {"mistakes": 0})["recorded"] == false, "요약 형식이 틀리면 기록하지 않는다")

	_check(Daily.can_play(state, "2027-01-06", "2027-01-06"), "오늘의 판")
	_check(Daily.can_play(state, "2027-01-03", "2027-01-06"), "이번 달의 놓친 날")
	_check(not Daily.can_play(state, "2027-01-05", "2027-01-06"), "이미 성공한 날")
	_check(not Daily.can_play(state, "2026-12-31", "2027-01-06"), "지난달")
	_check(not Daily.can_play(state, "2027-01-07", "2027-01-06"), "앞날")
	_check(not Daily.can_play(state, "2026-11-30", "2026-11-30") and not Daily.can_play(state, "x", "2027-01-06"), "기준일 전과 잘못된 날짜")
	return true


func _state() -> bool:
	var saved: Dictionary = Daily.default_state()
	_play(saved, "2027-01-01")
	_play(saved, "2027-01-02")
	var restored: Dictionary = Daily.state_from(JSON.parse_string(JSON.stringify(saved)))
	_check(restored == saved, "저장 뒤 읽으면 같은 상태다")
	_check(Daily.state_from({"results": {}, "streak": 2.0, "best": 3.0, "last": "2027-01-02"})["streak"] is int, "저장에서 읽은 숫자는 정수로 바꾼다")
	_check(Daily.state_from(null).is_empty() and Daily.state_from({"streak": 1}).is_empty(), "형식이 틀리면 빈 값")
	_check(Daily.state_from({"results": [], "streak": 0, "best": 0, "last": ""}).is_empty(), "결과가 사전이 아니면 빈 값")
	_check(Daily.state_from({"results": {}, "streak": -1, "best": 0, "last": ""}).is_empty(), "음수 기록은 빈 값")
	_check(Daily.state_from({"results": {}, "streak": 1, "best": 1, "last": "someday"}).is_empty(), "마지막 성공일이 날짜가 아니면 빈 값")
	_check(Daily.state_from({"results": {"someday": _summary(0)}, "streak": 0, "best": 0, "last": ""}).is_empty(), "결과의 열쇠가 날짜가 아니면 빈 값")
	_check(Daily.state_from({"results": {"2027-01-01": {"mistakes": 0}}, "streak": 0, "best": 0, "last": ""}).is_empty(), "결과 요약의 형식이 틀리면 빈 값")
	_check(restored["results"]["2027-01-01"]["seconds"] is int, "요약의 숫자도 정수로 바꾼다")
	return true
