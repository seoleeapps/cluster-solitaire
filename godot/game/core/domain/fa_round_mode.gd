class_name FaRoundMode
extends RefCounted
## 판의 종류. 진행 중인 판의 기록과 광고 정책, 유스케이스가 같은 값을 쓴다.

const JOURNEY := "journey"
const DAILY := "daily"
const TUTORIAL := "tutorial"
const ALL: Array[String] = [JOURNEY, DAILY, TUTORIAL]


## 분석 이벤트에 쓰는 판 이름. 여정은 stage_번호, 일일 도전은 daily_날짜, 튜토리얼은 tutorial이다.
static func level_name(mode: String, stage: int, date: String) -> String:
	match mode:
		JOURNEY:
			return "stage_%d" % stage
		DAILY:
			return "daily_" + date
	return mode
