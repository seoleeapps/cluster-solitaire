extends SceneTree
## 유스케이스 검사: 저장 읽기와 복구, 판 시작과 복원(AC-012), 판 종료 정산(AC-006, AC-014, AC-015),
## 부스터 사용, 광고 판정과 보상 적용(AC-016, AC-017), 분석 이벤트. 포트는 메모리 안의 대역으로 바꿔 끼운다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AdsPort := preload("res://game/core/ports/fa_ads_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")
const ClockPort := preload("res://game/core/ports/fa_clock_port.gd")
const ConfigPort := preload("res://game/core/ports/fa_config_port.gd")
const LoadProgress := preload("res://game/core/use_cases/fa_load_progress.gd")
const StartRound := preload("res://game/core/use_cases/fa_start_round.gd")
const FinishRound := preload("res://game/core/use_cases/fa_finish_round.gd")
const UseBooster := preload("res://game/core/use_cases/fa_use_booster.gd")
const AdFlow := preload("res://game/core/use_cases/fa_ad_flow.gd")

const NOON := 1800000000


class MemoryStore extends StorePort:
	var slots: Dictionary = {}
	var writes: int = 0
	var writable: bool = true

	func read(slot: String) -> Dictionary:
		return {"found": slots.has(slot), "data": slots.get(slot)}

	func write(data: Dictionary) -> bool:
		if not writable:
			return false
		if slots.has(SLOT_MAIN):
			slots[SLOT_BACKUP] = slots[SLOT_MAIN]
		slots[SLOT_MAIN] = JSON.parse_string(JSON.stringify(data))
		writes += 1
		return true


class FakeAds extends AdsPort:
	var ready: Dictionary = {"rewarded": true, "interstitial": true}

	func is_ready(format: String) -> bool:
		return ready.get(format, false)


class FakeClock extends ClockPort:
	var now: int = NOON
	var date: String = "2026-12-10"

	func now_unix() -> int:
		return now

	func today() -> String:
		return date


class FakeConfig extends ConfigPort:
	var values: Dictionary = {}

	func value(key: String) -> Variant:
		return values.get(key)


class Recorder extends AnalyticsPort:
	var events: Array[Dictionary] = []

	func log_event(name: String, params: Dictionary) -> void:
		events.append({"name": name, "params": params})

	func count(name: String) -> int:
		return events.filter(func(event: Dictionary) -> bool: return event["name"] == name).size()

	func last(name: String) -> Dictionary:
		for index: int in range(events.size() - 1, -1, -1):
			if events[index]["name"] == name:
				return events[index]["params"]
		return {}


var _checks: int = 0
var _failed: PackedStringArray = []
var _store: MemoryStore
var _ads: FakeAds
var _clock: FakeClock
var _config: FakeConfig
var _analytics: Recorder


func _initialize() -> void:
	_section("포트 기본 구현", _port_defaults)
	_section("저장 읽기와 복구", _load_progress)
	_section("판 시작과 복원(AC-012)", _start_and_resume)
	_section("여정 판 정산(AC-006)", _finish_journey)
	_section("일일 도전 정산(AC-014)", _finish_daily)
	_section("일일 도전 7일 연속 보상", _daily_streak_reward)
	_section("튜토리얼 정산(AC-015)", _finish_tutorial)
	_section("도감 달성 보상", _album_rewards)
	_section("부스터 사용", _boosters)
	_section("광고 판정(AC-016)", _ad_checks)
	_section("광고 보상 적용(AC-017)", _ad_rewards)
	print("Fa round flow probe: %d checks, %d failed" % [_checks, _failed.size()])
	for line: String in _failed:
		print("  FAILED ", line)
	quit(0 if _failed.is_empty() else 1)


func _section(title: String, body: Callable) -> void:
	_store = MemoryStore.new()
	_ads = FakeAds.new()
	_clock = FakeClock.new()
	_config = FakeConfig.new()
	_analytics = Recorder.new()
	if body.call() != true:
		_failed.append(title + ": 끝까지 실행되지 않음")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


## 범주 4개, 열 2개짜리 작은 레벨. 임시 칸 이동 없이 A, B, C, D 순서로 묶을 수 있다.
func _level(number: int, prefix: String = "") -> Dictionary:
	var groups: Array = []
	for category: String in ["A", "B", "C", "D"]:
		var items: Array = []
		for index: int in range(1, 5):
			items.append("%s%s%d" % [prefix, category.to_lower(), index])
		groups.append({"cat": prefix + category, "items": items})
	var p: String = prefix
	return {
		"n": number, "layout": "probe", "tier": 1, "f": 1.0, "groups": groups,
		"cols": [[p + "d1", p + "c1", p + "b1", p + "a1"], [p + "d2", p + "c2", p + "b2", p + "a2"]],
		"reserve": [p + "a3", p + "a4", p + "b3", p + "b4", p + "c3", p + "c4", p + "d3", p + "d4"],
	}


func _win(board: Board) -> void:
	for category: String in board.categories():
		board.submit(board.group_items(category))


## 실수 4회로 판을 실패시킨다. prefix는 _level에 준 것과 같다.
func _fail(board: Board, prefix: String = "") -> void:
	for last: String in ["b3", "b4", "c3", "c4"]:
		board.submit([prefix + "a1", prefix + "a2", prefix + "a3", prefix + last])


func _starter() -> StartRound:
	return StartRound.new(_store, _analytics, _clock)


func _finisher() -> FinishRound:
	return FinishRound.new(_store, _analytics)


func _ad_flow() -> AdFlow:
	return AdFlow.new(_store, _ads, _clock, _config, _analytics)


func _port_defaults() -> bool:
	_check(StorePort.new().read("main") == {"found": false, "data": null} and not StorePort.new().write({}), "저장 포트의 기본 구현은 저장이 없다")
	var results: Array = []
	var ads: AdsPort = AdsPort.new()
	ads.request("rewarded")
	ads.show("rewarded", func(result: String) -> void: results.append(result))
	_check(not ads.is_ready("rewarded") and results == ["failed"], "광고 포트의 기본 구현은 준비되지 않고 보여 주기는 실패로 끝난다")
	_check(not ads.privacy_choice_required(), "개인정보 선택은 기본으로 필요 없다")
	ads.open_privacy_choice()
	AnalyticsPort.new().log_event("level_start", {})
	_check(ClockPort.new().now_unix() == 0 and ClockPort.new().today() == "", "시계 포트의 기본 구현")
	_check(ConfigPort.new().value("rewarded_booster_enabled") == null, "설정 포트의 기본 구현은 값이 없다")
	return true


func _load_progress() -> bool:
	var loader: LoadProgress = LoadProgress.new(_store)
	var loaded: Dictionary = loader.execute()
	_check(loaded["origin"] == "new" and not loaded["reset"] and loaded["progress"].coins() == 0, "저장이 없으면 새로 시작하고 알리지 않는다")

	var progress: Progress = loaded["progress"]
	progress.grant("gift", {"coins": 70})
	_store.write(progress.to_dict())
	progress.grant("more", {"coins": 5})
	_store.write(progress.to_dict())
	loaded = loader.execute()
	_check(loaded["origin"] == "main" and not loaded["reset"] and loaded["progress"].coins() == 75, "저장한 값을 읽는다")

	_store.slots["main"] = null
	loaded = loader.execute()
	_check(loaded["origin"] == "backup" and not loaded["reset"] and loaded["progress"].coins() == 70, "깨진 파일이면 직전 백업을 읽는다")

	var newer: Dictionary = progress.to_dict()
	newer["version"] = 99
	_store.slots["main"] = newer
	_check(loader.execute()["origin"] == "backup", "높은 버전이면 직전 백업을 읽는다")

	_store.slots["backup"] = {"version": 1, "profile": "broken"}
	loaded = loader.execute()
	_check(loaded["origin"] == "new" and loaded["reset"] and loaded["progress"].coins() == 0, "백업도 못 쓰면 새로 시작하고 그 사실을 알린다")
	_store.slots.erase("main")
	_check(loader.execute()["reset"], "백업만 있고 그것도 깨졌으면 알린다")
	return true


func _start_and_resume() -> bool:
	var progress: Progress = Progress.create()
	progress.grant("starter_gift", {"coins": 200, "boosters": {"hint": 3, "undo": 3, "slot": 2}})
	var starter: StartRound = _starter()
	_check(starter.resume(progress) == null, "진행 중인 판이 없으면 복원할 것이 없다")
	_check(starter.start(progress, "journey", 2, "", _level(2)) == null and not progress.has_run(), "아직 열리지 않은 스테이지는 시작하지 않는다")
	_check(starter.start(progress, "journey", 1, "", {"n": 1}) == null and not progress.has_run(), "형식이 틀린 레벨은 시작하지 않는다")

	var board: Board = starter.start(progress, "journey", 1, "", _level(1))
	_check(board != null and board.slot_count() == 2 and board.mistakes() == 0, "새 판은 임시 칸 2개로 시작한다")
	_check(progress.run()["mode"] == "journey" and progress.run()["stage"] == 1 and progress.run()["seconds"] == 0 and progress.run()["started"] == "", "진행 중인 판으로 기록한다")
	_check(_store.writes == 1 and _analytics.last("level_start") == {"mode": "journey", "level": 1, "tier": 1, "layout": "probe"}, "시작을 저장하고 알린다")

	board.submit(["a1", "a2", "a3", "b3"])
	board.submit(["a1", "a2", "a3", "a4"])
	board.hold("b1")
	board.unlock_slot()
	_check(starter.checkpoint(progress, board, 37) and _store.writes == 2, "판이 바뀔 때마다 저장한다")

	var reloaded: Progress = LoadProgress.new(_store).execute()["progress"]
	var restored: Board = starter.resume(reloaded)
	_check(restored != null and restored.to_dict() == board.to_dict(), "앱을 닫았다 열면 판이 같은 상태로 돌아온다")
	_check(restored.mistakes() == 1 and restored.solved() == ["A"] and restored.holds() == ["b1", "", ""], "카드 위치, 실수, 완성한 묶음이 그대로다")
	_check(reloaded.run()["seconds"] == 37 and reloaded.booster("hint") == 3 and reloaded.booster("slot") == 2 and reloaded.coins() == 200, "걸린 시간과 부스터 수가 그대로다")

	_store.writable = false
	_check(not starter.checkpoint(progress, board, 40), "저장에 실패하면 알린다")
	_store.writable = true
	_check(not starter.checkpoint(Progress.create(), board, 40), "진행 중인 판이 없으면 저장하지 않는다")

	_check(starter.abandon(progress) == {"new": ["A"], "coins": 5}, "버린 판에서 완성한 범주도 도감에 등록한다")
	_check(not progress.has_run() and starter.resume(progress) == null, "다시 하기나 나가기는 진행 중인 판을 지운다")
	_check(progress.album_items("A") == ["a1", "a2", "a3", "a4"] and progress.coins() == 205, "도감과 새 범주 코인")
	_check(_analytics.last("level_end") == {
		"mode": "journey", "level": 1, "tier": 1, "layout": "probe", "success": false, "stars": 0,
		"mistakes": 1, "holds": 1, "seconds": 40, "continue_used": false, "slot_unlocked": true,
	}, "끝내지 못한 판을 알린다")
	_check(_analytics.last("album_unlock") == {"category": "A"}, "도감에 새로 들어간 범주를 알린다")
	_check(_analytics.last("earn_virtual_currency") == {"virtual_currency_name": "coin", "value": 5, "source": "journey"}, "도감 코인을 알린다")
	_check(starter.abandon(progress) == {"new": [], "coins": 0} and _analytics.count("level_end") == 1, "진행 중인 판이 없으면 버릴 것이 없다")
	_check(LoadProgress.new(_store).execute()["progress"].run().is_empty(), "지운 것도 저장한다")
	_check(starter.start(progress, "journey", 1, "", _level(1)).slot_count() == 2, "다시 시작한 판에서는 3번째 칸이 다시 잠긴다")
	return true


func _finish_journey() -> bool:
	var progress: Progress = Progress.create()
	var starter: StartRound = _starter()
	var finisher: FinishRound = _finisher()
	var board: Board = starter.start(progress, "journey", 1, "", _level(1))
	_check(finisher.execute(progress, board, 60) == {"ok": false, "reason": "not_won"}, "끝나지 않은 판은 정산하지 않는다")
	board.submit(["a1", "a2", "a3", "b3"])
	_win(board)
	var result: Dictionary = finisher.execute(progress, board, 95)
	_check(result["ok"] and result["mode"] == "journey" and result["stars"] == 2 and result["mistakes"] == 1, "실수 1회는 별 2")
	_check(result["coins"] == 13 and result["first_clear"] and result["next_stage"] == 2, "별 2의 코인 13과 다음 스테이지")
	_check(result["album"] == {"new": ["A", "B", "C", "D"], "coins": 20}, "새 범주 4개의 도감 코인")
	_check(result["bonus"] == {"key": "stage_bonus:1", "coins": 13} and result["saved"], "광고를 보면 받을 2배 보상")
	_check(progress.coins() == 33 and progress.stage() == 2 and progress.best_stars(1) == 2, "코인, 스테이지, 최고 별이 반영된다")
	_check(not progress.has_run() and progress.ads()["rounds_since_interstitial"] == 1, "판을 지우고 끝난 판 수를 센다")
	_check(progress.album_items("A") == ["a1", "a2", "a3", "a4"] and progress.recent_categories() == ["A", "B", "C", "D"], "도감과 최근 범주")
	_check(_analytics.last("level_end") == {
		"mode": "journey", "level": 1, "tier": 1, "layout": "probe", "success": true, "stars": 2,
		"mistakes": 1, "holds": 0, "seconds": 95, "continue_used": false, "slot_unlocked": false,
	}, "판 종료를 알린다")
	_check(_analytics.last("earn_virtual_currency") == {"virtual_currency_name": "coin", "value": 33, "source": "journey"}, "코인 획득을 알린다")
	_check(_analytics.count("album_unlock") == 4 and _analytics.count("daily_complete") == 0, "새 범주 4개를 알린다")
	_check(LoadProgress.new(_store).execute()["progress"].coins() == 33, "정산을 저장한다")
	_check(finisher.execute(progress, board, 95) == {"ok": false, "reason": "no_run"} and progress.coins() == 33, "같은 판을 두 번 정산하지 않는다")

	board = starter.start(progress, "journey", 2, "", _level(2, "x"))
	_win(board)
	result = finisher.execute(progress, board, 30)
	_check(result["stars"] == 3 and result["coins"] == 16 and result["next_stage"] == 3 and progress.coins() == 33 + 16 + 20, "실수 0은 별 3과 코인 16")

	board = starter.start(progress, "journey", 1, "", _level(1))
	_win(board)
	result = finisher.execute(progress, board, 20)
	_check(result["ok"] and result["stars"] == 3 and result["coins"] == 0 and not result["first_clear"], "이미 깬 스테이지는 코인을 다시 주지 않는다")
	_check(result["bonus"].is_empty() and result["album"] == {"new": [], "coins": 0}, "다시 받을 보상이 없다")
	_check(progress.best_stars(1) == 3 and progress.stage() == 3 and progress.coins() == 69, "최고 별만 고친다")

	board = starter.start(progress, "journey", 3, "", _level(3, "y"))
	_fail(board, "y")
	board.apply_continue()
	_win(board)
	result = finisher.execute(progress, board, 200)
	_check(result["stars"] == 1 and result["coins"] == 10 and result["mistakes"] == 2, "이어하기를 쓴 판은 별 1과 코인 10")
	_check(_analytics.last("level_end")["continue_used"] and _analytics.last("level_end")["level"] == 3, "이어하기를 썼다고 알린다")

	board = Board.create(_level(9, "z"), Board.HOLD_SLOTS_BASE)
	progress.set_run("journey", 9, "", "", 0, board)
	_win(board)
	result = finisher.execute(progress, board, 5)
	_check(result["ok"] and not result["first_clear"] and result["coins"] == 0 and result["bonus"].is_empty(), "아직 열리지 않은 스테이지의 판은 코인을 주지 않는다")
	_check(progress.best_stars(9) == 0 and progress.stage() == 4, "그 스테이지는 깬 것으로 치지 않는다")
	return true


func _finish_daily() -> bool:
	var progress: Progress = Progress.create()
	progress.grant("gift", {"coins": 500, "boosters": {"hint": 2, "undo": 2, "slot": 2}})
	var starter: StartRound = _starter()
	var finisher: FinishRound = _finisher()
	_check(starter.start(progress, "daily", 0, "someday", _level(1)) == null, "잘못된 날짜로는 시작하지 않는다")
	_check(starter.start(progress, "daily", 0, "2026-12-11", _level(11)) == null, "앞날의 판은 시작하지 않는다")
	_check(starter.start(progress, "daily", 0, "2026-11-30", _level(1)) == null and not progress.has_run(), "지난달의 판은 시작하지 않는다")
	var board: Board = starter.start(progress, "daily", 0, "2026-12-10", _level(10))
	_check(board != null and progress.run()["started"] == "2026-12-10", "일일 도전 판을 시작하고 시작한 날을 남긴다")
	_check(_analytics.last("level_start") == {"mode": "daily", "level": 10, "tier": 1, "layout": "probe"}, "일일 도전은 도전 번호로 알린다")

	var booster: UseBooster = UseBooster.new(_store, _analytics)
	var flow: AdFlow = _ad_flow()
	flow.begin_session(progress)
	board.hold("a1")
	for id: String in ["hint", "undo", "slot"]:
		_check(booster.check(progress, board, id) == {"ok": false, "reason": "daily"}, id + ": 일일 도전에서는 부스터 버튼이 꺼진다")
		_check(booster.execute(progress, board, id, "coins") == {"ok": false, "reason": "daily"}, id + ": 일일 도전에서는 부스터를 쓸 수 없다")
	_check(progress.booster("hint") == 2 and progress.coins() == 500 and board.slot_count() == 2 and board.can_undo(), "부스터도 코인도 줄지 않는다")
	_check(flow.request(progress, "rewarded_continue", "daily") == {"ok": false, "reason": "daily_challenge"}, "일일 도전에서는 이어하기 광고가 없다")
	_check(flow.request(progress, "rewarded_booster", "daily")["reason"] == "daily_challenge", "일일 도전에서는 부스터 광고가 없다")
	var failed: Board = Board.create(_level(10), Board.HOLD_SLOTS_BASE)
	_fail(failed)
	_check(flow.request(progress, "rewarded_continue", "journey")["ok"], "판 종류를 잘못 넘기면 정책은 통과한다")
	_check(failed.is_failed() and not flow.finish_continue(progress, "earned", failed) and failed.is_failed(), "그래도 일일 도전 판은 이어 가지 못한다")

	board.submit(["a1", "a2", "a3", "b3"])
	_win(board)
	var result: Dictionary = finisher.execute(progress, board, 140)
	_check(result["ok"] and result["mode"] == "daily" and result["coins"] == 30 and result["stars"] == 2, "일일 도전 보상 30")
	_check(result["recorded"] and result["counted"] and result["streak"] == 1 and result["streak_coins"] == 0, "성공하면 연속 기록이 1 오른다")
	_check(result["bonus"] == {"key": "daily_bonus:2026-12-10", "coins": 30}, "일일 도전 보상도 광고로 2배")
	_check(progress.daily_result("2026-12-10") == {"mistakes": 1, "holds": 1, "seconds": 140, "order": ["A", "B", "C", "D"]}, "공유할 결과 요약을 남긴다")
	_check(progress.stage() == 1 and progress.recent_categories().is_empty(), "여정 진행은 그대로다")
	_check(progress.ads()["rounds_since_interstitial"] == 1 and not progress.has_run(), "끝난 판 수를 세고 판을 지운다")
	_check(_analytics.last("daily_complete") == {"streak": 1} and _analytics.last("level_end")["mode"] == "daily" and _analytics.last("level_end")["level"] == 10, "일일 도전 완료를 알린다")
	_check(starter.start(progress, "daily", 0, "2026-12-10", _level(10)) == null, "이미 성공한 날은 다시 시작하지 않는다")

	_clock.date = "2026-12-11"
	board = starter.start(progress, "daily", 0, "2026-12-11", _level(11, "x"))
	_clock.date = "2026-12-12"
	_win(board)
	result = finisher.execute(progress, board, 60)
	_check(result["recorded"] and result["counted"] and result["streak"] == 2, "자정을 넘겨 끝내도 시작한 날의 성공으로 연속 기록에 넣는다")
	board = starter.start(progress, "daily", 0, "2026-12-12", _level(12, "y"))
	_win(board)
	_check(finisher.execute(progress, board, 60)["streak"] == 3, "넘어간 날의 판도 성공하면 연속 기록이 이어진다")

	_clock.date = "2026-12-14"
	board = starter.start(progress, "daily", 0, "2026-12-13", _level(13, "z"))
	_check(board != null and progress.run()["started"] == "2026-12-14", "이번 달의 놓친 날은 시작할 수 있다")
	_win(board)
	result = finisher.execute(progress, board, 60)
	_check(result["recorded"] and not result["counted"] and result["streak"] == 0 and result["coins"] == 30, "놓친 날은 보상은 주되 연속 기록에 넣지 않는다")
	_check(progress.daily_best() == 3, "최고 연속 기록")
	return true


func _daily_streak_reward() -> bool:
	var progress: Progress = Progress.create()
	var starter: StartRound = _starter()
	var finisher: FinishRound = _finisher()
	var result: Dictionary = {}
	for day: int in range(1, 8):
		_clock.date = "2026-12-%02d" % day
		var board: Board = starter.start(progress, "daily", 0, _clock.date, _level(day))
		_win(board)
		result = finisher.execute(progress, board, 30)
		if day < 7:
			_check(result["streak"] == day and result["streak_coins"] == 0, "연속 %d일째에는 연속 기록 코인이 없다" % day)
	_check(result["streak"] == 7 and result["streak_coins"] == 100 and result["coins"] == 30, "7일 연속이면 코인 100을 더 받는다")
	_check(result["bonus"] == {"key": "daily_bonus:2026-12-07", "coins": 30}, "2배 광고는 그날의 코인 30에만 붙는다")
	_check(progress.has_grant("daily_streak:2026-12-07") and progress.coins() == 7 * 30 + 20 + 100, "지급 기록과 코인")
	_check(_analytics.last("earn_virtual_currency") == {"virtual_currency_name": "coin", "value": 130, "source": "daily"}, "연속 기록 코인을 함께 알린다")
	_check(_analytics.last("daily_complete") == {"streak": 7}, "연속 기록을 알린다")
	return true


func _finish_tutorial() -> bool:
	var progress: Progress = Progress.create()
	var starter: StartRound = _starter()
	var finisher: FinishRound = _finisher()
	var board: Board = starter.start(progress, "tutorial", 0, "", _level(0))
	_check(board != null and _analytics.count("tutorial_begin") == 1 and _analytics.count("level_start") == 0, "튜토리얼 판을 시작한다")
	_win(board)
	var result: Dictionary = finisher.execute(progress, board, 50)
	_check(result["ok"] and result["mode"] == "tutorial" and result["coins"] == 200 and result["gift"] == {"coins": 200, "boosters": {"hint": 3, "undo": 3, "slot": 2}}, "튜토리얼을 마치면 시작 선물을 받는다")
	_check(progress.coins() == 200 + 20 and progress.booster("hint") == 3 and progress.booster("undo") == 3 and progress.booster("slot") == 2, "코인 200과 부스터")
	_check(progress.flag("tutorial_done") and result["bonus"].is_empty(), "튜토리얼 완료를 표시하고 2배 광고는 없다")
	_check(progress.stage() == 1 and progress.ads()["rounds_since_interstitial"] == 0, "여정 진행과 전면 광고의 판 수에는 넣지 않는다")
	_check(_analytics.last("tutorial_complete") == {"seconds": 50} and _analytics.count("level_end") == 0, "튜토리얼 완료를 알린다")

	board = starter.start(progress, "tutorial", 0, "", _level(0))
	_win(board)
	result = finisher.execute(progress, board, 50)
	_check(result["ok"] and result["coins"] == 0 and result["gift"].is_empty() and progress.coins() == 220 and progress.booster("hint") == 3, "다시 해도 또 받지 않는다")
	var reloaded: Progress = LoadProgress.new(_store).execute()["progress"]
	_check(reloaded.flag("tutorial_done") and reloaded.has_grant("starter_gift"), "다시 실행해도 완료와 지급 기록이 남아 있다")
	return true


func _album_rewards() -> bool:
	var progress: Progress = Progress.create()
	for index: int in 8:
		progress.register_album("seen%d" % index, ["x"])
	var board: Board = _starter().start(progress, "journey", 1, "", _level(1))
	_win(board)
	var result: Dictionary = _finisher().execute(progress, board, 10)
	_check(result["album"] == {"new": ["A", "B", "C", "D"], "coins": 4 * 5 + 50}, "10번째 범주에서 달성 코인 50을 더 받는다")
	_check(progress.album_count() == 12 and progress.has_grant("album_count:10") and not progress.has_grant("album_count:20"), "달성 기록")
	_check(progress.coins() == 16 + 70, "판 코인과 도감 코인")
	return true


func _boosters() -> bool:
	var progress: Progress = Progress.create()
	progress.grant("gift", {"coins": 400, "boosters": {"hint": 1, "undo": 1, "slot": 0}})
	var starter: StartRound = _starter()
	var booster: UseBooster = UseBooster.new(_store, _analytics)
	var board: Board = Board.create(_level(1), Board.HOLD_SLOTS_BASE)
	_check(booster.execute(progress, board, "hint", "owned") == {"ok": false, "reason": "no_run"}, "진행 중인 판이 없으면 쓰지 못한다")
	_check(booster.check(progress, board, "hint") == {"ok": false, "reason": "no_run"}, "진행 중인 판이 없으면 버튼도 꺼진다")
	board = starter.start(progress, "journey", 1, "", _level(1))
	_check(booster.execute(progress, board, "bomb", "coins") == {"ok": false, "reason": "unknown"}, "없는 부스터")
	_check(booster.check(progress, board, "hint") == {"ok": true, "reason": ""} and booster.check(progress, board, "slot")["ok"], "쓸 수 있는 부스터를 미리 알 수 있다")
	_check(booster.check(progress, board, "undo") == {"ok": false, "reason": "no_effect"}, "되돌릴 것이 없으면 되돌리기 버튼이 꺼진다")
	_check(progress.booster("hint") == 1 and progress.coins() == 400 and _analytics.count("booster_used") == 0, "미리 알아보는 것은 아무것도 쓰지 않는다")

	var writes: int = _store.writes
	var result: Dictionary = booster.execute(progress, board, "hint", "owned")
	_check(result == {"ok": true, "booster": "hint", "source": "owned", "pair": ["a1", "a2"], "column": -1, "saved": true}, "힌트는 같은 범주 2장을 알려 준다")
	_check(progress.booster("hint") == 0 and _store.writes == writes + 1, "보유분을 쓰고 저장한다")
	_check(_analytics.last("booster_used") == {"mode": "journey", "level": 1, "tier": 1, "layout": "probe", "booster": "hint", "source": "owned"}, "부스터 사용을 알린다")
	_check(booster.execute(progress, board, "hint", "owned") == {"ok": false, "reason": "no_stock"} and progress.coins() == 400, "보유분이 없으면 묻지 않고 사지 않는다")
	_check(booster.execute(progress, board, "hint", "ad") == {"ok": false, "reason": "no_stock"}, "광고로 받은 것이 없으면 쓸 것이 없다")
	result = booster.execute(progress, board, "hint", "coins")
	_check(result["ok"] and result["source"] == "coins" and progress.coins() == 300 and progress.booster("hint") == 0, "코인 100으로 사서 바로 쓴다")
	_check(_analytics.last("spend_virtual_currency") == {"virtual_currency_name": "coin", "value": 100, "item_name": "hint"}, "코인 사용을 알린다")

	_check(booster.execute(progress, board, "undo", "owned") == {"ok": false, "reason": "no_effect"} and progress.booster("undo") == 1, "되돌릴 것이 없으면 쓰지 않는다")
	board.hold("a1")
	_check(booster.check(progress, board, "undo")["ok"], "옮긴 뒤에는 되돌리기 버튼이 켜진다")
	result = booster.execute(progress, board, "undo", "coins")
	_check(result == {"ok": true, "booster": "undo", "source": "owned", "card": "a1", "column": 0, "slot": 0, "closed": "b1", "saved": true}, "보유분이 있으면 코인으로 사라고 해도 보유분을 쓴다")
	_check(board.front_card(0) == "a1" and progress.booster("undo") == 0 and progress.coins() == 300, "판과 보유분이 바뀐다")
	_check(progress.run()["board"] == board.to_dict(), "바뀐 판을 진행 기록에 남긴다")

	result = booster.execute(progress, board, "slot", "coins")
	_check(result == {"ok": true, "booster": "slot", "source": "coins", "slots": 3, "saved": true} and board.slot_count() == 3 and progress.coins() == 150, "칸 추가를 코인 150으로 산다")
	_check(booster.execute(progress, board, "slot", "coins") == {"ok": false, "reason": "no_effect"} and progress.coins() == 150, "판당 1회")
	_check(booster.execute(progress, board, "undo", "coins") == {"ok": false, "reason": "no_effect"} and progress.coins() == 150, "효과가 없으면 코인을 쓰지 않는다")
	board.hold("a1")
	_check(booster.execute(progress, board, "undo", "coins")["source"] == "coins" and progress.coins() == 70, "되돌리기를 코인 80으로 산다")
	_check(booster.execute(progress, board, "hint", "coins") == {"ok": false, "reason": "no_coins"} and progress.coins() == 70, "코인이 모자라면 사지 못한다")

	var lonely: Dictionary = {
		"n": 1, "layout": "probe", "tier": 1, "f": 1.0,
		"groups": [{"cat": "A", "items": ["a1", "a2", "a3", "a4"]}, {"cat": "B", "items": ["b1", "b2", "b3", "b4"]}],
		"cols": [["a4", "a3", "a2", "a1"], ["b4", "b3", "b2", "b1"]], "reserve": [],
	}
	progress.grant("more", {"boosters": {"hint": 3}})
	board = starter.start(progress, "journey", 1, "", lonely)
	_check(booster.execute(progress, board, "hint", "owned") == {"ok": false, "reason": "no_effect"} and progress.booster("hint") == 3, "짝도 없고 임시 칸 2개로 풀 길도 없으면 힌트를 쓰지 않는다")
	board.unlock_slot()
	_check(booster.execute(progress, board, "hint", "owned") == {"ok": true, "booster": "hint", "source": "owned", "pair": [], "column": 0, "saved": true}, "짝이 없으면 다음에 옮길 열을 알려 준다")

	var buried: Dictionary = lonely.duplicate(true)
	buried["cols"] = [["b2", "a2", "a1"], ["a4", "a3", "b1"]]
	buried["reserve"] = ["b3", "b4"]
	board = starter.start(progress, "journey", 1, "", buried)
	board.hold("b1")
	board.submit(["b1", "b3", "b4", "a1"])
	result = booster.execute(progress, board, "hint", "owned")
	_check(result["ok"] and result["pair"] == ["b3", "b4"], "열린 카드에 짝이 있으면 짝을 알려 준다")
	for wrong: Array in [["a1", "a3", "b3", "b4"], ["a1", "a3", "b3", "b1"], ["a1", "a3", "b4", "b1"]]:
		board.submit(wrong)
	_check(board.is_failed() and booster.check(progress, board, "slot") == {"ok": false, "reason": "no_effect"}, "실패한 판에서는 칸 추가 버튼이 꺼진다")
	_check(booster.check(progress, board, "hint")["reason"] == "no_effect" and booster.check(progress, board, "undo")["reason"] == "no_effect", "실패한 판에서는 힌트와 되돌리기 버튼도 꺼진다")

	var solo: Dictionary = lonely.duplicate(true)
	solo["cols"] = [["a2", "b2", "a1"], ["b4", "a3", "b1"]]
	solo["reserve"] = ["a4", "b3"]
	board = starter.start(progress, "journey", 1, "", solo)
	board.submit(["a1", "a4", "b1", "b3"])
	result = booster.execute(progress, board, "hint", "owned")
	_check(result["ok"] and result["pair"] == ["a1", "a4"] and result["column"] == -1, "짝이 있는 동안은 옮길 열을 알려 주지 않는다")
	_check(booster.execute(progress, board, "hint", "owned") == {"ok": false, "reason": "no_stock"}, "보유분을 다 쓰면 힌트를 쓰지 못한다")
	return true


func _ad_checks() -> bool:
	var progress: Progress = Progress.create()
	var flow: AdFlow = _ad_flow()
	flow.begin_session(progress)
	_check(progress.ads()["session_no"] == 1 and progress.ads()["date"] == "2026-12-10" and _store.writes == 1, "실행을 시작하면 실행 번호와 날짜를 기록하고 저장한다")
	_check(flow.check(progress, "rewarded_booster", "journey") == {"ok": true, "reason": ""}, "보상형은 첫 실행부터 요청할 수 있다")
	_check(flow.check(progress, "interstitial_level_end", "journey")["reason"] == "first_session", "첫 실행에는 전면 광고를 요청하지 않는다")
	_check(flow.check(progress, "rewarded_booster", "tutorial")["reason"] == "tutorial", "튜토리얼에는 광고가 없다")
	_check(_analytics.events.is_empty(), "알아보기만 할 때는 이벤트를 남기지 않는다")

	flow.begin_session(progress)
	flow.add_play_time(progress, 200)
	_check(flow.check(progress, "interstitial_level_end", "journey")["reason"] == "rounds", "끝난 판이 2판이 안 되면 요청하지 않는다")
	for stage: int in [1, 2]:
		var board: Board = _starter().start(progress, "journey", stage, "", _level(stage, "s%d" % stage))
		_check(flow.check(progress, "interstitial_level_end", "journey")["reason"] == "rounds", "플레이 중에는 요청하지 않는다(스테이지 %d)" % stage)
		_win(board)
		_finisher().execute(progress, board, 30)
	_check(flow.check(progress, "interstitial_level_end", "journey") == {"ok": true, "reason": ""}, "조건을 채운 판 종료에서만 요청한다")
	_check(flow.check(progress, "interstitial_level_end", "daily")["reason"] == "daily_challenge", "일일 도전 결과 뒤에는 요청하지 않는다")

	_ads.ready["interstitial"] = false
	_check(flow.request(progress, "interstitial_level_end", "journey") == {"ok": false, "reason": "not_ready"}, "광고가 준비되지 않았으면 건너뛴다")
	_check(_analytics.last("ad_failed") == {"placement": "interstitial_level_end", "format": "interstitial", "reason": "not_ready"}, "준비되지 않은 광고를 알린다")
	_ads.ready["interstitial"] = true

	_config.values = {"interstitial_level_end_enabled": false}
	_check(flow.request(progress, "interstitial_level_end", "journey")["reason"] == "disabled" and _analytics.count("ad_requested") == 0, "원격 설정으로 배치를 끈다")
	_config.values = {}

	flow.finish_interstitial(progress, "dismissed")
	_check(not progress.ads()["daily"].has("interstitial_level_end") and _analytics.count("ad_impression") == 0, "요청하지 않은 광고의 결과는 기록하지 않는다")

	_check(flow.request(progress, "interstitial_level_end", "journey") == {"ok": true, "reason": ""}, "조건을 채웠으면 요청한다")
	_check(_analytics.last("ad_requested") == {"placement": "interstitial_level_end", "format": "interstitial"}, "광고 요청을 알린다")
	flow.finish_interstitial(progress, "failed")
	_check(not progress.ads()["daily"].has("interstitial_level_end") and _analytics.last("ad_failed")["reason"] == "show", "뜨지 못한 광고는 횟수에 넣지 않는다")
	_check(flow.request(progress, "interstitial_level_end", "journey")["ok"], "뜨지 못했으면 다시 요청할 수 있다")
	flow.finish_interstitial(progress, "dismissed")
	_check(progress.ads()["rounds_since_interstitial"] == 0 and progress.ads()["last"]["interstitial_level_end"] == NOON, "전면 광고가 뜨면 기록한다")
	_check(progress.ads()["daily"]["interstitial_level_end"] == 1 and progress.ads()["declined_at"] == 0, "노출 횟수를 세고 거절로는 치지 않는다")
	_check(_analytics.last("ad_impression") == {"placement": "interstitial_level_end", "format": "interstitial"}, "광고 노출을 알린다")
	_check(_analytics.count("ad_declined") == 0 and _analytics.count("rewarded_earned") == 0, "전면 광고는 보상이나 거절을 알리지 않는다")
	flow.finish_interstitial(progress, "dismissed")
	_check(progress.ads()["daily"]["interstitial_level_end"] == 1 and _analytics.count("ad_impression") == 1, "같은 광고의 결과가 두 번 와도 한 번만 기록한다")
	_check(flow.request(progress, "interstitial_level_end", "journey")["reason"] == "cooldown", "바로 다시 요청하지 않는다")

	_clock.date = "2026-12-11"
	_clock.now = NOON + 86400
	_check(flow.check(progress, "interstitial_level_end", "journey")["reason"] == "rounds" and progress.ads()["daily"].is_empty(), "날짜가 바뀌면 판정 전에 일 횟수를 0으로 돌린다")
	return true


func _ad_rewards() -> bool:
	_config.values = {
		"rewarded_booster_cooldown_s": 0, "rewarded_booster_session_cap": 4, "rewarded_booster_daily_cap": 10,
		"rewarded_continue_cooldown_s": 0, "rewarded_continue_session_cap": 2, "rewarded_continue_daily_cap": 4,
		"rewarded_result_bonus_cooldown_s": 0, "rewarded_result_bonus_session_cap": 2, "rewarded_result_bonus_daily_cap": 6,
	}
	var progress: Progress = Progress.create()
	var flow: AdFlow = _ad_flow()
	flow.begin_session(progress)
	_check(not flow.finish_booster(progress, "earned", "hint") and progress.booster("hint") == 0 and progress.ads()["daily"].is_empty(), "요청하지 않은 광고의 보상은 주지 않는다")

	flow.request(progress, "rewarded_booster", "journey")
	_check(not flow.finish_booster(progress, "dismissed", "hint") and progress.booster("hint") == 0, "중간에 닫으면 보상이 없다")
	_check(progress.ads()["daily"]["rewarded_booster"] == 1 and progress.ads()["declined_at"] == NOON, "닫은 광고도 노출로 세고 거절 시각을 남긴다")
	_check(_analytics.last("ad_declined") == {"placement": "rewarded_booster", "format": "rewarded", "reason": "dismissed"}, "중간에 닫은 것을 알린다")

	flow.request(progress, "rewarded_booster", "journey")
	_check(not flow.finish_booster(progress, "failed", "hint") and progress.booster("hint") == 0 and progress.ads()["daily"]["rewarded_booster"] == 1, "광고가 뜨지 못하면 보상도 기록도 없다")

	flow.request(progress, "rewarded_booster", "journey")
	_check(flow.finish_booster(progress, "earned", "hint") and progress.booster("hint") == 1, "끝까지 보면 부스터 1개를 받는다")
	_check(progress.ads()["rewarded_at"] == NOON and progress.ads()["daily"]["rewarded_booster"] == 2, "보상형 노출을 기록한다")
	_check(_analytics.last("rewarded_earned") == {"placement": "rewarded_booster", "format": "rewarded"}, "보상을 알린다")
	_check(not flow.finish_booster(progress, "earned", "hint") and progress.booster("hint") == 1, "결과가 두 번 와도 보상은 한 번이다")

	flow.request(progress, "rewarded_booster", "journey")
	_check(not flow.finish_booster(progress, "earned", "bomb") and progress.booster("bomb") == 0, "없는 부스터는 주지 않는다")

	var board: Board = _starter().start(progress, "journey", 1, "", _level(1))
	var booster: UseBooster = UseBooster.new(_store, _analytics)
	var used: Dictionary = booster.execute(progress, board, "hint", "ad")
	_check(used["ok"] and used["source"] == "ad" and progress.booster("hint") == 0, "광고로 받은 부스터를 쓴다")
	_check(_analytics.last("booster_used")["source"] == "ad", "출처를 광고로 알린다")

	flow.request(progress, "rewarded_booster", "journey")
	flow.finish_booster(progress, "dismissed", "slot")
	_check(flow.request(progress, "rewarded_booster", "journey")["reason"] == "session_cap", "한 번 실행의 상한에 닿으면 요청하지 않는다")
	progress.grant("gift", {"coins": 150})
	_check(booster.execute(progress, board, "slot", "coins")["source"] == "coins" and board.slot_count() == 3, "광고 상한에 닿아도 코인으로 같은 것을 얻는다")

	_fail(board)
	_check(board.is_failed() and flow.check(progress, "rewarded_continue", "journey")["ok"], "실패한 판에서 이어하기 광고를 요청할 수 있다")
	flow.request(progress, "rewarded_continue", "journey")
	_check(not flow.finish_continue(progress, "dismissed", board) and board.is_failed(), "이어하기 광고를 닫으면 판은 그대로다")
	flow.request(progress, "rewarded_continue", "journey")
	_check(flow.finish_continue(progress, "earned", board) and board.mistakes() == 2 and not board.is_failed(), "끝까지 보면 실수가 2로 돌아간다")
	_check(progress.run()["board"]["mistakes"] == 2 and progress.run()["board"]["continued"], "이어 간 판을 진행 기록에 남긴다")
	board.submit(["a1", "a2", "b3", "b4"])
	board.submit(["a1", "a2", "c3", "c4"])
	_check(board.is_failed() and not board.can_continue(), "두 번째 실패에는 이어하기가 없다")
	_check(flow.request(progress, "rewarded_continue", "journey")["reason"] == "session_cap", "이어하기 광고도 실행 상한을 지킨다")
	flow.begin_session(progress)
	flow.request(progress, "rewarded_continue", "journey")
	_check(not flow.finish_continue(progress, "earned", board) and board.is_failed() and board.mistakes() == 4, "광고를 다시 봐도 같은 판은 한 번만 이어 간다")

	progress = Progress.create()
	flow.begin_session(progress)
	board = _starter().start(progress, "journey", 1, "", _level(1))
	_win(board)
	var result: Dictionary = _finisher().execute(progress, board, 30)
	var coins: int = progress.coins()
	flow.request(progress, "rewarded_result_bonus", "journey")
	_check(not flow.finish_bonus(progress, "earned", {}) and progress.coins() == coins, "받을 2배가 없으면 주지 않는다")
	flow.request(progress, "rewarded_result_bonus", "journey")
	_check(not flow.finish_bonus(progress, "dismissed", result["bonus"]) and progress.coins() == coins, "결과 광고를 닫으면 2배가 없다")
	flow.begin_session(progress)
	flow.request(progress, "rewarded_result_bonus", "journey")
	_check(flow.finish_bonus(progress, "earned", result["bonus"]) and progress.coins() == coins + 16, "끝까지 보면 그 판의 코인을 한 번 더 받는다")
	_check(_analytics.last("earn_virtual_currency") == {"virtual_currency_name": "coin", "value": 16, "source": "rewarded_result_bonus"}, "광고 보상 코인을 알린다")
	flow.request(progress, "rewarded_result_bonus", "journey")
	_check(not flow.finish_bonus(progress, "earned", result["bonus"]) and progress.coins() == coins + 16, "같은 판의 2배는 한 번뿐이다")

	_clock.now = NOON + 50
	flow.decline(progress, "rewarded_result_bonus")
	_check(progress.ads()["declined_at"] == NOON + 50, "보상형 제안을 거절한 시각을 남긴다")
	_check(_analytics.last("ad_declined") == {"placement": "rewarded_result_bonus", "format": "rewarded", "reason": "offer"}, "제안을 거절한 것을 알린다")
	_check(LoadProgress.new(_store).execute()["progress"].ads()["declined_at"] == NOON + 50, "광고 상태를 저장한다")
	return true
