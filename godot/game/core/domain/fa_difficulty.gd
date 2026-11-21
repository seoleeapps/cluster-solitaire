class_name FaDifficulty
extends RefCounted
## 배치와 난도 등급. 관대함 범위와 순환은 GDD의 가설값이며 출시 뒤 클리어율로 다시 맞춘다.

const TIER_MIN := 1
const TIER_MAX := 5
const SUNDAY := 0
const SATURDAY := 6

## 배치: 범주 수, 열별 장수, 예비 카드 수.
const LAYOUTS := {
	"intro": {"groups": 3, "columns": [2, 2, 2, 2], "reserve": 4},
	"open": {"groups": 4, "columns": [2, 2, 2, 2], "reserve": 8},
	"step": {"groups": 4, "columns": [3, 3, 2, 2], "reserve": 6},
	"classic": {"groups": 4, "columns": [3, 3, 3, 3], "reserve": 4},
	"deep": {"groups": 4, "columns": [4, 3, 3, 2], "reserve": 4},
}

## 등급 조건.
##   layouts: 쓸 수 있는 배치. f_min~f_max: 관대함 범위(양 끝 포함).
##   category_tier_max: 쓸 수 있는 범주 난도의 상한. domain_max: 같은 대분류에서 고를 수 있는 범주 수.
##   confusable_max: 판의 다른 범주로도 보일 수 있는 카드의 최대 장수.
##   outside_max: 판에 없는 한 범주의 후보가 될 수 있는 카드의 최대 장수.
const TIERS := {
	1: {"layouts": ["open"], "f_min": 0.90, "f_max": 1.0, "category_tier_max": 1,
		"domain_max": 1, "confusable_max": 0, "outside_max": 2},
	2: {"layouts": ["step"], "f_min": 0.45, "f_max": 0.90, "category_tier_max": 2,
		"domain_max": 1, "confusable_max": 0, "outside_max": 2},
	3: {"layouts": ["classic"], "f_min": 0.25, "f_max": 0.60, "category_tier_max": 3,
		"domain_max": 2, "confusable_max": 0, "outside_max": 3},
	4: {"layouts": ["classic", "deep"], "f_min": 0.10, "f_max": 0.30, "category_tier_max": 4,
		"domain_max": 2, "confusable_max": 1, "outside_max": 3},
	5: {"layouts": ["deep"], "f_min": 0.04, "f_max": 0.12, "category_tier_max": 4,
		"domain_max": 2, "confusable_max": 2, "outside_max": 3},
}

## 여정의 등급 순환. from 스테이지부터 cycle을 되풀이한다.
const JOURNEY_BANDS: Array[Dictionary] = [
	{"from": 1, "cycle": [1]},
	{"from": 6, "cycle": [2, 2, 1, 2, 2]},
	{"from": 21, "cycle": [2, 3, 2, 3, 3]},
	{"from": 61, "cycle": [3, 3, 4, 2, 3, 4, 3, 3, 4, 5]},
	{"from": 151, "cycle": [3, 4, 4, 2, 4, 5, 3, 4, 4, 5]},
]

const DAILY_WEEKDAY_TIER := 3
const DAILY_WEEKEND_TIER := 4


static func layout_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(LAYOUTS.keys())
	return ids


## 배치 {groups, columns, reserve}. 없는 id면 빈 값.
static func layout(id: String) -> Dictionary:
	return LAYOUTS.get(id, {}).duplicate(true)


## 등급 조건. 없는 등급이면 빈 값.
static func tier_rule(tier: int) -> Dictionary:
	return TIERS.get(tier, {}).duplicate(true)


## 여정 스테이지 번호(1부터)의 등급.
static func journey_tier(stage: int) -> int:
	var band: Dictionary = JOURNEY_BANDS[0]
	for candidate: Dictionary in JOURNEY_BANDS:
		if stage >= candidate["from"]:
			band = candidate
	var cycle: Array = band["cycle"]
	return cycle[maxi(0, stage - band["from"]) % cycle.size()]


## 일일 도전의 요일별 등급. 요일은 0(일요일)~6(토요일)이다.
static func daily_tier(weekday: int) -> int:
	return DAILY_WEEKEND_TIER if weekday == SUNDAY or weekday == SATURDAY else DAILY_WEEKDAY_TIER
