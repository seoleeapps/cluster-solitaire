class_name FaRemoteConfig
extends "res://game/core/ports/fa_config_port.gd"
## 원격 설정 포트의 실제 구현. 정적 JSON 하나를 받아 기기에 캐시한다.
## start()가 캐시를 먼저 읽고, 주소가 있으면 새 문서를 받는다. 받지 못하면 캐시를, 캐시도 없으면 null을 돌려주고
## 쓰는 쪽(FaAdPolicy.config_from)이 내장 기본값을 쓴다. 값의 형과 범위는 FaRemoteConfigRules가 검사한다.

const Rules := preload("res://game/adapters/fa_remote_config_rules.gd")

## 쓰는 값이 바뀌었다(캐시를 읽었거나 새 문서를 받았다).
signal changed

const CACHE_FILE := "remote-config.json"
const TIMEOUT_SECONDS := 8.0
## 응답 크기 상한. 넘는 응답은 받지 않는다.
const MAX_BYTES := 16 * 1024

const SOURCE_NONE := ""
const SOURCE_CACHE := "cache"
const SOURCE_REMOTE := "remote"

var _rules: Dictionary
## read(name), write(name, data)를 가진 파일 저장(FaJsonFiles).
var _files: RefCounted
## 요청을 보내는 함수. (request: Dictionary, on_done: Callable)을 받는다(FaHttp.send).
var _transport: Callable
var _url: String
var _values: Dictionary = {}
var _version: int = 0
var _source: String = SOURCE_NONE


func _init(rules: Dictionary, files: RefCounted, transport: Callable, url: String) -> void:
	_rules = rules
	_files = files
	_transport = transport
	_url = url


## 실행마다 한 번 부른다.
func start() -> void:
	var cached: Dictionary = Rules.accept(_rules, _files.read(CACHE_FILE))
	if cached["ok"]:
		_use(cached, SOURCE_CACHE)
	if _url.is_empty():
		return
	_transport.call(
		{"method": "GET", "url": _url, "timeout": TIMEOUT_SECONDS, "max_bytes": MAX_BYTES},
		_received)


func value(key: String) -> Variant:
	return _values.get(key)


## 쓰고 있는 문서의 version. 받은 것이 없으면 0.
func version() -> int:
	return _version


## 쓰고 있는 값이 어디서 왔는지(SOURCE_*).
func source() -> String:
	return _source


func _received(response: Dictionary) -> void:
	if not response.get("ok", false) or int(response.get("status", 0)) != 200:
		return
	var text: String = str(response.get("text", ""))
	var parser: JSON = JSON.new()
	if text.to_utf8_buffer().size() > MAX_BYTES or parser.parse(text) != OK:
		return
	var accepted: Dictionary = Rules.accept(_rules, parser.data)
	if not accepted["ok"]:
		return
	_use(accepted, SOURCE_REMOTE)
	_files.write(CACHE_FILE, {"version": accepted["version"], "values": accepted["values"]})


func _use(accepted: Dictionary, origin: String) -> void:
	_values = accepted["values"]
	_version = accepted["version"]
	_source = origin
	changed.emit()
