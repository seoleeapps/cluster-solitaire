class_name FaGa4Analytics
extends "res://game/core/ports/fa_analytics_port.gd"
## 분석 포트의 실제 구현. GA4 Measurement Protocol(웹 스트림)로 이벤트를 모아 보낸다.
##
## 보내는 조건은 셋이 모두 맞을 때다: 주입된 측정 값이 있고, 설정에서 분석이 켜져 있고(set_enabled),
## 문(gate)이 열려 있다. 문은 광고 어댑터의 동의 상태에서 온다.
##   GATE_OPEN: 동의가 필요 없는 지역. 보내고, 못 보낸 것은 기기에 저장한다.
##   GATE_WAIT: 동의 상태를 아직 모른다. 메모리에만 들고 있고 기기에 쓰지 않는다.
##   GATE_CLOSED: 규제 지역이거나 알 수 없다. 들고 있던 것과 저장한 것을 버린다(결정 로그 DEC-020).
## 설정에서 끄면 대기 중인 이벤트와 저장한 대기열을 버린다.
##
## 모든 이벤트에 platform, app_market, release_version, session_id, engagement_time_msec을 붙인다.
## 첫 실행과 실행 시작(app_first_run, app_session)은 여기서 보낸다. 기기의 식별자 파일을 쓸 수 있는
## 문이 열린 때에만 알 수 있는 값(실행 번호, 설치 뒤 지난 날)이 들어가기 때문이다.
## 전송 실패는 게임에 알리지 않는다. 요청 주소에는 비밀값이 들어가므로 어디에도 출력하지 않는다.
##
## 공통 흐름의 분석 선택(analytics_preference.gd)이 요구하는 set_enabled와 discard_pending을 구현하므로
## 그 port 자리에 그대로 끼울 수 있다.

const Events := preload("res://game/adapters/fa_ga4_events.gd")
const ServiceValues := preload("res://game/adapters/fa_service_values.gd")

const GATE_CLOSED := -1
const GATE_WAIT := 0
const GATE_OPEN := 1

const ENDPOINT := "https://www.google-analytics.com/mp/collect"
const PLATFORM := "android"
const APP_MARKET := "google_play"
## 게임이 쓰는 이름 가운데 웹 스트림으로 보낼 수 없는 것의 보내는 이름.
## ad_impression은 Measurement Protocol이 앱 스트림에서만 받는다(FaGa4Events.RESERVED_EVENTS의 근거 문서).
## 수익화 프로필과 코어는 ad_impression을 그대로 쓰고, 보낼 때만 바꾼다.
const WIRE_NAMES := {"ad_impression": "ad_shown"}

const QUEUE_FILE := "analytics-queue.json"
const CLIENT_FILE := "analytics-client.json"
## 대기열의 개수 상한. 넘으면 오래된 것부터 버린다.
const QUEUE_LIMIT := 200
## 대기열에 이벤트가 있으면 이 간격(초)으로 보낸다. 한 요청 분량이 차면 기다리지 않는다.
const FLUSH_SECONDS := 15.0
## 전송에 연달아 실패한 횟수에 따른 다음 시도까지의 초.
const RETRY_SECONDS: Array[float] = [15.0, 60.0, 300.0]
const SEND_TIMEOUT_SECONDS := 10.0
const RESPONSE_MAX_BYTES := 4096
const DAY_SECONDS := 86400
## 한 번에 세는 시간의 상한. 백그라운드에서 돌아온 첫 프레임의 긴 간격을 플레이한 시간으로 세지 않는다.
const MAX_STEP_SECONDS := 1.0

var _values: ServiceValues
## read(name), write(name, data), remove(name)을 가진 파일 저장(FaJsonFiles).
var _files: RefCounted
## 요청을 보내는 함수. (request: Dictionary, on_done: Callable)을 받는다(FaHttp.send).
var _transport: Callable
## 문의 상태(GATE_*)를 돌려주는 함수.
var _gate: Callable
## 현재 시각(유닉스 초, 실수)을 돌려주는 함수.
var _now: Callable
var _release_version: String
var _debug_build: bool

var _enabled: bool = false
## 아직 보내지 않은 이벤트(오래된 것이 앞).
var _queue: Array[Dictionary] = []
## 지금 요청에 실어 보낸 이벤트. 실패하면 대기열 앞으로 되돌린다.
var _sending: Array[Dictionary] = []
var _in_flight: bool = false
## 버린 뒤에 도착한 응답을 걸러 내는 번호.
var _generation: int = 0
## 기기의 대기열과 식별자를 읽었는지. 문이 처음 열릴 때 읽는다.
var _storage_loaded: bool = false
var _dirty: bool = false
var _client: Dictionary = {}
## 식별자를 이번에 처음 만들었는지. 첫 실행 이벤트를 한 번 보내는 데 쓴다.
var _first_run: bool = false
var _session_id: String = ""
var _session_started: float = 0.0
var _session_announced: bool = true
## 지난 이벤트 뒤로 게임이 화면 앞에서 돌아간 밀리초.
var _engaged_msec: float = 0.0
var _since_flush: float = 0.0
var _failures: int = 0
var _retry_in: float = -1.0
## 문이 닫힌 것을 보고 이미 버렸는지. 닫혀 있는 동안 프레임마다 파일을 건드리지 않게 한다.
var _closed_seen: bool = false


func _init(
		values: ServiceValues, files: RefCounted, transport: Callable, gate: Callable, now: Callable,
		release_version: String, debug_build: bool) -> void:
	_values = values
	_files = files
	_transport = transport
	_gate = gate
	_now = now
	_release_version = release_version
	_debug_build = debug_build


## 설정의 분석 허용을 받는다. 켤 수 있으면(측정 값이 있고 문이 닫혀 있지 않으면) true를 돌려준다.
## 끄거나 켤 수 없으면 대기 중인 이벤트를 버린다.
func set_enabled(enabled: bool) -> bool:
	_enabled = enabled and _values.analytics_configured() and _gate_state() != GATE_CLOSED
	if not _enabled:
		discard_pending()
	return _enabled


## 대기 중인 이벤트와 기기에 저장한 대기열을 버린다. 보내는 중인 요청의 결과는 무시한다.
func discard_pending() -> void:
	_generation += 1
	_queue.clear()
	_sending.clear()
	_in_flight = false
	_dirty = false
	_retry_in = -1.0
	_failures = 0
	_files.remove(QUEUE_FILE)


## 새 실행(세션)을 시작한다. 앱을 켰을 때와, 오래 백그라운드에 있다가 돌아왔을 때 부른다.
func begin_session() -> void:
	_session_started = _now.call()
	_session_id = str(int(_session_started))
	_session_announced = false
	_engaged_msec = 0.0


func log_event(name: String, params: Dictionary) -> void:
	if not _enabled:
		return
	var gate: int = _observe_gate()
	if gate == GATE_CLOSED:
		return
	if gate == GATE_OPEN:
		_open_storage()
	_append(WIRE_NAMES.get(name, name), params, _now.call())


## 게임이 화면 앞에서 돌아간 시간을 더한다. 문이 바뀐 것을 반영하고, 보낼 때가 됐으면 보낸다.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var step: float = minf(seconds, MAX_STEP_SECONDS)
	_engaged_msec += step * 1000.0
	if not _enabled:
		return
	if _observe_gate() != GATE_OPEN:
		return
	_open_storage()
	_save_if_dirty()
	if _retry_in >= 0.0:
		_retry_in -= step
		if _retry_in <= 0.0:
			_send()
		return
	_since_flush += step
	if _since_flush >= FLUSH_SECONDS or _queue.size() >= Events.MAX_EVENTS_PER_REQUEST:
		_send()


## 기다리지 않고 지금 보낸다. 백그라운드로 가거나 끝날 때 부른다.
func flush() -> void:
	if not _enabled or _observe_gate() != GATE_OPEN:
		return
	_open_storage()
	_save_if_dirty()
	_send()


## 아직 보내지 않은 이벤트 수(보내는 중인 것 포함). 검수와 프로브에서 쓴다.
func pending_count() -> int:
	return _queue.size() + _sending.size()


func _gate_state() -> int:
	return int(_gate.call())


## 지금의 문. 닫힌 것을 처음 보면 들고 있던 것과 저장한 것을 버린다.
func _observe_gate() -> int:
	var gate: int = _gate_state()
	if gate != GATE_CLOSED:
		_closed_seen = false
	elif not _closed_seen:
		_closed_seen = true
		discard_pending()
	return gate


## 문이 처음 열릴 때 기기의 대기열과 식별자를 읽고(식별자가 없으면 만든다), 이번 실행을 알리는 이벤트를 넣는다.
func _open_storage() -> void:
	if not _storage_loaded:
		_storage_loaded = true
		var stored: Array[Dictionary] = Events.restore(_files.read(QUEUE_FILE), _now.call(), QUEUE_LIMIT)
		if not stored.is_empty():
			stored.append_array(_queue)
			_queue = Events.trim(stored, QUEUE_LIMIT)
			_dirty = true
		_client = _read_client()
		if _client.is_empty():
			_first_run = true
			var created: int = int(_now.call())
			var random: PackedByteArray = Crypto.new().generate_random_bytes(4)
			# 기기에서 한 번 만드는 임의 식별자. GA의 웹 식별자와 같은 "숫자.숫자" 꼴이다.
			_client = {"client_id": "%d.%d" % [random.decode_u32(0), created], "created": created, "sessions": 0}
			_files.write(CLIENT_FILE, _client)
	if _session_announced:
		return
	_session_announced = true
	_client["sessions"] = int(_client["sessions"]) + 1
	_files.write(CLIENT_FILE, _client)
	var session: Dictionary = {
		"session_index": _client["sessions"],
		"days_since_install": maxi(0, floori((_session_started - float(_client["created"])) / DAY_SECONDS)),
	}
	if _first_run:
		_first_run = false
		_append("app_first_run", session, _session_started)
	_append("app_session", session, _session_started)


func _read_client() -> Dictionary:
	var raw: Variant = _files.read(CLIENT_FILE)
	if not raw is Dictionary or not raw.get("client_id") is String or raw["client_id"].is_empty():
		return {}
	for key: String in ["created", "sessions"]:
		if not (raw.get(key) is int or raw.get(key) is float):
			return {}
	return {"client_id": raw["client_id"], "created": int(raw["created"]), "sessions": int(raw["sessions"])}


func _append(name: String, params: Dictionary, unix_seconds: float) -> void:
	if _session_id.is_empty():
		begin_session()
	var merged: Dictionary = params.duplicate()
	merged["platform"] = PLATFORM
	merged["app_market"] = APP_MARKET
	merged["release_version"] = _release_version
	merged["session_id"] = _session_id
	merged["engagement_time_msec"] = maxi(1, int(_engaged_msec))
	if _debug_build:
		merged["debug_mode"] = 1
	var problem: String = Events.problem(name, merged)
	if not problem.is_empty():
		if _debug_build:
			push_warning("analytics event dropped (%s): %s" % [problem, name])
		return
	_engaged_msec = 0.0
	_queue.append(Events.entry(name, merged, unix_seconds))
	_queue = Events.trim(_queue, QUEUE_LIMIT)
	_dirty = true


func _save_if_dirty() -> void:
	if not _dirty:
		return
	_dirty = false
	var stored: Array[Dictionary] = _sending.duplicate()
	stored.append_array(_queue)
	if stored.is_empty():
		_files.remove(QUEUE_FILE)
	else:
		_files.write(QUEUE_FILE, stored)


func _send() -> void:
	_since_flush = 0.0
	if _in_flight:
		return
	var fresh: Array[Dictionary] = Events.fresh(_queue, _now.call())
	if fresh.size() != _queue.size():
		_queue = fresh
		_dirty = true
		_save_if_dirty()
	if _queue.is_empty():
		return
	_retry_in = -1.0
	_sending = _queue.slice(0, Events.MAX_EVENTS_PER_REQUEST)
	_queue = _queue.slice(_sending.size())
	_in_flight = true
	var generation: int = _generation
	_transport.call({
		"method": "POST",
		"url": "%s?measurement_id=%s&api_secret=%s" % [
			ENDPOINT, _values.measurement_id().uri_encode(), _values.api_secret().uri_encode()],
		"body": JSON.stringify(Events.payload(str(_client.get("client_id", "")), _sending)),
		"timeout": SEND_TIMEOUT_SECONDS,
		"max_bytes": RESPONSE_MAX_BYTES,
	}, func(response: Dictionary) -> void:
		if generation == _generation:
			_sent(response))


func _sent(response: Dictionary) -> void:
	_in_flight = false
	var status: int = int(response.get("status", 0))
	var delivered: bool = bool(response.get("ok", false)) and status >= 200 and status < 300
	# 받는 쪽이 요청을 거부했으면(4xx) 같은 요청을 다시 보내도 결과가 같으므로 버린다. 408과 429는 다시 보낸다.
	var rejected: bool = status >= 400 and status < 500 and status != 408 and status != 429
	if delivered or rejected:
		_sending.clear()
		_failures = 0
		_dirty = true
		_save_if_dirty()
		if not _queue.is_empty():
			_send()
		return
	_sending.append_array(_queue)
	_queue = Events.trim(_sending, QUEUE_LIMIT)
	_sending = []
	_failures += 1
	_retry_in = RETRY_SECONDS[mini(_failures, RETRY_SECONDS.size()) - 1]
	_dirty = true
	_save_if_dirty()
