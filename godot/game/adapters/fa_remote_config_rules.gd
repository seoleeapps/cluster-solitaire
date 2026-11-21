class_name FaRemoteConfigRules
extends RefCounted
## 원격 설정 값의 형과 범위 검사. 기준은 수익화 프로필(godot/data/monetization/bm-profile.json)의 remote_config다.
## 원격 설정 문서의 형식은 {"version": 1 이상의 정수, "values": {열쇠: 값}}이다.

const TYPE_BOOL_NAME := "bool"
const TYPE_INT_NAME := "int"
const TYPE_NAMES: Array[String] = [TYPE_BOOL_NAME, TYPE_INT_NAME]


## 프로필에서 열쇠별 규칙 {열쇠: {type, min, max}}을 만든다. 프로필을 읽을 수 없으면 빈 Dictionary.
## 참 거짓 열쇠에는 min과 max가 없다.
static func from_profile(profile: Variant) -> Dictionary:
	var rules: Dictionary = {}
	if not profile is Dictionary or not profile.get("remote_config") is Array:
		return rules
	for entry: Variant in profile["remote_config"]:
		if not entry is Dictionary or not entry.get("key") is String or not TYPE_NAMES.has(entry.get("type")):
			return {}
		var rule: Dictionary = {"type": entry["type"]}
		if entry["type"] == TYPE_INT_NAME:
			var limits: Variant = entry.get("range")
			if not limits is Dictionary or not _is_whole(limits.get("min")) or not _is_whole(limits.get("max")):
				return {}
			rule["min"] = int(limits["min"])
			rule["max"] = int(limits["max"])
		rules[entry["key"]] = rule
	return rules


## 원격 설정 문서를 규칙에 대어 본다. 결과는 {ok, version, values}다.
## 문서의 형식이 틀리면 ok가 false다. 모르는 열쇠, 형이 틀린 값, 범위를 벗어난 값은 values에서 뺀다.
static func accept(rules: Dictionary, document: Variant) -> Dictionary:
	if not document is Dictionary or not _is_whole(document.get("version")) or document["version"] < 1 \
			or not document.get("values") is Dictionary:
		return {"ok": false, "version": 0, "values": {}}
	var values: Dictionary = {}
	for key: Variant in document["values"]:
		if not key is String or not rules.has(key):
			continue
		var rule: Dictionary = rules[key]
		var value: Variant = document["values"][key]
		if rule["type"] == TYPE_BOOL_NAME:
			if value is bool:
				values[key] = value
		elif _is_whole(value) and value >= rule["min"] and value <= rule["max"]:
			values[key] = int(value)
	return {"ok": true, "version": int(document["version"]), "values": values}


static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value))
