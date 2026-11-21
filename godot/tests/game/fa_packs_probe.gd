extends SceneTree
## 레벨 팩 검사: 실은 팩의 모든 판(AC-013)을 GDScript 탐색기로 다시 확인하고, 전부 다시 생성해 대조하며,
## 스테이지와 날짜에서 레벨을 찾는 유스케이스를 검사한다. Python 대조는 tools/levels/verify_packs.py가 맡는다.

const Content := preload("res://game/core/domain/fa_content.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Generator := preload("res://game/core/domain/fa_generator.gd")
const PickLevel := preload("res://game/core/use_cases/fa_pick_level.gd")

const JOURNEY_SIZE := 600
const DAILY_SIZE := 1100

var _checks: int = 0
var _failed: PackedStringArray = []
var _content: Content
var _journey: Dictionary
var _daily: Dictionary


func _initialize() -> void:
	_content = Content.new(_read("res://data/content/items.json"), _read("res://data/content/categories.json"))
	_journey = _read("res://data/levels/journey.json")
	_daily = _read("res://data/levels/daily.json")
	_section("팩 머리말", _headers)
	_section("여정 팩의 모든 판", _journey_levels)
	_section("일일 도전 팩의 모든 판", _daily_levels)
	_section("다시 생성해 대조", _regeneration)
	_section("레벨 찾기", _pick_level)
	print("Fa packs probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _headers() -> bool:
	for pack: Dictionary in [_journey, _daily]:
		_check(pack.get("version") == PickLevel.PACK_VERSION, "팩 형식 버전")
		_check(pack.get("content_version") == _content.version(), "팩의 콘텐츠 버전은 실은 콘텐츠와 같다")
		_check(pack.get("generator") == Generator.VERSION, "팩의 생성기 버전")
	_check(_journey.get("levels", []).size() == JOURNEY_SIZE, "여정 600판")
	_check(_daily.get("levels", []).size() == DAILY_SIZE, "일일 도전 1,100판")
	return true


func _categories_of(level: Dictionary) -> Array:
	var categories: Array = []
	for group: Dictionary in level["groups"]:
		categories.append(group["cat"])
	return categories


## 한 판이 어긴 조건의 이름. 없으면 빈 문자열.
func _problem(level: Dictionary, number: int, tier: int, recent: Array) -> String:
	if level.get("n") != number or level.get("tier") != tier:
		return "번호 또는 등급"
	var rule: Dictionary = Difficulty.tier_rule(tier)
	var layout: Dictionary = Difficulty.layout(level.get("layout", ""))
	if not rule["layouts"].has(level.get("layout")):
		return "배치"
	var board: Board = Board.create(level, Board.HOLD_SLOTS_BASE)
	if board == null:
		return "레벨 형식"
	for column: int in board.column_count():
		if board.column_size(column) != layout["columns"][column]:
			return "열별 장수"
	if board.reserve().size() != layout["reserve"] or board.categories().size() != layout["groups"]:
		return "예비 카드 수 또는 범주 수"
	var cards: Array = []
	var domains: Dictionary = {}
	for category: String in board.categories():
		if recent.has(category):
			return "최근 범주 재사용"
		if _content.category_tier(category) < 1 or _content.category_tier(category) > rule["category_tier_max"]:
			return "범주 난도"
		domains[_content.category_domain(category)] = domains.get(_content.category_domain(category), 0) + 1
		for item: String in board.group_items(category):
			if not _content.category_members(category).has(item):
				return "소속이 아닌 카드"
			cards.append(item)
	if domains.values().max() > rule["domain_max"]:
		return "대분류"
	if Generator.count_groupings(_content, board.categories(), cards, 2) != 1:
		return "묶는 방법이 하나가 아님"
	var solved: Dictionary = Solver.solve_board(board, Board.HOLD_SLOTS_BASE)
	if not solved["solvable"]:
		return "임시 칸 2개로 풀리지 않음"
	if solved["forgiveness"] < rule["f_min"] or solved["forgiveness"] > rule["f_max"]:
		return "관대함 범위"
	if absf(level["f"] - solved["forgiveness"]) > 0.005 + 1e-9:
		return "관대함 값"
	return ""


func _scan(pack: Dictionary, recent_levels: int, tier_of: Callable) -> PackedStringArray:
	var problems: PackedStringArray = []
	var history: Array[Array] = []
	var levels: Array = pack.get("levels", [])
	for index: int in levels.size():
		var recent: Array = []
		for categories: Array in history:
			recent.append_array(categories)
		var level: Dictionary = _whole_numbers(levels[index])
		var problem: String = _problem(level, index + 1, tier_of.call(index + 1), recent)
		if not problem.is_empty():
			problems.append("%d번: %s" % [index + 1, problem])
			continue
		history.append(_categories_of(level))
		if history.size() > recent_levels:
			history.pop_front()
	return problems


## JSON에서 읽은 번호와 등급은 실수라서 정수로 바꿔 비교한다.
func _whole_numbers(level: Dictionary) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	copy["n"] = int(level.get("n", 0))
	copy["tier"] = int(level.get("tier", 0))
	return copy


func _journey_levels() -> bool:
	var problems: PackedStringArray = _scan(_journey, Generator.JOURNEY_RECENT_LEVELS, Difficulty.journey_tier)
	_check(problems.is_empty(), "여정 팩의 문제 %d건: %s" % [problems.size(), ", ".join(problems.slice(0, 5))])
	return true


func _daily_tier(number: int) -> int:
	return Difficulty.daily_tier(Daily.weekday(Daily.challenge_date(number)))


func _daily_levels() -> bool:
	var problems: PackedStringArray = _scan(_daily, Generator.DAILY_RECENT_LEVELS, _daily_tier)
	_check(problems.is_empty(), "일일 도전 팩의 문제 %d건: %s" % [problems.size(), ", ".join(problems.slice(0, 5))])
	return true


func _regenerated(make: Callable, count: int, recent_levels: int) -> Array:
	var lines: Array = []
	var history: Array[Array] = []
	for number: int in range(1, count + 1):
		var recent: Array = []
		for categories: Array in history:
			recent.append_array(categories)
		var result: Dictionary = make.call(_content, number, recent)
		if not result["ok"]:
			break
		history.append(_categories_of(result["level"]))
		if history.size() > recent_levels:
			history.pop_front()
		lines.append(JSON.stringify(result["level"], "", false))
	return lines


## 팩 파일은 머리말 한 줄, 판마다 한 줄, 닫는 줄로 이뤄진다. 판의 줄만 쉼표를 떼고 돌려준다.
func _pack_lines(path: String, count: int) -> Array:
	return Array(FileAccess.get_file_as_string(path).split("\n")).slice(1, count + 1).map(
		func(line: String) -> String: return line.trim_suffix(","))


func _regeneration() -> bool:
	var journey: Array = _regenerated(Generator.journey_level, JOURNEY_SIZE, Generator.JOURNEY_RECENT_LEVELS)
	_check(journey.size() == JOURNEY_SIZE and journey == _pack_lines("res://data/levels/journey.json", JOURNEY_SIZE), "여정 600판을 다시 만들면 팩과 글자까지 같다")
	var daily: Array = _regenerated(Generator.daily_level, DAILY_SIZE, Generator.DAILY_RECENT_LEVELS)
	_check(daily.size() == DAILY_SIZE and daily == _pack_lines("res://data/levels/daily.json", DAILY_SIZE), "일일 도전 1,100판을 다시 만들면 팩과 글자까지 같다")
	return true


func _pick_level() -> bool:
	var pick: PickLevel = PickLevel.new(_content, _journey, _daily)
	_check(pick.problems().is_empty(), "실은 팩에 문제가 없다: " + ", ".join(pick.problems()))
	_check(pick.journey_size() == JOURNEY_SIZE and pick.daily_size() == DAILY_SIZE, "팩 길이")

	var first: Dictionary = pick.journey(1, [])
	_check(first["ok"] and first["level"]["n"] == 1 and first["level"]["tier"] == 1 and first["level"]["layout"] == "open", "스테이지 1은 팩의 첫 판")
	_check(first["level"]["n"] is int and first["level"]["tier"] is int, "번호와 등급은 정수로 돌려준다")
	_check(Board.create(first["level"], Board.HOLD_SLOTS_BASE) != null, "팩의 레벨로 판을 시작할 수 있다")
	first["level"]["groups"].clear()
	_check(pick.journey(1, [])["level"]["groups"].size() == 4, "돌려준 레벨을 고쳐도 팩은 그대로다")
	_check(pick.journey(600, [])["level"]["n"] == 600, "팩의 마지막 스테이지")
	_check(pick.journey(0, []) == {"ok": false, "error": "bad_stage"}, "스테이지 0은 오류")

	var avoided: Array = Array(_content.category_ids()).slice(0, 12)
	var beyond: Dictionary = pick.journey(601, avoided)
	_check(beyond.keys() == ["ok", "level"] and beyond["ok"] and beyond["level"]["n"] == 601, "팩을 넘는 스테이지는 생성기로 만든다")
	_check(JSON.stringify(beyond["level"]) == JSON.stringify(Generator.journey_level(_content, 601, avoided)["level"]), "생성기에 스테이지 번호와 최근 범주를 그대로 넘긴다")
	for group: Dictionary in beyond["level"]["groups"]:
		_check(not avoided.has(group["cat"]), "피하라고 한 범주 %s는 쓰지 않는다" % group["cat"])
	var everything: Array = Array(_content.category_ids())
	_check(not Generator.journey_level(_content, 601, everything)["ok"], "모든 범주를 피하면 생성기는 만들지 못한다")
	_check(JSON.stringify(pick.journey(601, everything)["level"]) == JSON.stringify(Generator.journey_level(_content, 601, [])["level"]), "피할 범주 때문에 못 만들면 그 조건 없이 다시 만든다")

	var base: Dictionary = pick.daily("2026-12-01")
	_check(base["ok"] and base["number"] == 1 and base["level"]["n"] == 1 and base["level"]["tier"] == 3, "기준일은 일일 도전 1번")
	_check(pick.daily("2026-12-05")["level"]["tier"] == 4, "토요일은 T4")
	_check(JSON.stringify(pick.daily("2027-03-15")) == JSON.stringify(pick.daily("2027-03-15")), "같은 날짜에는 같은 판")
	var last: Dictionary = pick.daily("2029-12-04")
	_check(last["number"] == 1100 and last["level"]["n"] == 1100, "팩의 마지막 날")
	var wrapped: Dictionary = pick.daily("2029-12-05")
	_check(wrapped["number"] == 1101 and wrapped["level"]["n"] == 1, "팩 길이를 넘으면 처음으로 돌아간다")
	_check(pick.daily("2026-11-30") == {"ok": false, "error": "bad_date"} and pick.daily("soon")["error"] == "bad_date", "기준일 전과 잘못된 날짜는 오류")

	var broken: PickLevel = PickLevel.new(_content, {"version": 9, "levels": []}, {})
	_check(Array(broken.problems()) == ["bad_pack: journey", "bad_pack: daily"], "형식이 틀린 팩을 알린다")
	_check(broken.journey_size() == 0 and broken.daily_size() == 0, "형식이 틀린 팩은 쓰지 않는다")
	_check(broken.journey(1, [])["ok"] and broken.journey(1, [])["level"]["n"] == 1, "여정 팩이 없으면 첫 스테이지부터 생성한다")
	_check(broken.daily("2026-12-01") == {"ok": false, "error": "no_pack"}, "일일 도전 팩이 없으면 오류")
	var stale: Dictionary = _journey.duplicate()
	stale["content_version"] = _content.version() + 1
	_check(Array(PickLevel.new(_content, stale, _daily).problems()) == ["bad_pack: journey"], "콘텐츠 판 번호가 다른 팩을 알린다")
	return true
