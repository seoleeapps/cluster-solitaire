class_name FaPickLevel
extends RefCounted
## 스테이지 번호나 날짜에서 레벨을 찾는다. 팩 파일은 어댑터가 읽어 Dictionary로 넘긴다.
## 여정은 팩에 있는 스테이지면 팩에서, 그 뒤는 생성기로 만든다. 일일 도전은 팩에서만 꺼내고 길이를 넘으면 순환한다.

const Content := preload("res://game/core/domain/fa_content.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Generator := preload("res://game/core/domain/fa_generator.gd")

const PACK_VERSION := 1

var _content: Content
var _journey: Array = []
var _daily: Array = []
var _problems: PackedStringArray = []


func _init(content: Content, journey_pack: Dictionary, daily_pack: Dictionary) -> void:
	_content = content
	_journey = _levels_of(journey_pack, "journey")
	_daily = _levels_of(daily_pack, "daily")


## 쓸 수 없는 팩 목록. 한 줄은 "bad_pack: 이름"이고 비어 있으면 문제가 없다.
func problems() -> PackedStringArray:
	return _problems


func journey_size() -> int:
	return _journey.size()


func daily_size() -> int:
	return _daily.size()


## 여정 스테이지(1부터)의 레벨. recent는 팩 뒤의 스테이지를 만들 때 피할 범주다.
## 피할 범주 때문에 만들지 못하면 그 조건 없이 한 번 더 만든다. 같은 스테이지와 recent에서는 늘 같은 판이 나온다.
## 결과는 {ok: true, level} 또는 {ok: false, error}다.
func journey(stage: int, recent: Array) -> Dictionary:
	if stage < 1:
		return {"ok": false, "error": "bad_stage"}
	if stage <= _journey.size():
		return {"ok": true, "level": _level_at(_journey, stage)}
	var made: Dictionary = Generator.journey_level(_content, stage, recent)
	if not made["ok"] and not recent.is_empty():
		made = Generator.journey_level(_content, stage, [])
	if not made["ok"]:
		return {"ok": false, "error": made["error"]}
	return {"ok": true, "level": made["level"]}


## 날짜(YYYY-MM-DD)의 일일 도전 레벨. 결과의 number는 그 날짜의 도전 번호다.
func daily(date: String) -> Dictionary:
	var number: int = Daily.challenge_number(date)
	if number == 0:
		return {"ok": false, "error": "bad_date"}
	var pack_number: int = Daily.pack_number(number, _daily.size())
	if pack_number == 0:
		return {"ok": false, "error": "no_pack"}
	return {"ok": true, "level": _level_at(_daily, pack_number), "number": number}


func _levels_of(pack: Dictionary, name: String) -> Array:
	var levels: Variant = pack.get("levels")
	if pack.get("version") != PACK_VERSION or pack.get("content_version") != _content.version() or not levels is Array:
		_problems.append("bad_pack: " + name)
		return []
	return levels


## 팩의 레벨을 복사해 돌려준다. JSON에서 실수로 읽힌 번호와 등급은 정수로 바꾼다.
func _level_at(levels: Array, number: int) -> Dictionary:
	var level: Dictionary = levels[number - 1].duplicate(true)
	level["n"] = int(level["n"])
	level["tier"] = int(level["tier"])
	return level
