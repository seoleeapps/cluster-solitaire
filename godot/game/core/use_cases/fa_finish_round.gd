class_name FaFinishRound
extends RefCounted
## 끝낸 판을 정산한다. 별과 코인, 도감, 다음 스테이지, 일일 도전 기록을 한 번에 반영하고 저장한 뒤 결과를 돌려준다.
## 저장이 화면 반영보다 먼저라서 같은 보상을 두 번 받지 않는다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const Events := preload("res://game/core/use_cases/fa_round_events.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

var _store: StorePort
var _analytics: AnalyticsPort


func _init(store: StorePort, analytics: AnalyticsPort) -> void:
	_store = store
	_analytics = analytics


## 진행 중인 판이 board로 끝났을 때 부른다. seconds는 이 판에 쓴 시간이다.
## 정산하지 못하면 {ok: false, reason}이고 reason은 no_run 또는 not_won이다.
## 정산하면 {ok: true, mode, stars, mistakes, coins, bonus, album, saved}에 판의 종류별 값이 붙는다.
##   coins: 이 판으로 받은 코인(도감과 연속 기록 코인 제외). bonus: 결과 광고를 끝까지 보면 더 받을 {key, coins}, 없으면 빈 값.
##   album: {new: 새로 등록한 범주, coins: 도감으로 받은 코인}. saved: 저장했는지.
##   여정: first_clear, next_stage. 일일 도전: recorded, counted, streak, streak_coins(7일 연속마다 받는 코인).
##   튜토리얼: gift(받은 시작 선물, 이미 받았으면 빈 값).
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
			_settle_daily(progress, board, run, seconds, result)
		RoundMode.TUTORIAL:
			_settle_tutorial(progress, result)
	result["album"] = progress.collect_album(board)
	if mode != RoundMode.TUTORIAL:
		AdPolicy.record_round_end(progress.ads())
	progress.clear_run()
	result["saved"] = _store.write(progress.to_dict())

	Events.level_end(_analytics, run, board, true, result["stars"], seconds)
	if result.get("recorded", false):
		_analytics.log_event("daily_complete", {"streak": result["streak"]})
	Events.album_unlocked(_analytics, result["album"])
	Events.coins_earned(_analytics, result["coins"] + result.get("streak_coins", 0) + result["album"]["coins"], mode)
	return result


## 스테이지 코인은 지금 풀 차례인 스테이지를 처음 깼을 때만 준다.
func _settle_journey(progress: Progress, board: Board, stage: int, result: Dictionary) -> void:
	result["first_clear"] = progress.clear_stage(stage, result["stars"], board.categories())
	if result["first_clear"]:
		_pay_round(progress, "stage", str(stage), Economy.stage_reward(result["stars"]), result)
	result["next_stage"] = progress.stage()


## 일일 도전은 판을 시작한 날을 기준으로 판정한다. 코인은 그 날짜를 처음 성공했을 때만 주고,
## 지난 날짜의 판도 코인은 받지만 연속 기록에는 넣지 않는다. 연속 기록이 7일 단위가 되면 코인을 더 준다.
func _settle_daily(progress: Progress, board: Board, run: Dictionary, seconds: int, result: Dictionary) -> void:
	var date: String = run["date"]
	var record: Dictionary = progress.record_daily_success(date, run["started"], {
		"mistakes": board.mistakes(), "holds": board.hold_moves(), "seconds": seconds, "order": board.solved(),
	})
	result.merge(record)
	result["streak_coins"] = 0
	if not record["recorded"]:
		return
	_pay_round(progress, "daily", date, Economy.DAILY_REWARD, result)
	var streak_coins: int = Economy.streak_reward(record["streak"]) if record["counted"] else 0
	if streak_coins > 0 and progress.grant("daily_streak:" + date, {"coins": streak_coins}):
		result["streak_coins"] = streak_coins


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
