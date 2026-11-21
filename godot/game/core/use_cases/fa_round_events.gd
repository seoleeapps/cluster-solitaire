class_name FaRoundEvents
extends RefCounted
## 판과 재화에 관한 분석 이벤트를 한곳에서 보낸다. 이름과 매개변수는 06 기술 제작 계획의 이벤트 분류를 따른다.
## 판 시작과 끝은 여정과 일일 도전이면 level_start와 level_end, 튜토리얼이면 tutorial_begin과 tutorial_complete다.

const Board := preload("res://game/core/domain/fa_board.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

const COIN := "coin"


## run은 진행 중인 판의 기록(FaProgress.run())이다.
static func level_start(analytics: AnalyticsPort, run: Dictionary, board: Board) -> void:
	if run["mode"] == RoundMode.TUTORIAL:
		analytics.log_event("tutorial_begin", {})
	else:
		analytics.log_event("level_start", RoundMode.event_params(run, board.meta()))


## 끝낸 판(success가 true)과 버린 판(false)을 알린다. 버린 튜토리얼은 알리지 않는다.
static func level_end(analytics: AnalyticsPort, run: Dictionary, board: Board, success: bool, stars: int, seconds: int) -> void:
	if run["mode"] == RoundMode.TUTORIAL:
		if success:
			analytics.log_event("tutorial_complete", {"seconds": seconds})
		return
	var params: Dictionary = RoundMode.event_params(run, board.meta())
	params.merge({
		"success": success, "stars": stars, "mistakes": board.mistakes(), "holds": board.hold_moves(), "seconds": seconds,
		"continue_used": board.continue_used(), "slot_unlocked": board.slot_count() > Board.HOLD_SLOTS_BASE,
	})
	analytics.log_event("level_end", params)


## 도감에 새로 들어간 범주를 알린다. album은 FaProgress.collect_album의 결과다.
static func album_unlocked(analytics: AnalyticsPort, album: Dictionary) -> void:
	for category: String in album["new"]:
		analytics.log_event("album_unlock", {"category": category})


## 코인을 받았으면 알린다. source는 받은 곳(판 종류나 광고 배치 id)이다.
static func coins_earned(analytics: AnalyticsPort, coins: int, source: String) -> void:
	if coins > 0:
		analytics.log_event("earn_virtual_currency", {"virtual_currency_name": COIN, "value": coins, "source": source})


static func coins_spent(analytics: AnalyticsPort, coins: int, item: String) -> void:
	analytics.log_event("spend_virtual_currency", {"virtual_currency_name": COIN, "value": coins, "item_name": item})
