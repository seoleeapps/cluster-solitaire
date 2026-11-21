extends SceneTree
## FaHttp와 FaRemoteConfig를 이 기기 안의 HTTP 서버(127.0.0.1)에 붙여 실제 요청을 보내 본다.
## 서버는 tools/test_services.py가 띄우고 이 스크립트를 실행한다. 바깥 네트워크는 쓰지 않는다.
##   godot --headless --path godot --script res://tests/game/fa_http_check.gd -- --base http://127.0.0.1:<포트>
## 서버의 경로: /config.json(원격 설정 문서), /missing(404), /big(큰 응답), /slow(늦은 응답), /echo(POST 본문을 그대로 돌려줌)

const Http := preload("res://game/adapters/fa_http.gd")
const RemoteConfig := preload("res://game/adapters/fa_remote_config.gd")
const Rules := preload("res://game/adapters/fa_remote_config_rules.gd")

const PROFILE_PATH := "res://data/monetization/bm-profile.json"

var _checks: int = 0
var _failed: PackedStringArray = []


class MemoryFiles extends RefCounted:
	var data: Dictionary = {}

	func read(name: String) -> Variant:
		return data.get(name)

	func write(name: String, value: Variant) -> bool:
		data[name] = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


## 요청 하나를 보내고 결과가 올 때까지 기다린다.
func _send(http: Http, request: Dictionary) -> Dictionary:
	var results: Array[Dictionary] = []
	http.send(request, func(result: Dictionary) -> void: results.append(result))
	var waited: float = 0.0
	while results.is_empty() and waited < 15.0:
		await process_frame
		waited += 1.0 / 60.0
	_check(results.size() == 1, "결과가 한 번 온다: " + str(request.get("url", "")).get_file())
	return results[0] if not results.is_empty() else {"ok": false, "status": -1, "text": ""}


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var base: String = arguments[arguments.find("--base") + 1] if arguments.has("--base") else ""
	if not base.begins_with("http://127.0.0.1:"):
		print("usage: -- --base http://127.0.0.1:<port>")
		quit(1)
		return
	var outside: Http = Http.new()
	var early: Dictionary = await _send(outside, {"method": "GET", "url": base + "/config.json", "timeout": 5.0, "max_bytes": 16384})
	_check(not early["ok"] and early["status"] == 0, "트리 밖에서 보낸 요청은 실패로 돌려준다")
	outside.free()

	var http: Http = Http.new()
	root.add_child(http)

	var found: Dictionary = await _send(http, {"method": "GET", "url": base + "/config.json", "timeout": 5.0, "max_bytes": 16384})
	_check(found["ok"] and found["status"] == 200 and JSON.parse_string(found["text"]) is Dictionary, "GET으로 문서를 받는다")
	var missing: Dictionary = await _send(http, {"method": "GET", "url": base + "/missing", "timeout": 5.0, "max_bytes": 16384})
	_check(missing["ok"] and missing["status"] == 404, "없는 주소는 응답은 받았고 상태가 404다")
	var big: Dictionary = await _send(http, {"method": "GET", "url": base + "/big", "timeout": 5.0, "max_bytes": 1024})
	_check(not big["ok"] and big["status"] == 0 and big["text"] == "", "크기 상한을 넘는 응답은 받지 않는다")
	var slow: Dictionary = await _send(http, {"method": "GET", "url": base + "/slow", "timeout": 1.0, "max_bytes": 16384})
	_check(not slow["ok"] and slow["status"] == 0, "시간 제한을 넘기면 받지 못한 것으로 끝난다")
	var refused: Dictionary = await _send(http, {"method": "GET", "url": "http://127.0.0.1:9/nothing", "timeout": 3.0, "max_bytes": 16384})
	_check(not refused["ok"] and refused["status"] == 0, "연결할 수 없으면 받지 못한 것으로 끝난다")

	var body: String = JSON.stringify({"client_id": "1.2", "events": [{"name": "share", "params": {"level": 3}}]})
	var echoed: Dictionary = await _send(http, {"method": "POST", "url": base + "/echo?measurement_id=G-X&api_secret=s", "body": body, "timeout": 5.0, "max_bytes": 16384})
	var echo: Variant = JSON.parse_string(echoed["text"]) if echoed["ok"] else null
	_check(echoed["ok"] and echoed["status"] == 200 and echo is Dictionary, "POST의 응답을 받는다")
	if echo is Dictionary:
		_check(echo["body"] == body, "POST 본문이 그대로 간다")
		_check(echo["content_type"] == "application/json", "본문 형식은 JSON이다")
		_check(echo["path"] == "/echo?measurement_id=G-X&api_secret=s", "주소의 질의 문자열이 그대로 간다")
	var settled: bool = await _settled(http)
	_check(settled, "끝난 요청의 노드를 남기지 않는다")

	var rules: Dictionary = Rules.from_profile(JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH)))
	var files: MemoryFiles = MemoryFiles.new()
	var config: RemoteConfig = RemoteConfig.new(rules, files, http.send, base + "/config.json")
	config.start()
	var waited: float = 0.0
	while config.source() != RemoteConfig.SOURCE_REMOTE and waited < 10.0:
		await process_frame
		waited += 1.0 / 60.0
	_check(config.source() == RemoteConfig.SOURCE_REMOTE and config.version() >= 1, "원격 설정 어댑터가 실제 HTTP로 문서를 받는다")
	_check(config.value("rewarded_booster_cooldown_s") == 30 and config.value("interstitial_level_end_enabled") == true, "받은 값을 돌려준다")
	_check(files.data.has(RemoteConfig.CACHE_FILE), "받은 문서를 캐시에 쓴다")

	http.queue_free()
	await process_frame
	print("Fa http check: %d checks, %d failed" % [_checks, _failed.size()])
	for line: String in _failed:
		print("  FAILED ", line)
	quit(0 if _failed.is_empty() else 1)


func _settled(http: Http) -> bool:
	for _frame: int in 5:
		await process_frame
	return http.get_child_count() == 0
