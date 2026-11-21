class_name FaRoundMode
extends RefCounted
## 판의 종류. 진행 중인 판의 기록과 광고 정책, 유스케이스가 같은 값을 쓴다.

const Daily := preload("res://game/core/domain/fa_daily.gd")

const JOURNEY := "journey"
const DAILY := "daily"
const TUTORIAL := "tutorial"
const ALL: Array[String] = [JOURNEY, DAILY, TUTORIAL]


## 분석 이벤트 level_start, level_end, booster_used에 함께 싣는 판 정보 {mode, level, tier, layout}.
## run은 진행 중인 판의 기록, meta는 FaBoard.meta()다. level은 여정이면 스테이지 번호, 일일 도전이면 도전 번호다.
static func event_params(run: Dictionary, meta: Dictionary) -> Dictionary:
	var mode: String = run["mode"]
	var level: int = run["stage"] if mode == JOURNEY else Daily.challenge_number(run["date"])
	return {"mode": mode, "level": level, "tier": meta["tier"], "layout": meta["layout"]}
