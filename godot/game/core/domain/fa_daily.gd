class_name FaDaily
extends RefCounted
## 일일 도전의 날짜 계산과 연속 기록. 날짜는 현지 날짜 문자열(YYYY-MM-DD)이다.
## 상태는 {results: {날짜: 요약}, streak, best, last}이고 요약은 {mistakes, holds, seconds, order}다.
## streak은 last(마지막으로 연속 기록에 넣은 성공일)까지 이어진 날 수다.

const BASE_DATE := "2026-12-01"
const DATE_LENGTH := 10
const DAYS_PER_WEEK := 7
## 1970-01-01은 목요일이다(0 = 일요일).
const EPOCH_WEEKDAY := 4
const SUMMARY_COUNTS: Array[String] = ["mistakes", "holds", "seconds"]


static func is_date(text: String) -> bool:
	if text.length() != DATE_LENGTH or text[4] != "-" or text[7] != "-":
		return false
	for part: String in [text.substr(0, 4), text.substr(5, 2), text.substr(8, 2)]:
		if not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return false
	return _from_days(_to_days(text)) == text


## 날짜에 days일을 더한 날짜.
static func add_days(date: String, days: int) -> String:
	return _from_days(_to_days(date) + days)


## from에서 to까지의 날 수. to가 더 이르면 음수다.
static func days_between(from: String, to: String) -> int:
	return _to_days(to) - _to_days(from)


## 요일. 0(일요일)~6(토요일).
static func weekday(date: String) -> int:
	return posmod(_to_days(date) + EPOCH_WEEKDAY, DAYS_PER_WEEK)


static func same_month(a: String, b: String) -> bool:
	return a.substr(0, 7) == b.substr(0, 7)


## 일일 도전 번호. 기준일이 1번이고, 기준일 전이나 잘못된 날짜는 0이다.
static func challenge_number(date: String) -> int:
	if not is_date(date):
		return 0
	return maxi(0, days_between(BASE_DATE, date) + 1)


## 일일 도전 번호(1부터)의 날짜.
static func challenge_date(number: int) -> String:
	return add_days(BASE_DATE, number - 1)


## 길이가 pack_size인 팩에서 쓸 판 번호(1부터). 팩 길이를 넘으면 처음부터 순환한다.
static func pack_number(number: int, pack_size: int) -> int:
	if number < 1 or pack_size < 1:
		return 0
	return (number - 1) % pack_size + 1


static func default_state() -> Dictionary:
	return {"results": {}, "streak": 0, "best": 0, "last": ""}


## 저장에서 읽은 값을 상태로 바꾼다. 형식이 틀리면 빈 Dictionary.
static func state_from(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("results") is Dictionary or not raw.get("last") is String:
		return {}
	if not (_is_count(raw.get("streak")) and _is_count(raw.get("best"))):
		return {}
	if not (raw["last"].is_empty() or is_date(raw["last"])):
		return {}
	var results: Dictionary = {}
	for date: Variant in raw["results"]:
		var summary: Dictionary = _summary_from(raw["results"][date])
		if not date is String or not is_date(date) or summary.is_empty():
			return {}
		results[date] = summary
	return {"results": results, "streak": int(raw["streak"]), "best": int(raw["best"]), "last": raw["last"]}


## today 기준으로 살아 있는 연속 기록. 마지막 성공이 오늘이나 어제가 아니면 0이다.
static func streak(state: Dictionary, today: String) -> int:
	var last: String = state["last"]
	if last.is_empty() or days_between(last, today) < 0 or days_between(last, today) > 1:
		return 0
	return state["streak"]


## date의 판을 지금 풀 수 있는지. 오늘과 이번 달의 지난 날 가운데 아직 성공하지 않은 날만 된다.
static func can_play(state: Dictionary, date: String, today: String) -> bool:
	if challenge_number(date) == 0 or not is_date(today) or state["results"].has(date):
		return false
	return days_between(date, today) >= 0 and same_month(date, today)


## date의 판을 성공으로 기록한다. played_on은 그 판을 시작한 날이고, 자정을 넘겨 끝내도 시작한 날로 판정한다.
## 시작한 날의 판이면 연속 기록에 넣고, 지난 날짜의 판은 결과만 남긴다.
## 이미 더 뒤의 날까지 연속 기록에 넣었다면(오래 묵힌 판을 뒤늦게 끝낸 경우) 결과만 남긴다.
## 돌려주는 값은 {recorded, counted, streak}이고 streak은 played_on 기준으로 살아 있는 연속 기록이다.
static func record_success(state: Dictionary, date: String, played_on: String, summary: Dictionary) -> Dictionary:
	var clean: Dictionary = _summary_from(summary)
	var recorded: bool = not clean.is_empty() and can_play(state, date, played_on)
	var last: String = state["last"]
	var counted: bool = recorded and date == played_on and (last.is_empty() or days_between(last, date) > 0)
	if recorded:
		state["results"][date] = clean
	if counted:
		state["streak"] = streak(state, played_on) + 1
		state["best"] = maxi(state["best"], state["streak"])
		state["last"] = played_on
	return {"recorded": recorded, "counted": counted, "streak": streak(state, played_on)}


static func _summary_from(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("order") is Array:
		return {}
	var summary: Dictionary = {}
	for key: String in SUMMARY_COUNTS:
		if not _is_count(raw.get(key)):
			return {}
		summary[key] = int(raw[key])
	for category: Variant in raw["order"]:
		if not category is String:
			return {}
	summary["order"] = raw["order"].duplicate()
	return summary


static func _is_count(value: Variant) -> bool:
	return (value is int or (value is float and value == floorf(value))) and value >= 0


## 1970-01-01부터의 날 수(그레고리력).
static func _to_days(date: String) -> int:
	var year: int = date.substr(0, 4).to_int()
	var month: int = date.substr(5, 2).to_int()
	var day: int = date.substr(8, 2).to_int()
	if month <= 2:
		year -= 1
	var era: int = floori(year / 400.0)
	var year_of_era: int = year - era * 400
	var day_of_year: int = (153 * (month - 3 if month > 2 else month + 9) + 2) / 5 + day - 1
	var day_of_era: int = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year
	return era * 146097 + day_of_era - 719468


static func _from_days(days: int) -> String:
	var shifted: int = days + 719468
	var era: int = floori(shifted / 146097.0)
	var day_of_era: int = shifted - era * 146097
	var year_of_era: int = (day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096) / 365
	var day_of_year: int = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100)
	var month_index: int = (5 * day_of_year + 2) / 153
	var day: int = day_of_year - (153 * month_index + 2) / 5 + 1
	var month: int = month_index + 3 if month_index < 10 else month_index - 9
	var year: int = year_of_era + era * 400 + (1 if month <= 2 else 0)
	return "%04d-%02d-%02d" % [year, month, day]
