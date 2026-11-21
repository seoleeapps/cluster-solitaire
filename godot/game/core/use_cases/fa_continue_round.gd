class_name FaContinueRound
extends RefCounted
## 실수 4회로 실패한 판을 이어 가는 길을 고르고, 코인으로 이어 간다.
## 길은 둘이다. 이어하기 광고를 쓸 수 있으면 광고(FaAdFlow.request 뒤 finish_continue),
## 광고를 쓸 수 없으면(정책이 막거나 광고가 준비되지 않음) 코인이다. 화면은 check의 way에 맞는 버튼 하나만 보여 준다.
## 어느 길이든 효과와 제한은 같다: 실수 2회를 지우고, 판당 1회이며(두 길이 횟수를 함께 쓴다), 일일 도전에서는 안 된다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const Events := preload("res://game/core/use_cases/fa_round_events.gd")
const AdFlow := preload("res://game/core/use_cases/fa_ad_flow.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

const WAY_AD := "ad"
const WAY_COINS := "coins"

var _store: StorePort
var _analytics: AnalyticsPort
var _ad_flow: AdFlow


func _init(store: StorePort, analytics: AnalyticsPort, ad_flow: AdFlow) -> void:
	_store = store
	_analytics = analytics
	_ad_flow = ad_flow


## 진행 중인 판 board를 지금 어떻게 이어 갈 수 있는지. 결과는 {ok, way, reason, price}다.
##   way: ad(광고를 쓸 수 있음) 또는 coins(광고를 못 쓰고 코인이 충분함). 이어 갈 수 없으면 "".
##   reason: no_run, daily, no_effect(실패한 판이 아니거나 이미 이어 간 판), no_coins(광고도 못 쓰고 코인도 모자람).
##   price: 코인으로 이어 갈 때의 값.
func check(progress: Progress, board: Board) -> Dictionary:
	var verdict: Dictionary = {"ok": false, "way": "", "reason": _refusal(progress, board), "price": Economy.price(Economy.CONTINUE)}
	if not verdict["reason"].is_empty():
		return verdict
	if _ad_flow.check(progress, AdPolicy.REWARDED_CONTINUE, progress.run()["mode"])["ok"]:
		verdict.merge({"ok": true, "way": WAY_AD}, true)
	elif progress.coins() >= verdict["price"]:
		verdict.merge({"ok": true, "way": WAY_COINS}, true)
	else:
		verdict["reason"] = "no_coins"
	return verdict


## 코인을 내고 이어 간다. 결과는 {ok: true, saved} 또는 {ok: false, reason}이고 reason은 check와 같다.
## 광고를 쓸 수 있는지는 여기서 따지지 않는다. 어느 버튼을 보일지는 화면이 check로 정한다.
func pay_coins(progress: Progress, board: Board) -> Dictionary:
	var reason: String = _refusal(progress, board)
	if reason.is_empty() and not progress.spend_coins(Economy.price(Economy.CONTINUE)):
		reason = "no_coins"
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	board.apply_continue()
	progress.update_run(board, progress.run()["seconds"])
	var saved: bool = _store.write(progress.to_dict())
	Events.coins_spent(_analytics, Economy.price(Economy.CONTINUE), Economy.CONTINUE)
	return {"ok": true, "saved": saved}


## 어느 길로도 이어 갈 수 없는 이유. 이어 갈 수 있는 판이면 "".
func _refusal(progress: Progress, board: Board) -> String:
	if not progress.has_run():
		return "no_run"
	if progress.run()["mode"] == RoundMode.DAILY:
		return "daily"
	return "" if board.can_continue() else "no_effect"
