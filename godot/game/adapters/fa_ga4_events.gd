class_name FaGa4Events
extends RefCounted
## GA4 Measurement Protocol(웹 스트림)의 이름 규칙과 제한, 요청 본문 만들기.
## 근거: https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference 의 Reserved names와
## https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events 의 Limitations.

const MAX_EVENTS_PER_REQUEST := 25
const MAX_NAME_LENGTH := 40
const MAX_PARAMS := 25
const MAX_VALUE_LENGTH := 100
## 이보다 오래된 이벤트는 받는 쪽이 시각을 고치거나 거부하므로 보내지 않는다.
const MAX_AGE_SECONDS := 72 * 3600
const MICROS := 1000000
## JSON에서 실수로 읽힌 정수를 정수로 되돌릴 수 있는 크기(2^53).
const WHOLE_LIMIT := 9007199254740992.0

## 쓸 수 없는 이벤트 이름. 뒤의 셋은 앱 스트림에서만 받는 이름이라 웹 스트림으로는 보낼 수 없다.
const RESERVED_EVENTS: Array[String] = [
	"ad_activeview", "ad_click", "ad_exposure", "ad_query", "ad_reward", "adunit_exposure",
	"app_clear_data", "app_exception", "app_install", "app_remove", "app_store_refund", "app_update", "app_upgrade",
	"dynamic_link_app_open", "dynamic_link_app_update", "dynamic_link_first_open", "error",
	"firebase_campaign", "firebase_in_app_message_action", "firebase_in_app_message_dismiss",
	"firebase_in_app_message_impression", "first_open", "first_visit",
	"notification_dismiss", "notification_foreground", "notification_open", "notification_receive", "notification_send",
	"os_update", "session_start", "user_engagement",
	"ad_impression", "in_app_purchase", "screen_view",
]
const RESERVED_PARAMS: Array[String] = ["firebase_conversion"]
const RESERVED_PARAM_PREFIXES: Array[String] = ["_", "firebase_", "ga_", "google_", "gtag."]

const PROBLEM_NAME := "bad_name"
const PROBLEM_RESERVED_NAME := "reserved_name"
const PROBLEM_PARAM_COUNT := "too_many_params"
const PROBLEM_PARAM_NAME := "bad_param_name"
const PROBLEM_RESERVED_PARAM := "reserved_param"
const PROBLEM_VALUE := "bad_value"
const PROBLEM_VALUE_LENGTH := "value_too_long"


## 이벤트를 보낼 수 없는 이유. 보낼 수 있으면 "".
## params는 모든 이벤트에 붙는 매개변수까지 합친 것을 넘긴다.
static func problem(name: String, params: Dictionary) -> String:
	if not _is_name(name):
		return PROBLEM_NAME
	if RESERVED_EVENTS.has(name):
		return PROBLEM_RESERVED_NAME
	if params.size() > MAX_PARAMS:
		return PROBLEM_PARAM_COUNT
	for key: Variant in params:
		if not key is String:
			return PROBLEM_PARAM_NAME
		if RESERVED_PARAMS.has(key):
			return PROBLEM_RESERVED_PARAM
		for prefix: String in RESERVED_PARAM_PREFIXES:
			if key.begins_with(prefix):
				return PROBLEM_RESERVED_PARAM
		if not _is_name(key):
			return PROBLEM_PARAM_NAME
		var value: Variant = params[key]
		if value is String:
			if value.length() > MAX_VALUE_LENGTH:
				return PROBLEM_VALUE_LENGTH
		elif value is float:
			if not is_finite(value):
				return PROBLEM_VALUE
		elif not value is int and not value is bool:
			return PROBLEM_VALUE
	return ""


## 보낼 값으로 바꾼 매개변수. 참 거짓은 1과 0으로, 정수인 실수는 정수로 바꾼다.
static func clean_params(params: Dictionary) -> Dictionary:
	var cleaned: Dictionary = {}
	for key: String in params:
		cleaned[key] = _clean(params[key])
	return cleaned


## 대기열의 이벤트 하나. timestamp_micros는 일어난 시각(유닉스 마이크로초)이다.
static func entry(name: String, params: Dictionary, unix_seconds: float) -> Dictionary:
	return {"name": name, "params": clean_params(params), "timestamp_micros": int(unix_seconds * MICROS)}


## 저장에서 읽은 대기열을 정리한다. 형식이 틀린 항목과 MAX_AGE_SECONDS를 넘긴 항목을 빼고,
## limit개를 넘으면 오래된 것부터 버린다.
static func restore(raw: Variant, unix_seconds: float, limit: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not raw is Array:
		return entries
	for item: Variant in raw:
		if not item is Dictionary or not item.get("name") is String or not item.get("params") is Dictionary:
			continue
		var stamp: Variant = item.get("timestamp_micros")
		if not (stamp is int or stamp is float) or not is_finite(float(stamp)) or stamp <= 0:
			continue
		var params: Dictionary = clean_params(_string_keys(item["params"]))
		if not problem(item["name"], params).is_empty():
			continue
		entries.append({"name": item["name"], "params": params, "timestamp_micros": int(stamp)})
	return trim(fresh(entries, unix_seconds), limit)


## MAX_AGE_SECONDS를 넘기지 않은 항목만 남긴다.
static func fresh(entries: Array[Dictionary], unix_seconds: float) -> Array[Dictionary]:
	var oldest: int = int((unix_seconds - MAX_AGE_SECONDS) * MICROS)
	var kept: Array[Dictionary] = []
	for item: Dictionary in entries:
		if item["timestamp_micros"] >= oldest:
			kept.append(item)
	return kept


## limit개를 넘으면 앞(오래된 것)부터 버린다.
static func trim(entries: Array[Dictionary], limit: int) -> Array[Dictionary]:
	if entries.size() <= limit:
		return entries
	return entries.slice(entries.size() - limit)


## 요청 하나의 본문. entries는 MAX_EVENTS_PER_REQUEST개까지만 넘긴다.
static func payload(client_id: String, entries: Array[Dictionary]) -> Dictionary:
	var events: Array[Dictionary] = []
	for item: Dictionary in entries:
		events.append({"name": item["name"], "params": item["params"], "timestamp_micros": item["timestamp_micros"]})
	return {"client_id": client_id, "events": events}


## 이름 규칙: 글자로 시작하고 글자, 숫자, 밑줄만 쓰며 MAX_NAME_LENGTH자 이하.
static func _is_name(text: String) -> bool:
	if text.is_empty() or text.length() > MAX_NAME_LENGTH:
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var letter: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var digit: bool = code >= 48 and code <= 57
		if not letter and not (index > 0 and (digit or code == 95)):
			return false
	return true


static func _clean(value: Variant) -> Variant:
	if value is bool:
		return 1 if value else 0
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < WHOLE_LIMIT:
		return int(value)
	return value


static func _string_keys(params: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in params:
		result[str(key)] = params[key]
	return result
