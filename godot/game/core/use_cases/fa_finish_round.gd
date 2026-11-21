class_name FaFinishRound
extends RefCounted
## 끝낸 판을 정산한다. 별과 코인, 도감, 다음 스테이지, 일일 도전 기록을 한 번에 반영하고 저장한 뒤 결과를 돌려준다.
## 저장이 화면 반영보다 먼저라서 같은 보상을 두 번 받지 않는다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")
const ClockPort := preload("res://game/core/ports/fa_clock_port.gd")

const COIN := "coin"

var _store: StorePort
var _analytics: AnalyticsPort
var _clock: ClockPort


func _init(store: StorePort, analytics: AnalyticsPort, clock: ClockPort) -> void:
	_store = store
	_analytics = analytics
	_clock = clock


## 진행 중인 판이 board로 끝났을 때 부른다. seconds는 이 판에 쓴 시간이다.
## 정산하지 못하면 {ok: false, reason}이고 reason은 no_run 또는 not_won이다.
## 정산하면 {ok: true, mode, stars, mistakes, coins, bonus, album, saved}에 판의 종류별 값이 붙는다.
##   coins: 이 판으로 받은 코인(도감 코인 제외). bonus: 결과 광고를 끝까지 보면 더 받을 {key, coins}, 없으면 빈 값.
##   album: {new: 새로 등록한 범주, coins: 도감으로 받은 코인}. saved: 저장했는지.
##   여정: first_clear, next_stage. 일일 도전: recorded, counted, streak. 튜토리얼: gift(받은 시작 선물, 없으면 빈 값).
func execute(progress: Progress, board: Board, seconds: int) -> Dictionary:
	if not progress.has_run():
		return {"ok": false, "reason": "no_run"}
	if not board.is_won():
		return {"ok": false, "reason": "not_won"}
	var run: Dictionary = progress.run()
	var mode: String = run["mode"]
	var result: Dictionary = {
		"ok": true, "mode": mode, "stars": Economy.stars(board.mistakes(), board.continue_used()),
		"mistakes": board.mistakes(), "coins": 0, "bonus": {},
	}
	match mode:
		RoundMode.JOURNEY:
			_settle_journey(progress, board, run["stage"], result)
		RoundMode.DAILY:
			_settle_daily(progress, board, run["date"], seconds, result)
		RoundMode.TUTORIAL:
			_settle_tutorial(progress, result)
	result["album"] = _register_album(progress, board)
	if mode != RoundMode.TUTORIAL:
		AdPolicy.record_round_end(progress.ads())
	progress.clear_run()
	result["saved"] = _store.write(progress.to_dict())

	_analytics.log_event("level_end", {
		"level_name": RoundMode.level_name(mode, run["stage"], run["date"]), "mode": mode, "success": true,
		"stars": result["stars"], "mistakes": result["mistakes"], "seconds": seconds, "holds": board.hold_moves(),
	})
	var earned: int = result["coins"] + result["album"]["coins"]
	if earned > 0:
		_analytics.log_event("earn_virtual_currency", {"virtual_currency_name": COIN, "value": earned, "source": mode})
	return result


## 스테이지 코인은 처음 깼을 때만 준다.
func _settle_journey(progress: Progress, board: Board, stage: int, result: Dictionary) -> void:
	result["first_clear"] = progress.clear_stage(stage, result["stars"], board.categories())
	_pay_round(progress, "stage", str(stage), Economy.stage_reward(result["stars"]), result)
	result["next_stage"] = progress.stage()


## 일일 도전 코인은 그 날짜를 처음 성공했을 때만 준다. 지난 날짜도 받지만 연속 기록에는 넣지 않는다.
func _settle_daily(progress: Progress, board: Board, date: String, seconds: int, result: Dictionary) -> void:
	var record: Dictionary = progress.record_daily_success(date, _clock.today(), {
		"mistakes": board.mistakes(), "holds": board.hold_moves(), "seconds": seconds, "order": board.solved(),
	})
	result.merge(record)
	if record["recorded"]:
		_pay_round(progress, "daily", date, Economy.DAILY_REWARD, result)


## 시작 선물은 한 번만 준다.
func _settle_tutorial(progress: Progress, result: Dictionary) -> void:
	var gift: Dictionary = Economy.starter_gift()
	var granted: bool = progress.grant("starter_gift", gift)
	result["gift"] = gift if granted else {}
	result["coins"] = gift["coins"] if granted else 0
	progress.set_flag(Progress.FLAG_TUTORIAL_DONE, true)


func _pay_round(progress: Progress, kind: String, id: String, coins: int, result: Dictionary) -> void:
	if progress.grant("%s:%s" % [kind, id], {"coins": coins}):
		result["coins"] = coins
		result["bonus"] = {"key": "%s_bonus:%s" % [kind, id], "coins": Economy.ad_bonus(coins)}


## 완성한 범주를 도감에 넣고 새 범주와 10개 단위 달성의 코인을 준다.
func _register_album(progress: Progress, board: Board) -> Dictionary:
	var fresh: Array[String] = []
	var coins: int = 0
	for category: String in board.solved():
		if not progress.register_album(category, board.group_items(category)):
			continue
		fresh.append(category)
		if progress.grant("album:" + category, {"coins": Economy.ALBUM_NEW_CATEGORY}):
			coins += Economy.ALBUM_NEW_CATEGORY
		var milestone: int = Economy.album_milestone(progress.album_count())
		if milestone > 0 and progress.grant("album_count:%d" % progress.album_count(), {"coins": milestone}):
			coins += milestone
	return {"new": fresh, "coins": coins}
