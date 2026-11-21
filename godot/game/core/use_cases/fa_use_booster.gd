class_name FaUseBooster
extends RefCounted
## 부스터(힌트, 되돌리기, 칸 추가)를 쓴다. 보유분을 먼저 쓰고, 없으면 허락을 받았을 때만 코인으로 사서 쓴다.
## 효과가 없을 상황이면 보유분도 코인도 쓰지 않는다. 일일 도전에서는 쓸 수 없다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

const PAID_STOCK := "stock"
const PAID_COINS := "coins"
const COIN := "coin"

var _store: StorePort
var _analytics: AnalyticsPort


func _init(store: StorePort, analytics: AnalyticsPort) -> void:
	_store = store
	_analytics = analytics


## 진행 중인 판의 board에 부스터를 쓴다. pay_coins가 true면 보유분이 없을 때 코인으로 산다.
## 쓰지 못하면 {ok: false, reason}이고 reason은 no_run, daily, unknown, no_effect, no_stock, no_coins다.
##   no_stock은 보유분이 없고 pay_coins가 false일 때라, 화면이 코인 구매나 광고를 물어볼 자리다.
## 쓰면 {ok: true, booster, paid, saved}에 효과가 붙는다. paid는 stock 또는 coins다.
##   힌트: pair(같은 범주 2장. 짝이 없으면 빈 배열)와 column(짝이 없을 때 다음에 옮길 열, 아니면 -1).
##   되돌리기: card, column, slot, closed(FaBoard.undo의 결과). 칸 추가: slots(늘어난 임시 칸 수).
func execute(progress: Progress, board: Board, booster: String, pay_coins: bool) -> Dictionary:
	if not progress.has_run():
		return _refused("no_run")
	var run: Dictionary = progress.run()
	if run["mode"] == RoundMode.DAILY:
		return _refused("daily")
	if not Economy.BOOSTERS.has(booster):
		return _refused("unknown")
	var hint: Dictionary = _hint(board) if booster == Economy.BOOSTER_HINT else {}
	if not _has_effect(board, booster, hint):
		return _refused("no_effect")
	var paid: String = _pay(progress, booster, pay_coins)
	if paid.is_empty():
		return _refused("no_coins" if pay_coins else "no_stock")

	var result: Dictionary = {"ok": true, "booster": booster, "paid": paid}
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

	_analytics.log_event("use_booster", {"booster": booster, "paid": paid, "mode": run["mode"]})
	if paid == PAID_COINS:
		_analytics.log_event("spend_virtual_currency", {
			"virtual_currency_name": COIN, "value": Economy.price(booster), "item_name": booster,
		})
	return result


func _refused(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


## 힌트로 보여 줄 것. 열린 카드에 같은 범주 2장이 있으면 그 짝이고, 없으면 최소 해법의 다음 이동 열이다.
## 짝도 없고 지금 임시 칸 수로 풀 길도 없으면 빈 값이다.
func _hint(board: Board) -> Dictionary:
	var pair: Array[String] = board.hint_pair()
	if not pair.is_empty():
		return {"pair": pair, "column": -1}
	var column: int = Solver.solve_board(board, board.slot_count())["next_hold"]
	return {} if column == -1 else {"pair": pair, "column": column}


func _has_effect(board: Board, booster: String, hint: Dictionary) -> bool:
	if board.is_won() or board.is_failed():
		return false
	match booster:
		Economy.BOOSTER_HINT:
			return not hint.is_empty()
		Economy.BOOSTER_UNDO:
			return board.can_undo()
	return board.can_unlock_slot()


## 보유분 1개를 쓰거나 코인으로 사서 쓴다. 치른 방법을 돌려주고 치르지 못했으면 "".
func _pay(progress: Progress, booster: String, pay_coins: bool) -> String:
	if progress.use_booster(booster):
		return PAID_STOCK
	if pay_coins and progress.buy_booster(booster) and progress.use_booster(booster):
		return PAID_COINS
	return ""
