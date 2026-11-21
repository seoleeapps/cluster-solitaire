class_name FaAdPolicy
extends RefCounted
## 광고를 지금 내도 되는지 판정하는 규칙. 설정과 상태를 받아 {ok, reason}을 돌려준다.
## 열쇠 이름은 사내 수익화 프로필(bm-profile.json)의 배치 필드를 따른다.
##
## 배치 설정: format, enabled, cooldown_s(같은 배치의 노출 간격), session_cap(한 번 실행 상한),
##   daily_cap(하루 상한), first_session(몇 번째 실행부터), first_play_seconds(누적 플레이 몇 초부터).
##   전면에는 completion_interval(직전 전면 뒤 끝나야 하는 판 수)과
##   rewarded_gap_s(보상형을 보거나 거절한 뒤 비워 둘 초)가 더 있다.
## 상태: date(일 횟수를 센 날짜), daily와 session(배치별 횟수), last(배치별 마지막 노출 시각),
##   session_no(실행 번호), play_seconds(누적 플레이 초), rounds_since_interstitial,
##   rewarded_at(마지막 보상형 노출 시각), declined_at(마지막 보상형 거절 시각). 시각은 유닉스 초다.

const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")

const FORMAT_REWARDED := "rewarded"
const FORMAT_INTERSTITIAL := "interstitial"

const REWARDED_BOOSTER := "rewarded_booster"
const REWARDED_CONTINUE := "rewarded_continue"
const REWARDED_RESULT_BONUS := "rewarded_result_bonus"
const INTERSTITIAL_LEVEL_END := "interstitial_level_end"

const DEFAULTS := {
	REWARDED_BOOSTER: {
		"format": FORMAT_REWARDED, "enabled": true, "cooldown_s": 30, "session_cap": 2, "daily_cap": 5,
		"first_session": 1, "first_play_seconds": 0,
	},
	REWARDED_CONTINUE: {
		"format": FORMAT_REWARDED, "enabled": true, "cooldown_s": 60, "session_cap": 1, "daily_cap": 2,
		"first_session": 1, "first_play_seconds": 0,
	},
	REWARDED_RESULT_BONUS: {
		"format": FORMAT_REWARDED, "enabled": true, "cooldown_s": 60, "session_cap": 1, "daily_cap": 3,
		"first_session": 1, "first_play_seconds": 0,
	},
	INTERSTITIAL_LEVEL_END: {
		"format": FORMAT_INTERSTITIAL, "enabled": true, "cooldown_s": 120, "session_cap": 3, "daily_cap": 8,
		"first_session": 2, "first_play_seconds": 180, "completion_interval": 2, "rewarded_gap_s": 120,
	},
}

## 일일 도전에서 막는 배치. 튜토리얼에서는 모든 배치를 막는다.
const BLOCKED_IN_DAILY: Array[String] = [REWARDED_BOOSTER, REWARDED_CONTINUE, INTERSTITIAL_LEVEL_END]

## 원격 설정으로 덮어쓸 수 있는 필드. 열쇠는 "<배치 id>_<필드>"다.
const REMOTE_SWITCH := "enabled"
const REMOTE_NUMBERS: Array[String] = ["cooldown_s", "session_cap", "daily_cap"]
## 덮어쓸 수 있는 범위는 0부터, 간격은 기본값의 4배와 600초 중 큰 값, 상한은 기본값의 2배까지다.
const COOLDOWN_RANGE_FACTOR := 4
const COOLDOWN_RANGE_FLOOR := 600
const CAP_RANGE_FACTOR := 2

const STATE_COUNTS: Array[String] = ["session_no", "play_seconds", "rounds_since_interstitial", "rewarded_at", "declined_at"]
const STATE_TABLES: Array[String] = ["daily", "session", "last"]


static func default_config() -> Dictionary:
	return DEFAULTS.duplicate(true)


## 원격 설정의 열쇠 목록.
static func remote_keys() -> Array[String]:
	var keys: Array[String] = []
	for placement: String in DEFAULTS:
		keys.append(_remote_key(placement, REMOTE_SWITCH))
		for field: String in REMOTE_NUMBERS:
			keys.append(_remote_key(placement, field))
	return keys


## 숫자 열쇠가 받을 수 있는 [최소, 최대]. 숫자 열쇠가 아니면 빈 배열.
static func remote_range(key: String) -> Array[int]:
	for placement: String in DEFAULTS:
		for field: String in REMOTE_NUMBERS:
			if key == _remote_key(placement, field):
				return _field_range(field, DEFAULTS[placement][field])
	return []


## 원격 설정 값({열쇠: 값})으로 기본 설정을 덮어쓴다. 형식이 틀리거나 범위를 벗어난 값은 기본값을 쓴다.
static func config_from(values: Dictionary) -> Dictionary:
	var config: Dictionary = default_config()
	for placement: String in config:
		var enabled: Variant = values.get(_remote_key(placement, REMOTE_SWITCH))
		if enabled is bool:
			config[placement][REMOTE_SWITCH] = enabled
		for field: String in REMOTE_NUMBERS:
			var value: Variant = values.get(_remote_key(placement, field))
			var allowed: Array[int] = _field_range(field, DEFAULTS[placement][field])
			if _is_count(value) and value >= allowed[0] and value <= allowed[1]:
				config[placement][field] = int(value)
	return config


static func default_state() -> Dictionary:
	return {
		"date": "", "daily": {}, "session": {}, "last": {}, "session_no": 0, "play_seconds": 0,
		"rounds_since_interstitial": 0, "rewarded_at": 0, "declined_at": 0,
	}


## 저장에서 읽은 값을 상태로 바꾼다. 형식이 틀리면 빈 Dictionary.
static func state_from(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("date") is String:
		return {}
	var state: Dictionary = {"date": raw["date"]}
	for key: String in STATE_TABLES:
		var table: Variant = raw.get(key)
		if not table is Dictionary:
			return {}
		state[key] = {}
		for placement: Variant in table:
			if not placement is String or not _is_count(table[placement]):
				return {}
			state[key][placement] = int(table[placement])
	for key: String in STATE_COUNTS:
		if not _is_count(raw.get(key)):
			return {}
		state[key] = int(raw[key])
	return state


## 날짜가 바뀌었으면 일 횟수만 0으로 돌리고 true를 돌려준다.
static func roll_date(state: Dictionary, today: String) -> bool:
	if state["date"] == today:
		return false
	state["date"] = today
	state["daily"] = {}
	return true


## 앱 실행을 시작할 때 한 번 부른다. 실행 번호를 올리고 실행 횟수를 비운다.
static func begin_session(state: Dictionary) -> void:
	state["session_no"] += 1
	state["session"] = {}


static func add_play_seconds(state: Dictionary, seconds: int) -> void:
	state["play_seconds"] += maxi(0, seconds)


## 판을 클리어할 때마다 부른다.
static func record_round_end(state: Dictionary) -> void:
	state["rounds_since_interstitial"] += 1


## 광고가 실제로 떴을 때 부른다. 보상형을 끝까지 보지 않고 닫았다면 record_declined도 함께 부른다.
static func record_shown(state: Dictionary, config: Dictionary, placement: String, now: int) -> void:
	if not config.has(placement):
		return
	state["daily"][placement] = state["daily"].get(placement, 0) + 1
	state["session"][placement] = state["session"].get(placement, 0) + 1
	state["last"][placement] = now
	if config[placement]["format"] == FORMAT_INTERSTITIAL:
		state["rounds_since_interstitial"] = 0
	else:
		state["rewarded_at"] = now


## 보상형 제안을 거절했거나 보다가 닫았을 때 부른다.
static func record_declined(state: Dictionary, now: int) -> void:
	state["declined_at"] = now


## placement를 now(유닉스 초)에 mode(journey, daily, tutorial)의 판에서 내도 되는지.
## 일 횟수는 state의 date 기준이므로 판정 전에 roll_date를 부른다.
## reason: unknown_placement, disabled, tutorial, daily_challenge, first_session, play_time,
##   daily_cap, session_cap, cooldown, rounds, after_rewarded. 허용이면 "".
static func can_show(config: Dictionary, state: Dictionary, placement: String, now: int, mode: String) -> Dictionary:
	var reason: String = _block_reason(config, state, placement, now, mode)
	return {"ok": reason.is_empty(), "reason": reason}


static func _block_reason(config: Dictionary, state: Dictionary, placement: String, now: int, mode: String) -> String:
	if not config.has(placement):
		return "unknown_placement"
	var rule: Dictionary = config[placement]
	if not rule["enabled"]:
		return "disabled"
	if mode == RoundMode.TUTORIAL:
		return "tutorial"
	if mode == RoundMode.DAILY and BLOCKED_IN_DAILY.has(placement):
		return "daily_challenge"
	if state["session_no"] < rule["first_session"]:
		return "first_session"
	if state["play_seconds"] < rule["first_play_seconds"]:
		return "play_time"
	if state["daily"].get(placement, 0) >= rule["daily_cap"]:
		return "daily_cap"
	if state["session"].get(placement, 0) >= rule["session_cap"]:
		return "session_cap"
	if not _has_passed(state["last"].get(placement, 0), now, rule["cooldown_s"]):
		return "cooldown"
	if state["rounds_since_interstitial"] < rule.get("completion_interval", 0):
		return "rounds"
	var gap: int = rule.get("rewarded_gap_s", 0)
	if not (_has_passed(state["rewarded_at"], now, gap) and _has_passed(state["declined_at"], now, gap)):
		return "after_rewarded"
	return ""


## since(0이면 없음)에서 gap초가 지났는지. 시계가 뒤로 가 now가 더 이르면 지난 것으로 본다.
static func _has_passed(since: int, now: int, gap: int) -> bool:
	return since <= 0 or now < since or now - since >= gap


static func _remote_key(placement: String, field: String) -> String:
	return placement + "_" + field


static func _field_range(field: String, default_value: int) -> Array[int]:
	if field == "cooldown_s":
		return [0, maxi(default_value * COOLDOWN_RANGE_FACTOR, COOLDOWN_RANGE_FLOOR)]
	return [0, default_value * CAP_RANGE_FACTOR]


static func _is_count(value: Variant) -> bool:
	return (value is int or (value is float and value == floorf(value))) and value >= 0
