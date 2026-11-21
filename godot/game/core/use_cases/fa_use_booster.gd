class_name FaUseBooster
extends RefCounted
## 부스터(힌트, 되돌리기, 칸 추가)를 쓴다. 보유분을 먼저 쓰고, 없으면 코인으로 사서 쓰라고 했을 때만 산다.
## 효과가 없을 상황이면 보유분도 코인도 쓰지 않는다. 일일 도전에서는 쓸 수 없다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const Events := preload("res://game/core/use_cases/fa_round_events.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

## 부스터를 어디서 얻어 쓰는지. owned는 보유분, coins는 코인 구매, ad는 방금 광고로 받은 보유분이다.
const SOURCE_OWNED := "owned"
const SOURCE_COINS := "coins"
const SOURCE_AD := "ad"

var _store: StorePort
var _analytics: AnalyticsPort


func _init(store: StorePort, analytics: AnalyticsPort) -> void:
	_store = store
	_analytics = analytics


## 지금 이 판에서 부스터가 효과가 있는지(보유분과 코인은 보지 않는다). 버튼을 보일지 정할 때 쓴다.
## 결과는 {ok, reason}이고 reason은 no_run, daily, unknown, no_effect다. 쓸 수 있으면 "".
func check(progress: Progress, board: Board, booster: String) -> Dictionary:
	var reason: String = _refusal(progress, board, booster, _hint_for(board, booster))
	return {"ok": reason.is_empty(), "reason": reason}


## 진행 중인 판의 board에 부스터를 쓴다. source가 coins면 보유분이 없을 때 코인으로 사서 쓰고,
## ad면 광고로 방금 받은 보유분을 쓴다(FaAdFlow.finish_booster 뒤에 부른다).
## 쓰지 못하면 {ok: false, reason}이고 reason은 check의 사유이거나 no_stock, no_coins다.
##   no_stock은 보유분이 없는데 source가 coins가 아닐 때라, 화면이 코인 구매나 광고를 물어볼 자리다.
## 쓰면 {ok: true, booster, source, saved}에 효과가 붙는다. source는 실제로 치른 방법이다.
##   힌트: pair(같은 범주 2장. 짝이 없으면 빈 배열)와 column(짝이 없을 때 다음에 옮길 열, 아니면 -1).
##   되돌리기: card, column, slot, closed(FaBoard.undo의 결과). 칸 추가: slots(늘어난 임시 칸 수).
func execute(progress: Progress, board: Board, booster: String, source: String) -> Dictionary:
	var hint: Dictionary = _hint_for(board, booster)
	var reason: String = _refusal(progress, board, booster, hint)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	var paid: String = _pay(progress, booster, source)
	if paid.is_empty():
		return {"ok": false, "reason": "no_coins" if source == SOURCE_COINS else "no_stock"}

	var run: Dictionary = progress.run()
	var result: Dictionary = {"ok": true, "booster": booster, "source": paid}
	match booster:
		Economy.BOOSTER_HINT:
			result.merge(hint)
		Economy.BOOSTER_UNDO:
			var undone: Dictionary = board.undo()
			undone.erase("ok")
			result.merge(undone)
		Economy.BOOSTER_SLOT:
			board.unlock_slot()
			result["slots"] = board.slot_count()
	progress.update_run(board, run["seconds"])
	result["saved"] = _store.write(progress.to_dict())

	var params: Dictionary = RoundMode.event_params(run, board.meta())
	params.merge({"booster": booster, "source": paid})
	_analytics.log_event("booster_used", params)
	if paid == SOURCE_COINS:
		Events.coins_spent(_analytics, Economy.price(booster), booster)
	return result


## 쓸 수 없는 이유. 쓸 수 있으면 "".
func _refusal(progress: Progress, board: Board, booster: String, hint: Dictionary) -> String:
	if not progress.has_run():
		return "no_run"
	if progress.run()["mode"] == RoundMode.DAILY:
		return "daily"
	if not Economy.BOOSTERS.has(booster):
		return "unknown"
	if board.is_won() or board.is_failed():
		return "no_effect"
	var effective: bool = board.can_unlock_slot()
	match booster:
		Economy.BOOSTER_HINT:
			effective = not hint.is_empty()
		Economy.BOOSTER_UNDO:
			effective = board.can_undo()
	return "" if effective else "no_effect"


## 힌트로 보여 줄 것. 열린 카드에 같은 범주 2장이 있으면 그 짝이고, 없으면 최소 해법의 다음 이동 열이다.
## 힌트가 아니거나, 짝도 없고 지금 임시 칸 수로 풀 길도 없으면 빈 값이다.
func _hint_for(board: Board, booster: String) -> Dictionary:
	if booster != Economy.BOOSTER_HINT:
		return {}
	var pair: Array[String] = board.hint_pair()
	if not pair.is_empty():
		return {"pair": pair, "column": -1}
	var column: int = Solver.solve_board(board, board.slot_count())["next_hold"]
	return {} if column == -1 else {"pair": pair, "column": column}


## 보유분 1개를 쓰거나 코인으로 사서 쓴다. 치른 방법을 돌려주고 치르지 못했으면 "".
func _pay(progress: Progress, booster: String, source: String) -> String:
	if progress.use_booster(booster):
		return SOURCE_AD if source == SOURCE_AD else SOURCE_OWNED
	if source == SOURCE_COINS and progress.buy_booster(booster) and progress.use_booster(booster):
		return SOURCE_COINS
	return ""
