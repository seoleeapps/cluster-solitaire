class_name FaAttendance
extends RefCounted
## 출석 보상(7일 주기). 하루에 한 번 받고, 날을 건너뛰어도 주기는 받은 횟수로 이어진다.
## 받으면 지급 기록과 함께 저장한 뒤 결과를 돌려준다(화면은 그 뒤에 연출한다).

const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Events := preload("res://game/core/use_cases/fa_round_events.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

const SOURCE := "attendance"

var _store: StorePort
var _analytics: AnalyticsPort


func _init(store: StorePort, analytics: AnalyticsPort) -> void:
	_store = store
	_analytics = analytics


## 팝업에 그릴 상태 {rewards, today, claimed, can_claim}.
##   rewards: 일곱 칸의 보상. today: 오늘 받을 칸(0부터), 받을 수 없으면 -1.
##   claimed: 이번 주기에서 이미 받은 칸 수(0~7). 오늘 일곱째 칸을 받았으면 7이다.
func status(progress: Progress, today: String) -> Dictionary:
	var rewards: Array[Dictionary] = []
	for day: int in Economy.ATTENDANCE_DAYS:
		rewards.append(Economy.attendance_reward(day))
	var can_claim: bool = progress.can_claim_attendance(today)
	var day: int = progress.attendance_day()
	# 오늘 일곱째 칸을 받으면 다음 칸이 처음으로 돌아가지만, 오늘은 받은 주기를 그대로 보인다.
	var claimed: int = day
	if not can_claim and day == 0 and Daily.is_date(today):
		claimed = Economy.ATTENDANCE_DAYS
	return {"rewards": rewards, "today": day if can_claim else -1, "claimed": claimed, "can_claim": can_claim}


## 오늘의 출석 보상을 받는다. 결과는 {ok, day, reward}이고 day는 받은 칸(0부터)이다.
func claim(progress: Progress, today: String) -> Dictionary:
	var day: int = progress.attendance_day()
	var reward: Dictionary = progress.claim_attendance(today)
	if reward.is_empty():
		return {"ok": false, "day": -1, "reward": {}}
	_store.write(progress.to_dict())
	_analytics.log_event("attendance_claim", {"day": day + 1})
	Events.coins_earned(_analytics, int(reward.get("coins", 0)), SOURCE)
	return {"ok": true, "day": day, "reward": reward}
