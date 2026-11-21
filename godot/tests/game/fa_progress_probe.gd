extends SceneTree
## 제품 저장 모델 검사: 기본값, 저장 왕복, 버전 올림, 손상과 높은 버전 판별, 중복 지급 방지,
## 코인과 부스터, 스테이지 클리어, 도감, 출석, 날짜 변경.

const Progress := preload("res://game/core/domain/fa_progress.gd")
const Generator := preload("res://game/core/domain/fa_generator.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("기본값", _defaults)
	_section("저장 왕복", _roundtrip)
	_section("버전 올림", _upgrade)
	_section("손상과 높은 버전", _damaged)
	_section("보상 지급과 중복 방지", _grants)
	_section("코인과 부스터", _wallet)
	_section("테마", _themes)
	_section("스테이지 클리어", _journey)
	_section("진행 중인 판", _run)
	_section("일일 도전", _daily)
	_section("도감", _album)
	_section("출석", _attendance)
	_section("날짜 변경과 표시", _date_and_flags)
	print("Fa progress probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _defaults() -> bool:
	var progress: Progress = Progress.create()
	_check(Progress.VERSION == 1, "저장 버전은 1부터")
	_check(progress.to_dict() == {
		"version": 1,
		"profile": {"coins": 0, "boosters": {"hint": 0, "undo": 0, "slot": 0}, "themes": [], "selected": {}},
		"journey": {"stage": 1, "stars": {}, "recent": []},
		"run": {},
		"daily": Daily.default_state(),
		"album": {},
		"attendance": {"last": "", "day": 0},
		"ads": AdPolicy.default_state(),
		"flags": {},
		"grants": {},
	}, "새 저장의 기본값")
	_check(progress.coins() == 0 and progress.booster("hint") == 0 and progress.stage() == 1, "기본 조회값")
	_check(not progress.has_run() and progress.album_count() == 0 and not progress.flag("tutorial_done"), "빈 상태")
	var copy: Dictionary = progress.to_dict()
	copy["profile"]["coins"] = 999
	_check(progress.coins() == 0, "돌려준 사본을 고쳐도 저장은 그대로다")
	return true


func _board() -> Board:
	var board: Board = Board.create({
		"n": 3, "layout": "probe", "tier": 2, "f": 0.5,
		"groups": [{"cat": "A", "items": ["a1", "a2", "a3", "a4"]}, {"cat": "B", "items": ["b1", "b2", "b3", "b4"]}],
		"cols": [["a1", "b1", "a2"], ["b2", "a3", "b3"]],
		"reserve": ["a4", "b4"],
	}, Board.HOLD_SLOTS_BASE)
	board.hold("a2")
	board.submit(["b1", "b3", "a4", "b4"])
	return board


func _busy() -> Progress:
	var progress: Progress = Progress.create()
	progress.grant("starter_gift", {"coins": 200, "boosters": {"hint": 3, "undo": 3, "slot": 2}})
	progress.clear_stage(1, 3, ["fruits", "birds", "tools", "planets"])
	progress.clear_stage(2, 2, ["boats", "trees", "bakery", "weather"])
	progress.register_album("fruits", ["banana", "lemon", "grapes", "peach"])
	progress.record_daily_success("2026-12-01", "2026-12-01", {"mistakes": 1, "holds": 4, "seconds": 120, "order": ["a", "b", "c", "d"]})
	progress.claim_attendance("2026-12-01")
	progress.set_flag(Progress.FLAG_TUTORIAL_DONE, true)
	progress.buy_theme("card_back_mint", 50)
	progress.select_theme("card_back", "card_back_mint")
	progress.set_run("journey", 3, "", "", 42, _board())
	progress.roll_date("2026-12-01")
	AdPolicy.begin_session(progress.ads())
	AdPolicy.record_shown(progress.ads(), AdPolicy.default_config(), "rewarded_booster", 1800000000)
	return progress


func _roundtrip() -> bool:
	var progress: Progress = _busy()
	var saved: Dictionary = progress.to_dict()
	var loaded: Dictionary = Progress.read(JSON.parse_string(JSON.stringify(saved)))
	_check(loaded["status"] == "ok", "저장한 값을 읽는다")
	_check(loaded["progress"].to_dict() == saved, "읽은 저장은 쓴 저장과 같다")
	_check(JSON.stringify(loaded["progress"].to_dict()) == JSON.stringify(saved), "다시 써도 같은 글자다")
	_check(loaded["progress"].coins() == 170 and loaded["progress"].coins() is int, "코인은 정수로 돌아온다")
	_check(Progress.read(Progress.create().to_dict())["status"] == "ok", "기본 저장도 읽는다")
	return true


func _upgrade() -> bool:
	var add_hundred: Callable = func(data: Dictionary) -> Dictionary:
		data["journey"]["stage"] += 100
		return data
	var double: Callable = func(data: Dictionary) -> Dictionary:
		data["journey"]["stage"] *= 2
		return data
	var fail: Callable = func(_data: Dictionary) -> Dictionary:
		return {}
	var steps: Dictionary = {1: add_hundred, 2: double}
	var old: Dictionary = Progress.create().to_dict()
	var upgraded: Dictionary = Progress.upgrade(old, steps, 3)
	_check(upgraded.get("version") == 3 and upgraded["journey"]["stage"] == 202, "낮은 버전은 단계를 순서대로 밟아 올린다")
	_check(old["version"] == 1 and old["journey"]["stage"] == 1, "원본은 건드리지 않는다")
	_check(Progress.upgrade(old, {1: add_hundred}, 3).is_empty(), "중간 단계가 없으면 올리지 못한다")
	_check(Progress.upgrade(old, {1: fail}, 2).is_empty(), "단계가 실패하면 올리지 못한다")
	_check(Progress.upgrade(old, steps, 1) == old, "같은 버전은 그대로다")

	var ancient: Dictionary = Progress.create().to_dict()
	ancient["version"] = 0
	_check(Progress.read(ancient) == {"status": "corrupt", "progress": null}, "올릴 단계가 없는 낮은 버전은 손상으로 본다")
	return true


func _status_of(change: Callable) -> String:
	var data: Dictionary = _busy().to_dict()
	change.call(data)
	return Progress.read(data)["status"]


func _damaged() -> bool:
	_check(Progress.read(null) == {"status": "corrupt", "progress": null}, "값이 없으면 손상")
	_check(Progress.read("text")["status"] == "corrupt" and Progress.read([])["status"] == "corrupt" and Progress.read({})["status"] == "corrupt", "사전이 아니거나 비어 있으면 손상")
	_check(_status_of(func(data: Dictionary) -> void: data["version"] = 2) == "newer", "높은 버전")
	_check(_status_of(func(data: Dictionary) -> void: data["version"] = 2.0) == "newer", "JSON에서 읽은 높은 버전")
	_check(Progress.read({"version": 7})["status"] == "newer", "높은 버전은 내용을 보지 않고 판별한다")
	_check(_status_of(func(data: Dictionary) -> void: data["version"] = 1.5) == "corrupt", "정수가 아닌 버전")
	_check(_status_of(func(data: Dictionary) -> void: data["version"] = "1") == "corrupt", "글자 버전")
	_check(_status_of(func(data: Dictionary) -> void: data.erase("version")) == "corrupt", "버전 없음")
	for group: String in ["profile", "journey", "run", "daily", "album", "attendance", "ads", "flags", "grants"]:
		_check(_status_of(func(data: Dictionary) -> void: data.erase(group)) == "corrupt", group + " 묶음이 없으면 손상")
		_check(_status_of(func(data: Dictionary) -> void: data[group] = 5) == "corrupt", group + " 묶음의 형식이 틀리면 손상")
	_check(_status_of(func(data: Dictionary) -> void: data["profile"]["coins"] = -5) == "corrupt", "음수 코인")
	_check(_status_of(func(data: Dictionary) -> void: data["profile"]["coins"] = 10.5) == "corrupt", "정수가 아닌 코인")
	_check(_status_of(func(data: Dictionary) -> void: data["profile"]["boosters"].erase("undo")) == "corrupt", "부스터 개수 누락")
	_check(_status_of(func(data: Dictionary) -> void: data["profile"]["selected"] = {"card_back": "card_back_gold"}) == "corrupt", "갖지 않은 테마를 고른 저장")
	_check(_status_of(func(data: Dictionary) -> void: data["journey"]["stage"] = 0) == "corrupt", "스테이지 0")
	_check(_status_of(func(data: Dictionary) -> void: data["journey"]["stars"] = {"1": 4}) == "corrupt", "별 4개")
	_check(_status_of(func(data: Dictionary) -> void: data["journey"]["stars"] = {"one": 3}) == "corrupt", "스테이지 번호가 아닌 열쇠")
	_check(_status_of(func(data: Dictionary) -> void: data["run"]["mode"] = "arcade") == "corrupt", "없는 판 종류")
	_check(_status_of(func(data: Dictionary) -> void: data["run"].erase("board")) == "corrupt", "판 상태가 없는 진행 기록")
	_check(_status_of(func(data: Dictionary) -> void: data["run"]["board"]["mistakes"] = 9) == "corrupt", "판 상태가 틀린 진행 기록")
	_check(_status_of(func(data: Dictionary) -> void: data["run"]["stage"] = 0) == "corrupt", "스테이지가 없는 여정 판")
	_check(_status_of(func(data: Dictionary) -> void: data["run"].erase("started")) == "corrupt", "시작한 날 칸이 없는 진행 기록")
	_check(_status_of(func(data: Dictionary) -> void: data["run"]["started"] = "2026-12-01") == "corrupt", "여정 판에 시작한 날이 적힌 진행 기록")
	_check(_status_of(func(data: Dictionary) -> void: data["run"].merge({"mode": "daily", "date": "2026-12-01"}, true)) == "corrupt", "시작한 날이 없는 일일 도전 판")
	_check(_status_of(func(data: Dictionary) -> void: data["run"].merge({"mode": "daily", "date": "2026-12-01", "started": "2026-12-02"}, true)) == "ok", "시작한 날이 적힌 일일 도전 판")
	_check(_status_of(func(data: Dictionary) -> void: data["run"] = {}) == "ok", "진행 중인 판이 없는 저장")
	_check(_status_of(func(data: Dictionary) -> void: data["daily"]["streak"] = -1) == "corrupt", "일일 도전 상태 오류")
	_check(_status_of(func(data: Dictionary) -> void: data["album"]["fruits"] = "banana") == "corrupt", "도감 항목 오류")
	_check(_status_of(func(data: Dictionary) -> void: data["attendance"]["day"] = 7) == "corrupt", "출석 주기 범위 밖")
	_check(_status_of(func(data: Dictionary) -> void: data["attendance"]["last"] = "yesterday") == "corrupt", "출석 날짜 오류")
	_check(_status_of(func(data: Dictionary) -> void: data["ads"]["daily"] = []) == "corrupt", "광고 상태 오류")
	_check(_status_of(func(data: Dictionary) -> void: data["flags"]["tutorial_done"] = 1) == "corrupt", "표시 값 오류")
	_check(_status_of(func(data: Dictionary) -> void: data["grants"]["starter_gift"] = false) == "corrupt", "지급 기록 오류")
	_check(_status_of(func(data: Dictionary) -> void: data["extra"] = {"anything": 1}) == "ok", "모르는 묶음은 무시한다")
	return true


func _grants() -> bool:
	var progress: Progress = Progress.create()
	_check(not progress.has_grant("starter_gift"), "아직 받지 않은 보상")
	_check(progress.grant("starter_gift", {"coins": 200, "boosters": {"hint": 3, "undo": 3, "slot": 2}}), "보상을 준다")
	_check(progress.coins() == 200 and progress.booster("hint") == 3 and progress.booster("undo") == 3 and progress.booster("slot") == 2, "코인과 부스터가 늘어난다")
	_check(progress.has_grant("starter_gift"), "지급 기록이 남는다")
	_check(not progress.grant("starter_gift", {"coins": 200, "boosters": {"hint": 3}}), "같은 열쇠로는 다시 주지 않는다")
	_check(progress.coins() == 200 and progress.booster("hint") == 3, "두 번 받지 않는다")
	_check(progress.grant("album:fruits", {"coins": 5}) and progress.coins() == 205, "코인만 있는 보상")
	_check(progress.grant("attendance:2026-12-02", {"boosters": {"undo": 1}}) and progress.booster("undo") == 4 and progress.coins() == 205, "부스터만 있는 보상")
	_check(not progress.grant("", {"coins": 5}) and progress.coins() == 205, "열쇠 없이는 주지 않는다")
	_check(not progress.grant("bad", {"coins": -5}) and not progress.grant("bad", {"boosters": {"bomb": 1}}), "음수 코인이나 없는 부스터는 주지 않는다")
	_check(not progress.has_grant("bad") and progress.coins() == 205, "거부한 보상은 기록하지 않는다")
	_check(progress.add_reward({"coins": 5, "boosters": {"slot": 1}}) and progress.add_reward({"coins": 5, "boosters": {"slot": 1}}), "열쇠 없는 보상은 줄 때마다 더한다")
	_check(progress.coins() == 215 and progress.booster("slot") == 4, "더한 만큼 늘어난다")
	_check(not progress.add_reward({"boosters": {"bomb": 1}}) and not progress.add_reward({"coins": 1.5}) and progress.coins() == 215, "형식이 틀린 보상은 더하지 않는다")

	var reloaded: Progress = Progress.read(JSON.parse_string(JSON.stringify(progress.to_dict())))["progress"]
	_check(not reloaded.grant("starter_gift", {"coins": 200}) and reloaded.coins() == 215, "저장하고 다시 읽어도 두 번 받지 않는다")
	return true


func _wallet() -> bool:
	var progress: Progress = Progress.create()
	progress.grant("gift", {"coins": 250, "boosters": {"hint": 1}})
	_check(not progress.spend_coins(251) and progress.coins() == 250, "모자라면 쓰지 못한다")
	_check(progress.spend_coins(100) and progress.coins() == 150, "코인을 쓴다")
	_check(not progress.spend_coins(-1) and progress.coins() == 150, "음수는 쓰지 못한다")
	_check(progress.use_booster("hint") and progress.booster("hint") == 0, "부스터를 한 개 쓴다")
	_check(not progress.use_booster("hint") and progress.booster("hint") == 0, "없는 부스터는 쓰지 못한다")
	_check(not progress.use_booster("bomb") and progress.booster("bomb") == 0, "없는 종류")
	_check(progress.buy_booster("hint") and progress.coins() == 50 and progress.booster("hint") == 1, "힌트를 100코인에 산다")
	_check(not progress.buy_booster("undo") and progress.coins() == 50 and progress.booster("undo") == 0, "코인이 모자라면 사지 못한다")
	_check(not progress.buy_booster("bomb") and progress.coins() == 50, "없는 부스터는 사지 못한다")
	return true


func _themes() -> bool:
	var progress: Progress = Progress.create()
	progress.grant("gift", {"coins": 120})
	_check(not progress.owns_theme("table_night") and progress.selected_theme("table") == "", "처음에는 기본 테마")
	_check(not progress.select_theme("table", "table_night"), "갖지 않은 테마는 고르지 못한다")
	_check(not progress.buy_theme("table_night", 200) and progress.coins() == 120, "코인이 모자라면 사지 못한다")
	_check(progress.buy_theme("table_night", 100) and progress.coins() == 20 and progress.owns_theme("table_night"), "테마를 산다")
	_check(not progress.buy_theme("table_night", 10) and progress.coins() == 20, "가진 테마는 다시 사지 않는다")
	_check(progress.select_theme("table", "table_night") and progress.selected_theme("table") == "table_night", "가진 테마를 고른다")
	_check(progress.select_theme("table", "") and progress.selected_theme("table") == "", "기본 테마로 되돌린다")
	return true


func _journey() -> bool:
	var progress: Progress = Progress.create()
	_check(progress.best_stars(1) == 0 and progress.total_stars() == 0, "아직 깨지 않은 스테이지")
	_check(progress.clear_stage(1, 2, ["a", "b", "c", "d"]), "지금 풀 차례인 스테이지를 깨면 다음 스테이지가 열린다")
	_check(progress.stage() == 2 and progress.best_stars(1) == 2 and progress.total_stars() == 2, "현재 스테이지와 최고 별")
	_check(not progress.clear_stage(1, 3, ["a", "b", "c", "d"]), "이미 깬 스테이지는 첫 클리어가 아니다")
	_check(progress.best_stars(1) == 3 and progress.stage() == 2, "더 좋은 별로 고친다")
	_check(progress.clear_stage(2, 1, ["e", "f", "g", "h"]) and progress.total_stars() == 4, "모은 별은 스테이지별 최고 별의 합이다")
	progress.clear_stage(1, 1, ["a", "b", "c", "d"])
	_check(progress.best_stars(1) == 3, "더 낮은 별로는 고치지 않는다")
	_check(not progress.clear_stage(5, 3, ["a", "b", "c", "d"]) and progress.best_stars(5) == 0, "아직 열리지 않은 스테이지는 반영하지 않는다")
	_check(not progress.clear_stage(3, 0, []) and not progress.clear_stage(3, 4, []) and progress.stage() == 3, "별이 범위 밖이면 반영하지 않는다")

	progress = Progress.create()
	var window: int = Generator.JOURNEY_RECENT_LEVELS
	var kept: Array[String] = []
	for stage: int in range(1, window + 1):
		var cleared: Array[String] = ["s%d_a" % stage, "s%d_b" % stage, "s%d_c" % stage, "s%d_d" % stage]
		progress.clear_stage(stage, 3, cleared)
		kept.append_array(cleared)
	_check(progress.recent_categories() == kept, "최근 판들의 범주를 깬 순서대로 든다")
	var newest: Array[String] = ["n_a", "n_b", "n_c", "n_d"]
	progress.clear_stage(window + 1, 3, newest)
	_check(progress.recent_categories() == kept.slice(4) + newest, "오래된 판의 범주는 밀려난다")
	progress.clear_stage(2, 3, ["x1", "x2", "x3", "x4"])
	_check(progress.recent_categories().has("n_d") and not progress.recent_categories().has("x1"), "다시 깬 판은 최근 범주에 넣지 않는다")
	return true


func _run() -> bool:
	var progress: Progress = Progress.create()
	var board: Board = _board()
	_check(progress.run().is_empty() and not progress.has_run(), "진행 중인 판 없음")
	_check(progress.set_run("daily", 0, "2026-12-03", "2026-12-04", 15, board), "일일 도전 판을 기록한다")
	_check(progress.run() == {"mode": "daily", "stage": 0, "date": "2026-12-03", "started": "2026-12-04", "seconds": 15, "board": board.to_dict()} and progress.has_run(), "기록한 판")
	var copy: Dictionary = progress.run()
	copy["board"]["mistakes"] = 3
	_check(progress.run()["board"]["mistakes"] == 1, "돌려준 사본을 고쳐도 기록은 그대로다")
	board.hold("b1")
	_check(progress.run()["board"]["holds"] == ["a2", ""], "기록한 뒤 판이 바뀌어도 기록은 그대로다")
	_check(not progress.set_run("arcade", 1, "", "", 0, board) and progress.run()["mode"] == "daily", "없는 판 종류는 기록하지 않는다")
	_check(not progress.set_run("journey", 1, "", "", -4, board), "음수 시간은 기록하지 않는다")
	_check(not progress.set_run("journey", 0, "", "", 0, board) and not progress.set_run("daily", 0, "soon", "2026-12-04", 0, board), "스테이지나 날짜가 틀리면 기록하지 않는다")
	_check(not progress.set_run("daily", 0, "2026-12-03", "", 0, board) and not progress.set_run("daily", 0, "2026-12-03", "later", 0, board), "일일 도전 판은 시작한 날이 있어야 한다")
	_check(not progress.set_run("journey", 4, "", "2026-12-04", 0, board), "다른 판에는 시작한 날을 적지 않는다")
	_check(progress.set_run("journey", 4, "", "", 0, board) and progress.run()["stage"] == 4, "여정 판으로 바꿔 기록한다")
	_check(progress.set_run("tutorial", 0, "", "", 0, board) and progress.run()["mode"] == "tutorial", "튜토리얼 판")
	_check(progress.set_run("journey", 4, "", "", 10, board) and progress.update_run(_board(), 25), "진행 중인 판의 상태와 시간을 고친다")
	_check(progress.run() == {"mode": "journey", "stage": 4, "date": "", "started": "", "seconds": 25, "board": _board().to_dict()}, "판의 종류와 번호는 그대로다")
	_check(not progress.update_run(board, -1) and progress.run()["seconds"] == 25, "음수 시간으로는 고치지 않는다")
	progress.clear_run()
	_check(progress.run().is_empty() and not progress.has_run(), "판을 끝내면 기록을 지운다")
	_check(not progress.update_run(board, 5) and not progress.has_run(), "진행 중인 판이 없으면 고칠 것이 없다")
	return true


func _daily() -> bool:
	var progress: Progress = Progress.create()
	var summary: Dictionary = {"mistakes": 0, "holds": 6, "seconds": 80, "order": ["a", "b", "c", "d"]}
	_check(progress.can_play_daily("2026-12-01", "2026-12-01"), "오늘의 판")
	_check(progress.record_daily_success("2026-12-01", "2026-12-01", summary) == {"recorded": true, "counted": true, "streak": 1}, "성공을 기록한다")
	_check(progress.daily_result("2026-12-01") == summary and progress.daily_result("2026-12-02").is_empty(), "날짜별 결과")
	_check(not progress.can_play_daily("2026-12-01", "2026-12-01"), "성공한 날은 다시 하지 않는다")
	progress.record_daily_success("2026-12-02", "2026-12-02", summary)
	_check(progress.daily_streak("2026-12-02") == 2 and progress.daily_streak("2026-12-04") == 0 and progress.daily_best() == 2, "연속 기록과 최고 기록")
	return true


func _album() -> bool:
	var progress: Progress = Progress.create()
	_check(progress.register_album("fruits", ["banana", "lemon", "grapes", "peach"]), "새 범주를 등록한다")
	_check(progress.album_count() == 1 and progress.album_items("fruits") == ["banana", "lemon", "grapes", "peach"], "본 카드가 채워진다")
	_check(not progress.register_album("fruits", ["banana", "mango", "kiwi_fruit", "pear"]), "이미 있는 범주는 새 범주가 아니다")
	_check(progress.album_items("fruits") == ["banana", "lemon", "grapes", "peach", "mango", "kiwi_fruit", "pear"], "새로 본 카드만 더한다")
	_check(progress.register_album("birds", ["owl", "duck", "swan", "eagle"]) and progress.album_count() == 2, "범주 수")
	_check(progress.album_categories() == ["fruits", "birds"] and progress.album_items("tools").is_empty(), "등록한 범주 목록")

	progress = Progress.create()
	for index: int in 8:
		progress.register_album("seen%d" % index, ["x"])
	var board: Board = Board.create({
		"groups": [{"cat": "A", "items": ["a1", "a2", "a3", "a4"]}, {"cat": "B", "items": ["b1", "b2", "b3", "b4"]}],
		"cols": [["b1", "a1"], ["b2", "a2"]], "reserve": ["a3", "a4", "b3", "b4"],
	}, Board.HOLD_SLOTS_BASE)
	_check(progress.collect_album(board) == {"new": [], "coins": 0}, "완성한 범주가 없으면 도감에 넣을 것이 없다")
	board.submit(["a1", "a2", "a3", "a4"])
	_check(progress.collect_album(board) == {"new": ["A"], "coins": 5}, "완성한 범주를 등록하고 새 범주 코인 5를 준다")
	_check(progress.album_items("A") == ["a1", "a2", "a3", "a4"] and progress.coins() == 5 and progress.has_grant("album:A"), "그 판에서 본 카드와 지급 기록")
	_check(progress.collect_album(board) == {"new": [], "coins": 0} and progress.coins() == 5, "같은 범주로 다시 받지 않는다")
	board.submit(["b1", "b2", "b3", "b4"])
	_check(progress.collect_album(board) == {"new": ["B"], "coins": 55}, "10번째 범주에서는 달성 코인 50을 더 받는다")
	_check(progress.album_count() == 10 and progress.has_grant("album_count:10") and progress.coins() == 60, "달성 기록과 코인")
	return true


func _attendance() -> bool:
	var progress: Progress = Progress.create()
	_check(progress.can_claim_attendance("2026-12-01") and progress.attendance_day() == 0, "첫날")
	_check(progress.claim_attendance("2026-12-01") == {"coins": 20}, "1일째 20코인")
	_check(progress.coins() == 20 and progress.attendance_day() == 1, "보상을 받고 다음 날로 넘어간다")
	_check(not progress.can_claim_attendance("2026-12-01") and progress.claim_attendance("2026-12-01").is_empty() and progress.coins() == 20, "하루에 한 번")
	_check(not progress.can_claim_attendance("2026-11-30"), "날짜가 뒤로 가면 받지 못한다")
	_check(progress.claim_attendance("2026-12-02") == {"boosters": {"hint": 1}} and progress.booster("hint") == 1, "2일째 힌트 1")
	_check(progress.claim_attendance("2026-12-05") == {"coins": 30}, "며칠 건너뛰어도 주기는 이어진다")
	_check(progress.claim_attendance("2026-12-31") == {"boosters": {"undo": 1}}, "4일째 되돌리기 1")
	_check(progress.claim_attendance("2027-01-01") == {"coins": 40}, "연말을 넘어 5일째 40코인")
	_check(progress.claim_attendance("2027-01-02") == {"boosters": {"slot": 1}}, "6일째 칸 추가 1")
	_check(progress.claim_attendance("2027-01-03") == {"coins": 60} and progress.attendance_day() == 0, "7일째 60코인 뒤 처음으로")
	_check(progress.claim_attendance("2027-01-04") == {"coins": 20} and progress.coins() == 170, "다음 주기의 1일째")
	_check(progress.claim_attendance("someday").is_empty(), "잘못된 날짜는 받지 못한다")
	return true


func _date_and_flags() -> bool:
	var progress: Progress = Progress.create()
	_check(progress.roll_date("2026-12-01"), "첫 날짜")
	AdPolicy.record_shown(progress.ads(), AdPolicy.default_config(), "rewarded_booster", 1800000000)
	AdPolicy.add_play_seconds(progress.ads(), 300)
	_check(not progress.roll_date("2026-12-01") and progress.ads()["daily"] == {"rewarded_booster": 1}, "같은 날에는 일 횟수가 남는다")
	_check(progress.roll_date("2026-12-02") and progress.ads()["daily"].is_empty(), "날짜가 바뀌면 일 횟수만 0으로 돌린다")
	_check(progress.ads()["play_seconds"] == 300 and progress.ads()["last"]["rewarded_booster"] == 1800000000, "누적 플레이와 마지막 노출 시각은 남는다")
	_check(progress.to_dict()["ads"]["date"] == "2026-12-02", "광고 상태는 저장에 들어간다")

	_check(not progress.flag("intro_hint"), "표시의 기본값은 꺼짐")
	progress.set_flag("intro_hint", true)
	_check(progress.flag("intro_hint") and progress.to_dict()["flags"] == {"intro_hint": true}, "표시를 켠다")
	progress.set_flag("intro_hint", false)
	_check(not progress.flag("intro_hint"), "표시를 끈다")
	return true
