extends SceneTree
## 원격 설정 어댑터 검사: 수익화 프로필에서 만든 규칙, 값의 형과 범위 검사, 받기와 캐시, 받지 못했을 때의 대체,
## 저장소의 첫 설정 파일(remote/config.json), 광고 정책과의 연결, 고정 값 대역.
## 전송과 파일은 메모리 안의 대역으로 바꿔 끼운다. 네트워크를 쓰지 않는다.

const Rules := preload("res://game/adapters/fa_remote_config_rules.gd")
const RemoteConfig := preload("res://game/adapters/fa_remote_config.gd")
const FixedConfig := preload("res://game/adapters/fa_fixed_config.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")

const PROFILE_PATH := "res://data/monetization/bm-profile.json"
const SHIPPED_PATH := "res://../remote/config.json"
const URL := "https://example.github.io/game/config.json"

var _checks: int = 0
var _failed: PackedStringArray = []
var _rules: Dictionary = {}


class MemoryFiles extends RefCounted:
	var texts: Dictionary = {}
	var writes: int = 0

	func read(name: String) -> Variant:
		if not texts.has(name):
			return null
		var parser: JSON = JSON.new()
		return parser.data if parser.parse(texts[name]) == OK else null

	func write(name: String, data: Variant) -> bool:
		texts[name] = JSON.stringify(data)
		writes += 1
		return true


class FakeTransport extends RefCounted:
	var requests: Array[Dictionary] = []
	var waiting: Array[Callable] = []

	func send(request: Dictionary, on_done: Callable) -> void:
		requests.append(request)
		waiting.append(on_done)

	func reply(ok: bool, status: int, text: String) -> void:
		var on_done: Callable = waiting.pop_front()
		on_done.call({"ok": ok, "status": status, "text": text})


func _initialize() -> void:
	_section("프로필에서 만든 규칙", _profile_rules)
	_section("형과 범위 검사", _accept)
	_section("받기와 캐시", _fetch)
	_section("받지 못했을 때", _fallback)
	_section("저장소의 첫 설정 파일", _shipped)
	_section("광고 정책과의 연결", _policy)
	_section("고정 값 대역", _fixed_double)
	print("Fa remote config probe: %d checks, %d failed" % [_checks, _failed.size()])
	for line: String in _failed:
		print("  FAILED ", line)
	quit(0 if _failed.is_empty() else 1)


func _section(title: String, body: Callable) -> void:
	if body.call() != true:
		_failed.append(title + ": 끝까지 실행되지 않음")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


func _read_json(path: String) -> Variant:
	var parser: JSON = JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null


func _document(values: Dictionary, version: Variant = 1) -> String:
	return JSON.stringify({"version": version, "values": values})


func _profile_rules() -> bool:
	var profile: Variant = _read_json(PROFILE_PATH)
	_rules = Rules.from_profile(profile)
	var keys: Array = _rules.keys()
	keys.sort()
	var expected: Array = Array(AdPolicy.remote_keys())
	expected.sort()
	_check(_rules.size() == 18 and keys == expected, "프로필의 열쇠 18개가 광고 정책의 열쇠와 같다")
	_check(_rules["rewarded_booster_enabled"] == {"type": "bool"}, "참 거짓 열쇠에는 범위가 없다")
	_check(_rules["rewarded_booster_cooldown_s"] == {"type": "int", "min": 0, "max": 600}, "간격의 범위")
	_check(_rules["interstitial_level_end_daily_cap"] == {"type": "int", "min": 0, "max": 16}, "하루 상한의 범위")
	_check(_rules["interstitial_min_play_seconds"] == {"type": "int", "min": 180, "max": 1800}, "전면 첫 노출까지 플레이 시간의 범위")
	_check(_rules["interstitial_min_stages_between"] == {"type": "int", "min": 2, "max": 6}, "전면 사이 판 수의 범위")
	for broken: Variant in [null, [], {}, {"remote_config": {}}, {"remote_config": [{"key": "a", "type": "text"}]},
			{"remote_config": [{"key": "a", "type": "int", "range": {}}]}, {"remote_config": [{"type": "bool"}]},
			{"remote_config": [{"key": "a", "type": "bool"}, "x"]}]:
		_check(Rules.from_profile(broken).is_empty(), "읽을 수 없는 프로필에서는 규칙을 만들지 않는다: " + str(broken))
	return true


func _accept() -> bool:
	var accepted: Dictionary = Rules.accept(_rules, {"version": 3, "values": {
		"rewarded_booster_enabled": false, "rewarded_booster_cooldown_s": 45, "interstitial_min_stages_between": 4,
	}})
	_check(accepted == {"ok": true, "version": 3, "values": {
		"rewarded_booster_enabled": false, "rewarded_booster_cooldown_s": 45, "interstitial_min_stages_between": 4,
	}}, "형과 범위가 맞는 값을 받는다")
	_check(Rules.accept(_rules, {"version": 1, "values": {}}) == {"ok": true, "version": 1, "values": {}}, "값이 없는 문서도 받는다")

	var edges: Dictionary = Rules.accept(_rules, {"version": 1, "values": {
		"rewarded_booster_cooldown_s": 0, "rewarded_continue_cooldown_s": 600, "interstitial_min_play_seconds": 180,
		"interstitial_min_stages_between": 6, "rewarded_booster_daily_cap": 10,
	}})["values"]
	_check(edges.size() == 5, "범위의 양 끝 값은 받는다")
	var outside: Dictionary = Rules.accept(_rules, {"version": 1, "values": {
		"rewarded_booster_cooldown_s": -1, "rewarded_continue_cooldown_s": 601, "interstitial_min_play_seconds": 179,
		"interstitial_min_stages_between": 7, "rewarded_booster_daily_cap": 11, "interstitial_level_end_session_cap": 7,
	}})["values"]
	_check(outside.is_empty(), "범위를 벗어난 값은 버린다")
	var wrong_type: Dictionary = Rules.accept(_rules, {"version": 1, "values": {
		"rewarded_booster_enabled": 1, "rewarded_continue_enabled": "true", "rewarded_result_bonus_enabled": null,
		"rewarded_booster_cooldown_s": "30", "rewarded_continue_cooldown_s": true, "rewarded_result_bonus_cooldown_s": 30.5,
		"interstitial_level_end_cooldown_s": [120], "interstitial_min_play_seconds": {"value": 200},
	}})["values"]
	_check(wrong_type.is_empty(), "형이 틀린 값은 버린다")
	var mixed: Dictionary = Rules.accept(_rules, {"version": 1, "values": {
		"rewarded_booster_cooldown_s": 9999, "rewarded_continue_cooldown_s": 90, "unknown_key": 5, "interstitial_level_end_enabled": false,
	}})["values"]
	_check(mixed == {"rewarded_continue_cooldown_s": 90, "interstitial_level_end_enabled": false}, "틀린 값과 모르는 열쇠만 빼고 나머지는 받는다")
	var from_json: Dictionary = Rules.accept(_rules, JSON.parse_string("{\"version\": 2.0, \"values\": {\"rewarded_booster_cooldown_s\": 45.0}}"))
	_check(from_json["ok"] and from_json["version"] == 2 and typeof(from_json["values"]["rewarded_booster_cooldown_s"]) == TYPE_INT, "JSON에서 실수로 읽힌 정수는 정수로 받는다")

	for broken: Variant in [null, [], "text", 5, {}, {"values": {}}, {"version": 1}, {"version": 0, "values": {}},
			{"version": -1, "values": {}}, {"version": "1", "values": {}}, {"version": 1.5, "values": {}},
			{"version": 1, "values": []}, {"version": true, "values": {}}]:
		_check(Rules.accept(_rules, broken) == {"ok": false, "version": 0, "values": {}}, "형식이 틀린 문서는 받지 않는다: " + str(broken))
	_check(Rules.accept({}, {"version": 1, "values": {"rewarded_booster_cooldown_s": 45}})["values"].is_empty(), "규칙이 없으면 어떤 값도 받지 않는다")
	return true


func _fetch() -> bool:
	var files: MemoryFiles = MemoryFiles.new()
	var transport: FakeTransport = FakeTransport.new()
	var config: RemoteConfig = RemoteConfig.new(_rules, files, transport.send, URL)
	var changes: Array[int] = [0]
	config.changed.connect(func() -> void: changes[0] += 1)
	_check(config.value("rewarded_booster_cooldown_s") == null and config.source() == "" and config.version() == 0, "start 전에는 값이 없다")
	config.start()
	_check(transport.requests.size() == 1 and transport.requests[0]["method"] == "GET" and transport.requests[0]["url"] == URL, "주소에서 받는다")
	_check(transport.requests[0]["timeout"] == RemoteConfig.TIMEOUT_SECONDS and transport.requests[0]["max_bytes"] == RemoteConfig.MAX_BYTES, "시간과 크기 제한을 넘긴다")
	_check(RemoteConfig.TIMEOUT_SECONDS <= 10.0 and RemoteConfig.MAX_BYTES <= 64 * 1024, "제한은 10초와 64KB 이하다")
	_check(config.value("rewarded_booster_cooldown_s") == null and changes[0] == 0, "받기 전에는 null이다")
	transport.reply(true, 200, _document({"rewarded_booster_cooldown_s": 45, "rewarded_booster_enabled": false, "rewarded_continue_daily_cap": 99, "extra": 1}, 7))
	_check(config.value("rewarded_booster_cooldown_s") == 45 and config.value("rewarded_booster_enabled") == false, "받은 값을 돌려준다")
	_check(config.value("rewarded_continue_daily_cap") == null and config.value("extra") == null and config.value("never_sent") == null, "범위를 벗어난 값, 모르는 열쇠, 없는 열쇠는 null이다")
	_check(config.source() == "remote" and config.version() == 7 and changes[0] == 1, "받은 문서의 version과 출처")
	_check(files.read(RemoteConfig.CACHE_FILE) == {"version": 7.0, "values": {"rewarded_booster_cooldown_s": 45.0, "rewarded_booster_enabled": false}}, "검사를 통과한 값만 캐시에 쓴다")

	# 다음 실행: 주소에 닿지 못해도 캐시를 쓴다.
	transport = FakeTransport.new()
	config = RemoteConfig.new(_rules, files, transport.send, URL)
	config.start()
	_check(config.value("rewarded_booster_cooldown_s") == 45 and typeof(config.value("rewarded_booster_cooldown_s")) == TYPE_INT, "받기 전에도 캐시의 값을 정수로 돌려준다")
	_check(config.source() == "cache" and config.version() == 7, "출처는 캐시다")
	transport.reply(false, 0, "")
	_check(config.value("rewarded_booster_cooldown_s") == 45 and config.source() == "cache", "받지 못하면 캐시를 계속 쓴다")

	# 그다음 실행: 새 문서가 캐시를 바꾼다.
	transport = FakeTransport.new()
	config = RemoteConfig.new(_rules, files, transport.send, URL)
	config.start()
	transport.reply(true, 200, _document({"rewarded_booster_cooldown_s": 60}, 8))
	_check(config.value("rewarded_booster_cooldown_s") == 60 and config.value("rewarded_booster_enabled") == null, "새 문서에 없는 열쇠는 캐시의 값을 쓰지 않는다")
	_check(config.version() == 8 and files.read(RemoteConfig.CACHE_FILE)["values"] == {"rewarded_booster_cooldown_s": 60.0}, "캐시를 새 문서로 바꾼다")
	return true


func _fallback() -> bool:
	var files: MemoryFiles = MemoryFiles.new()
	var transport: FakeTransport = FakeTransport.new()
	var config: RemoteConfig = RemoteConfig.new(_rules, files, transport.send, "")
	config.start()
	_check(transport.requests.is_empty() and config.value("rewarded_booster_cooldown_s") == null and files.writes == 0, "주소가 없으면 받지 않고 null을 돌려준다")

	var rejected: Array = [
		[false, 0, ""], [true, 404, _document({"rewarded_booster_cooldown_s": 45})], [true, 500, ""],
		[true, 200, "<html>not json</html>"], [true, 200, ""], [true, 200, "[1, 2]"],
		[true, 200, "{\"values\": {\"rewarded_booster_cooldown_s\": 45}}"],
		[true, 200, _document({"rewarded_booster_cooldown_s": 45}, 0)],
		[true, 200, _document({"rewarded_booster_cooldown_s": 45, "padding": "x".repeat(RemoteConfig.MAX_BYTES)})],
	]
	for response: Array in rejected:
		files = MemoryFiles.new()
		transport = FakeTransport.new()
		config = RemoteConfig.new(_rules, files, transport.send, URL)
		config.start()
		transport.reply(response[0], response[1], response[2])
		_check(config.value("rewarded_booster_cooldown_s") == null and config.source() == "" and files.writes == 0,
			"받지 못했고 캐시도 없으면 null이다: %s %d %s" % [response[0], response[1], str(response[2]).left(40)])

	files = MemoryFiles.new()
	files.write(RemoteConfig.CACHE_FILE, {"version": 2, "values": {"rewarded_booster_cooldown_s": 50}})
	for response: Array in rejected:
		transport = FakeTransport.new()
		config = RemoteConfig.new(_rules, files, transport.send, URL)
		config.start()
		transport.reply(response[0], response[1], response[2])
		_check(config.value("rewarded_booster_cooldown_s") == 50 and config.source() == "cache" and files.writes == 1,
			"받지 못하면 캐시를 쓰고 캐시를 건드리지 않는다: %s %d" % [response[0], response[1]])

	files = MemoryFiles.new()
	files.write(RemoteConfig.CACHE_FILE, {"version": 2, "values": {"rewarded_booster_cooldown_s": 5000, "rewarded_continue_cooldown_s": 70}})
	config = RemoteConfig.new(_rules, files, transport.send, "")
	config.start()
	_check(config.value("rewarded_booster_cooldown_s") == null and config.value("rewarded_continue_cooldown_s") == 70, "캐시의 값도 다시 검사한다")
	for broken: String in ["{broken", "[]", "{\"version\": 1}"]:
		files = MemoryFiles.new()
		files.texts[RemoteConfig.CACHE_FILE] = broken
		config = RemoteConfig.new(_rules, files, transport.send, "")
		config.start()
		_check(config.value("rewarded_booster_cooldown_s") == null and config.source() == "", "읽을 수 없는 캐시는 없는 것으로 본다: " + broken)
	return true


func _shipped() -> bool:
	var document: Variant = _read_json(SHIPPED_PATH)
	_check(document is Dictionary, "remote/config.json을 읽는다")
	var accepted: Dictionary = Rules.accept(_rules, document)
	_check(accepted["ok"] and accepted["version"] >= 1, "문서 형식이 맞다")
	_check(accepted["values"].size() == 18 and accepted["values"].size() == document["values"].size(), "열쇠 18개가 모두 검사를 통과한다")
	_check(AdPolicy.config_from(accepted["values"]) == AdPolicy.default_config(), "첫 설정은 내장 기본값과 같은 광고 설정을 만든다")
	_check(FileAccess.get_file_as_string(SHIPPED_PATH).to_utf8_buffer().size() < RemoteConfig.MAX_BYTES, "크기 제한 안이다")
	return true


func _policy() -> bool:
	var files: MemoryFiles = MemoryFiles.new()
	var transport: FakeTransport = FakeTransport.new()
	var config: RemoteConfig = RemoteConfig.new(_rules, files, transport.send, URL)
	config.start()
	var values: Dictionary = {}
	for key: String in AdPolicy.remote_keys():
		values[key] = config.value(key)
	_check(AdPolicy.config_from(values) == AdPolicy.default_config(), "받은 것이 없으면 광고 정책은 내장 기본값을 쓴다")
	transport.reply(true, 200, _document({
		"interstitial_level_end_enabled": false, "rewarded_booster_daily_cap": 3, "interstitial_min_stages_between": 5,
		"interstitial_min_play_seconds": 60,
	}))
	for key: String in AdPolicy.remote_keys():
		values[key] = config.value(key)
	var applied: Dictionary = AdPolicy.config_from(values)
	_check(not applied["interstitial_level_end"]["enabled"] and applied["rewarded_booster"]["daily_cap"] == 3 and applied["interstitial_level_end"]["completion_interval"] == 5, "받은 값이 광고 설정을 덮어쓴다")
	_check(applied["interstitial_level_end"]["first_play_seconds"] == 180 and applied["rewarded_continue"] == AdPolicy.default_config()["rewarded_continue"], "범위를 벗어난 값과 보내지 않은 값은 기본값이다")
	return true


func _fixed_double() -> bool:
	var initial: Dictionary = {"rewarded_booster_cooldown_s": 5, "interstitial_level_end_enabled": false}
	var config: FixedConfig = FixedConfig.new(initial)
	_check(config.value("rewarded_booster_cooldown_s") == 5 and config.value("interstitial_level_end_enabled") == false, "넘겨받은 값을 돌려준다")
	_check(config.value("rewarded_booster_daily_cap") == null, "없는 열쇠는 null이다")
	initial["rewarded_booster_cooldown_s"] = 99
	_check(config.value("rewarded_booster_cooldown_s") == 5, "넘긴 쪽이 뒤에 고쳐도 바뀌지 않는다")
	config.values["rewarded_booster_cooldown_s"] = 7
	_check(config.value("rewarded_booster_cooldown_s") == 7, "검수 도중에 값을 고칠 수 있다")
	_check(FixedConfig.new().value("rewarded_booster_cooldown_s") == null, "값 없이 만들면 모두 null이다")
	return true
