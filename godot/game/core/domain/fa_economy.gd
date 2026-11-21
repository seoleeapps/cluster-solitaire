class_name FaEconomy
extends RefCounted
## 경제 수치. 재화는 코인 하나이고 부스터는 개수로 가진다.
## 보상은 {"coins": 정수, "boosters": {부스터 id: 개수}} 꼴이며 두 열쇠 모두 생략할 수 있다.

const BOOSTER_HINT := "hint"
const BOOSTER_UNDO := "undo"
const BOOSTER_SLOT := "slot"
const BOOSTERS: Array[String] = [BOOSTER_HINT, BOOSTER_UNDO, BOOSTER_SLOT]

## 별: 실수 0은 3, 1~2는 2, 3 또는 이어하기를 쓴 판은 1.
const STARS_MAX := 3
const STARS_MIN := 1
const TWO_STAR_MISTAKES_MAX := 2

## 판 보상: 기본 10에 별 하나가 늘 때마다 3. 결과 광고를 보면 2배.
const STAGE_REWARD_BASE := 10
const STAGE_REWARD_PER_STAR := 3
const AD_MULTIPLIER := 2
const DAILY_REWARD := 30
## 일일 도전을 7일 연속으로 성공할 때마다 주는 코인.
const DAILY_STREAK_STEP := 7
const DAILY_STREAK_REWARD := 100

## 광고를 쓸 수 없을 때 코인으로 사는 이어하기. 부스터가 아니라서 보유하지 않고 살 때 바로 쓴다.
const CONTINUE := "continue"
const PRICES := {BOOSTER_HINT: 100, BOOSTER_UNDO: 80, BOOSTER_SLOT: 150, CONTINUE: 150}
const AD_BOOSTER_COUNT := 1
const STARTER_GIFT := {"coins": 200, "boosters": {BOOSTER_HINT: 3, BOOSTER_UNDO: 3, BOOSTER_SLOT: 2}}

const ALBUM_NEW_CATEGORY := 5
const ALBUM_MILESTONE_STEP := 10
const ALBUM_MILESTONE_REWARD := 50

## 출석 보상(7일 주기).
const ATTENDANCE: Array[Dictionary] = [
	{"coins": 20},
	{"boosters": {BOOSTER_HINT: 1}},
	{"coins": 30},
	{"boosters": {BOOSTER_UNDO: 1}},
	{"coins": 40},
	{"boosters": {BOOSTER_SLOT: 1}},
	{"coins": 60},
]
const ATTENDANCE_DAYS := 7


static func stars(mistakes: int, continued: bool) -> int:
	if continued or mistakes > TWO_STAR_MISTAKES_MAX:
		return STARS_MIN
	return STARS_MAX if mistakes == 0 else STARS_MAX - 1


## 별 수에 따른 스테이지 클리어 코인.
static func stage_reward(star_count: int) -> int:
	return STAGE_REWARD_BASE + STAGE_REWARD_PER_STAR * (star_count - STARS_MIN)


## 일일 도전 연속 기록이 streak이 됐을 때의 코인. 7일 단위가 아니면 0.
static func streak_reward(streak: int) -> int:
	return DAILY_STREAK_REWARD if streak > 0 and streak % DAILY_STREAK_STEP == 0 else 0


## 결과 광고를 끝까지 봤을 때 더 받는 코인. base는 그 판에서 이미 받은 코인이다.
static func ad_bonus(base: int) -> int:
	return base * (AD_MULTIPLIER - 1)


## 부스터 1개나 이어하기(CONTINUE)의 코인 가격. 팔지 않는 것은 0.
static func price(item: String) -> int:
	return PRICES.get(item, 0)


static func starter_gift() -> Dictionary:
	return STARTER_GIFT.duplicate(true)


## 보상형 광고로 받는 부스터 보상.
static func booster_reward(booster: String) -> Dictionary:
	return {"boosters": {booster: AD_BOOSTER_COUNT}}


## 도감에 등록한 범주 수가 count가 됐을 때의 달성 코인. 10개 단위가 아니면 0.
static func album_milestone(count: int) -> int:
	return ALBUM_MILESTONE_REWARD if count > 0 and count % ALBUM_MILESTONE_STEP == 0 else 0


## 주기 안의 day번째(0부터) 출석 보상. 7일이 지나면 처음으로 돌아간다.
static func attendance_reward(day: int) -> Dictionary:
	return ATTENDANCE[day % ATTENDANCE_DAYS].duplicate(true)
