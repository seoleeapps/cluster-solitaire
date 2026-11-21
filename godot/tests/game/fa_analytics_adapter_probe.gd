extends SceneTree
## 분석 어댑터 검사: 이름과 길이 제한, 모든 이벤트에 붙는 값, 25개 묶음, 보내지 않는 조건(설정, 동의, 측정 값),
## 대기열 상한과 72시간 만료, 전송 실패와 다시 시도, 기기 저장과 다음 실행, 실행 시작 이벤트, 데이터 초기화.
## 전송과 파일, 시계는 메모리 안의 대역으로 바꿔 끼운다. 네트워크를 쓰지 않는다.

const Events := preload("res://game/adapters/fa_ga4_events.gd")
const Analytics := preload("res://game/adapters/fa_ga4_analytics.gd")
const Memory := preload("res://game/adapters/fa_memory_analytics.gd")
const Values := preload("res://game/adapters/fa_service_values.gd")
const JsonFiles := preload("res://game/adapters/fa_json_files.gd")
const AnalyticsPreference := preload("res://addons/seorilabs_game/services/analytics_preference.gd")

const NOON := 1800000000.0
const MEASUREMENT_ID := "G-PROBE12345"
const API_SECRET := "probe_secret_value"

var _checks: int = 0
var _failed: PackedStringArray = []
var _rigs: Array[Rig] = []


## 파일 대역. 실제 파일처럼 JSON 글자로 바꿔 두므로 다시 읽으면 정수가 실수로 돌아온다.
class MemoryFiles extends RefCounted:
	var texts: Dictionary = {}
	var writes: int = 0
	var removes: int = 0

	func read(name: String) -> Variant:
		if not texts.has(name):
			return null
		var parser: JSON = JSON.new()
		return parser.data if parser.parse(texts[name]) == OK else null

	func write(name: String, data: Variant) -> bool:
		texts[name] = JSON.stringify(data)
		writes += 1
		return true

	func remove(name: String) -> void:
		texts.erase(name)
		removes += 1


## 전송 대역. 요청을 적어 두고, 검사가 원하는 때에 답한다.
class FakeTransport extends RefCounted:
	var requests: Array[Dictionary] = []
	var waiting: Array[Callable] = []

	func send(request: Dictionary, on_done: Callable) -> void:
		requests.append(request)
		waiting.append(on_done)

	func reply(ok: bool, status: int) -> void:
		var on_done: Callable = waiting.pop_front()
		on_done.call({"ok": ok, "status": status, "text": ""})

	func body(index: int) -> Dictionary:
		return JSON.parse_string(requests[index]["body"])

	func names(index: int) -> Array:
		return body(index)["events"].map(func(event: Dictionary) -> String: return event["name"])


## 검사 하나가 쓰는 것들: 어댑터, 파일, 전송, 문, 시계.
class Rig extends RefCounted:
	var files: MemoryFiles = MemoryFiles.new()
	var transport: FakeTransport = FakeTransport.new()
	var gate: int = Analytics.GATE_OPEN
	var now: float = NOON
	var analytics: Analytics

	func build(configured: bool = true, debug_build: bool = false, release_version: String = "1.0.0") -> Analytics:
		var text: String = JSON.stringify({"ga4_measurement_id": MEASUREMENT_ID, "ga4_api_secret": API_SECRET}) if configured else ""
		analytics = Analytics.new(
			Values.from_text(text, false), files, transport.send,
			func() -> int: return gate, func() -> float: return now, release_version, debug_build)
		return analytics

	## 0.5초씩 seconds초를 흘린다.
	func run(seconds: float) -> void:
		for _step: int in int(round(seconds * 2.0)):
			analytics.advance(0.5)

	func stored() -> Array:
		var raw: Variant = files.read(Analytics.QUEUE_FILE)
		return raw if raw is Array else []

	## 어댑터와 서로 붙들고 있는 것을 놓는다.
	func release() -> void:
		analytics = null
		transport.waiting.clear()


func _initialize() -> void:
	_section("이름과 길이 제한", _limits)
	_section("모든 이벤트에 붙는 값", _common_params)
	_section("25개 묶음", _batching)
	_section("보내지 않는 조건", _conditions)
	_section("동의를 기다리는 동안", _waiting_for_consent)
	_section("끄면 버린다", _turning_off)
	_section("대기열 상한과 만료", _queue_limits)
	_section("전송 실패와 다시 시도", _failures)
	_section("기기 저장과 다음 실행", _restart)
	_section("실행 시작 이벤트", _sessions)
	_section("데이터 초기화", _forget_device)
	_section("공통 흐름의 분석 선택", _preference)
	_section("메모리 기록 대역", _memory_double)
	_section("실제 파일 저장", _real_files)
	for rig: Rig in _rigs:
		rig.release()
	print("Fa analytics adapter probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _rig() -> Rig:
	var rig: Rig = Rig.new()
	_rigs.append(rig)
	return rig


## 요청 본문에 소수점이 붙은 정수(12.0 같은 것)가 있는지.
func _has_decimal_whole(body: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("[0-9]\\.0[,}\\]]")
	return regex.search(body) != null


## 켜진 어댑터. 실행 시작 이벤트(app_first_run, app_session)는 이미 보내 대기열이 비어 있다.
func _started(rig: Rig) -> Analytics:
	var analytics: Analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	analytics.flush()
	rig.transport.reply(true, 204)
	rig.transport.requests.clear()
	return analytics


func _limits() -> bool:
	_check(Events.problem("level_start", {"mode": "journey", "level": 3}) == "", "보통 이벤트는 문제없다")
	_check(Events.problem("a", {}) == "" and Events.problem("A1_b", {}) == "", "글자로 시작하는 짧은 이름")
	_check(Events.problem("e".repeat(40), {}) == "", "이름 40자는 된다")
	_check(Events.problem("e".repeat(41), {}) == "bad_name", "이름 41자는 안 된다")
	for name: String in ["", "1level", "_level", "level-start", "level start", "레벨", "level.start"]:
		_check(Events.problem(name, {}) == "bad_name", "쓸 수 없는 이름: '%s'" % name)
	for name: String in ["session_start", "first_open", "user_engagement", "app_update", "ad_reward", "error", "notification_open", "ad_impression", "screen_view", "in_app_purchase"]:
		_check(Events.problem(name, {}) == "reserved_name", "예약된 이름: " + name)
	_check(Events.RESERVED_EVENTS.size() == 34, "예약된 이름은 문서의 31개와 앱 스트림 전용 3개다")

	var many: Dictionary = {}
	for index: int in 25:
		many["p%d" % index] = index
	_check(Events.problem("share", many) == "", "매개변수 25개는 된다")
	many["one_more"] = 1
	_check(Events.problem("share", many) == "too_many_params", "매개변수 26개는 안 된다")
	_check(Events.problem("share", {"p".repeat(40): 1}) == "", "매개변수 이름 40자는 된다")
	_check(Events.problem("share", {"p".repeat(41): 1}) == "bad_param_name", "매개변수 이름 41자는 안 된다")
	for key: String in ["1p", "p-q", "p q", ""]:
		_check(Events.problem("share", {key: 1}) == "bad_param_name", "쓸 수 없는 매개변수 이름: '%s'" % key)
	_check(Events.problem("share", {7: 1}) == "bad_param_name", "글자가 아닌 열쇠")
	for key: String in ["_p", "firebase_x", "ga_session", "google_x", "gtag.x", "firebase_conversion"]:
		_check(Events.problem("share", {key: 1}) == "reserved_param", "예약된 매개변수: " + key)
	_check(Events.problem("share", {"text": "x".repeat(100)}) == "", "값 100자는 된다")
	_check(Events.problem("share", {"text": "x".repeat(101)}) == "value_too_long", "값 101자는 안 된다")
	_check(Events.problem("share", {"text": "가".repeat(100)}) == "", "길이는 글자 수로 센다")
	for value: Variant in [null, [1], {"a": 1}, NAN, INF, Vector2.ZERO]:
		_check(Events.problem("share", {"value": value}) == "bad_value", "보낼 수 없는 값: " + str(value))
	_check(Events.problem("share", {"a": true, "b": 3, "c": 1.5, "d": "x"}) == "", "참 거짓, 정수, 실수, 글자는 된다")
	_check(Events.clean_params({"a": true, "b": false, "c": 3.0, "d": 1.5, "e": "x", "f": 7}) == {"a": 1, "b": 0, "c": 3, "d": 1.5, "e": "x", "f": 7}, "참 거짓은 1과 0, 정수인 실수는 정수로 보낸다")
	_check(typeof(Events.clean_params({"c": 3.0})["c"]) == TYPE_INT, "정수로 바뀐 값의 형은 정수다")
	return true


func _common_params() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	rig.run(2.0)
	rig.now = NOON + 2.0
	analytics.log_event("level_end", {"mode": "journey", "level": 12, "success": true, "continue_used": false})
	analytics.flush()
	var request: Dictionary = rig.transport.requests[0]
	_check(request["method"] == "POST", "POST로 보낸다")
	_check(request["url"] == "https://www.google-analytics.com/mp/collect?measurement_id=%s&api_secret=%s" % [MEASUREMENT_ID, API_SECRET], "수집 주소에 측정 ID와 비밀값을 싣는다")
	_check(request["timeout"] > 0.0 and request["max_bytes"] > 0, "시간과 응답 크기 제한이 있다")
	var body: Dictionary = rig.transport.body(0)
	_check(body.keys() == ["client_id", "events"], "본문은 client_id와 events다")
	var event: Dictionary = body["events"][0]
	var params: Dictionary = event["params"]
	_check(event["name"] == "level_end" and event["timestamp_micros"] == (NOON + 2.0) * 1000000.0, "이름과 일어난 시각")
	_check(params["runtime_platform"] == "android" and params["app_market"] == "google_play" and params["release_version"] == "1.0.0", "runtime_platform, app_market, release_version")
	_check(params["session_id"] == str(int(NOON)), "session_id는 실행을 시작한 시각이다")
	_check(params["engagement_time_msec"] == 2000.0, "engagement_time_msec은 지난 이벤트 뒤 화면 앞에서 흐른 시간이다")
	_check(params["mode"] == "journey" and params["level"] == 12.0 and params["success"] == 1.0 and params["continue_used"] == 0.0, "게임이 넘긴 값(참 거짓은 1과 0)")
	_check(not params.has("debug_mode"), "릴리스 빌드에는 debug_mode가 없다")
	_check(not _has_decimal_whole(request["body"]) and _has_decimal_whole("{\"a\":12.0}"), "정수는 소수점 없이 보낸다")
	rig.transport.reply(true, 204)

	analytics.log_event("mistake", {"level": 12})
	analytics.flush()
	_check(rig.transport.body(1)["events"][0]["params"]["engagement_time_msec"] == 1.0, "시간이 흐르지 않았으면 1이다")
	rig.transport.reply(true, 204)

	analytics.log_event("share", {"runtime_platform": "ios", "session_id": "mine"})
	analytics.flush()
	var overridden: Dictionary = rig.transport.body(2)["events"][0]["params"]
	_check(overridden["runtime_platform"] == "android" and overridden["session_id"] == str(int(NOON)), "게임이 같은 이름을 넘겨도 공통 값이 이긴다")
	rig.transport.reply(true, 204)

	analytics.log_event("ad_impression", {"placement": "rewarded_booster", "format": "rewarded"})
	analytics.flush()
	_check(rig.transport.names(3) == ["ad_shown"], "ad_impression은 웹 스트림이 받는 이름으로 바꿔 보낸다")
	rig.transport.reply(true, 204)

	var crowded: Dictionary = {}
	for index: int in 21:
		crowded["p%d" % index] = index
	analytics.log_event("too_many", crowded)
	analytics.log_event("session_start", {})
	analytics.log_event("bad-name", {})
	analytics.log_event("long_value", {"text": "x".repeat(101)})
	_check(analytics.pending_count() == 0, "제한을 어긴 이벤트는 버린다(공통 값 5개를 더해 26개가 되는 것 포함)")
	crowded.erase("p20")
	analytics.log_event("just_fits", crowded)
	_check(analytics.pending_count() == 1, "공통 값을 더해 25개면 보낸다")

	var debug_rig: Rig = _rig()
	var debug: Analytics = debug_rig.build(true, true, "2.3.4")
	debug.begin_session()
	debug.set_enabled(true)
	debug.log_event("share", {})
	debug.flush()
	var debug_params: Dictionary = debug_rig.transport.body(0)["events"][0]["params"]
	_check(debug_params["debug_mode"] == 1.0 and debug_params["release_version"] == "2.3.4", "디버그 빌드는 debug_mode를 싣는다")
	return true


func _batching() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	for index: int in 60:
		analytics.log_event("mistake", {"level": index})
	_check(rig.transport.requests.is_empty(), "기록만으로는 보내지 않는다")
	analytics.advance(0.5)
	_check(rig.transport.requests.size() == 1 and rig.transport.body(0)["events"].size() == 25, "한 요청 분량이 차면 다음 프레임에 25개를 보낸다")
	_check(analytics.pending_count() == 60, "답을 받기 전에는 대기열에서 빼지 않는다")
	rig.run(60.0)
	analytics.flush()
	_check(rig.transport.requests.size() == 1, "보내는 중에는 또 보내지 않는다")
	rig.transport.reply(true, 204)
	_check(rig.transport.requests.size() == 2 and rig.transport.body(1)["events"].size() == 25 and analytics.pending_count() == 35, "성공하면 이어서 다음 25개를 보낸다")
	rig.transport.reply(true, 200)
	_check(rig.transport.requests.size() == 3 and rig.transport.body(2)["events"].size() == 10, "남은 10개를 보낸다")
	rig.transport.reply(true, 204)
	_check(analytics.pending_count() == 0 and rig.transport.requests.size() == 3, "다 보내면 멈춘다")
	var levels: Array = []
	for index: int in 3:
		for event: Dictionary in rig.transport.body(index)["events"]:
			levels.append(int(event["params"]["level"]))
	_check(levels == range(60), "순서대로, 빠짐없이, 한 번씩 보낸다")

	analytics.log_event("share", {})
	rig.run(Analytics.FLUSH_SECONDS - 1.0)
	_check(rig.transport.requests.size() == 3, "분량이 차지 않으면 간격을 기다린다")
	rig.run(1.5)
	_check(rig.transport.requests.size() == 4 and rig.transport.names(3) == ["share"], "간격이 지나면 보낸다")
	rig.transport.reply(true, 204)
	rig.run(60.0)
	_check(rig.transport.requests.size() == 4, "보낼 것이 없으면 요청하지 않는다")
	return true


func _conditions() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = rig.build(false)
	analytics.begin_session()
	_check(not analytics.set_enabled(true), "측정 값이 없으면 켤 수 없다")
	analytics.log_event("share", {})
	analytics.flush()
	rig.run(60.0)
	_check(analytics.pending_count() == 0 and rig.transport.requests.is_empty() and rig.files.writes == 0, "측정 값이 없으면 모으지도 보내지도 쓰지도 않는다")

	rig = _rig()
	analytics = rig.build()
	analytics.begin_session()
	analytics.log_event("share", {})
	analytics.flush()
	rig.run(60.0)
	_check(analytics.pending_count() == 0 and rig.transport.requests.is_empty() and rig.files.writes == 0, "설정을 받기 전에는 꺼진 것으로 본다")
	_check(not analytics.set_enabled(false), "끄면 false다")
	analytics.log_event("share", {})
	rig.run(60.0)
	_check(analytics.pending_count() == 0 and rig.transport.requests.is_empty() and rig.files.writes == 0, "설정에서 꺼져 있으면 모으지 않는다")
	_check(analytics.set_enabled(true), "측정 값이 있고 문이 열려 있으면 켜진다")
	analytics.log_event("share", {})
	_check(analytics.pending_count() == 3, "켜면 모은다(실행 시작 이벤트 둘과 함께)")

	rig = _rig()
	rig.gate = Analytics.GATE_CLOSED
	analytics = rig.build()
	analytics.begin_session()
	_check(not analytics.set_enabled(true), "문이 닫혀 있으면(규제 지역) 켤 수 없다")
	analytics.log_event("share", {})
	analytics.flush()
	rig.run(60.0)
	_check(analytics.pending_count() == 0 and rig.transport.requests.is_empty() and rig.files.writes == 0, "규제 지역에서는 모으지도 보내지도 쓰지도 않는다")

	rig = _rig()
	analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	analytics.log_event("share", {})
	analytics.advance(0.5)
	_check(not rig.stored().is_empty(), "문이 열려 있으면 못 보낸 이벤트를 기기에 저장한다")
	rig.gate = Analytics.GATE_CLOSED
	analytics.log_event("share", {})
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "켜진 뒤에 문이 닫히면 들고 있던 것과 저장한 것을 버린다")
	rig.gate = Analytics.GATE_OPEN
	analytics.log_event("share", {})
	rig.gate = Analytics.GATE_CLOSED
	analytics.advance(0.5)
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "기록이 없어도 다음 프레임에 버린다")
	analytics.flush()
	_check(rig.transport.requests.is_empty(), "문이 닫혀 있으면 보내지 않는다")
	var removes: int = rig.files.removes
	rig.run(30.0)
	analytics.log_event("share", {})
	_check(rig.files.removes == removes and analytics.pending_count() == 0, "닫혀 있는 동안에는 프레임마다 파일을 건드리지 않는다")
	return true


func _waiting_for_consent() -> bool:
	var rig: Rig = _rig()
	rig.gate = Analytics.GATE_WAIT
	var analytics: Analytics = rig.build()
	analytics.begin_session()
	_check(analytics.set_enabled(true), "동의 상태를 기다리는 동안에도 켜 둘 수 있다")
	analytics.log_event("level_start", {"level": 1})
	analytics.log_event("level_end", {"level": 1})
	analytics.flush()
	rig.run(120.0)
	_check(analytics.pending_count() == 2, "기다리는 동안 메모리에 들고 있다")
	_check(rig.transport.requests.is_empty() and rig.files.writes == 0 and rig.files.texts.is_empty(), "기다리는 동안 보내지도, 기기에 쓰지도 않는다")
	for index: int in 300:
		analytics.log_event("mistake", {"level": index})
	_check(analytics.pending_count() == Analytics.QUEUE_LIMIT, "기다리는 동안에도 상한을 넘으면 오래된 것부터 버린다")

	rig = _rig()
	rig.gate = Analytics.GATE_WAIT
	analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	analytics.log_event("level_start", {"level": 1})
	rig.gate = Analytics.GATE_OPEN
	analytics.advance(0.5)
	_check(rig.files.texts.has(Analytics.CLIENT_FILE) and rig.stored().size() == 3, "문이 열리면 식별자를 만들고 들고 있던 것을 저장한다")
	analytics.flush()
	_check(rig.transport.names(0) == ["level_start", "app_first_run", "app_session"], "기다리던 이벤트와 실행 시작 이벤트를 보낸다")
	var events: Array = rig.transport.body(0)["events"]
	_check(events[1]["timestamp_micros"] == NOON * 1000000.0 and events[2]["timestamp_micros"] == NOON * 1000000.0, "실행 시작 이벤트의 시각은 실행을 시작한 때다")

	rig = _rig()
	rig.gate = Analytics.GATE_WAIT
	analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	analytics.log_event("level_start", {"level": 1})
	rig.gate = Analytics.GATE_CLOSED
	analytics.advance(0.5)
	_check(analytics.pending_count() == 0 and rig.files.texts.is_empty() and rig.transport.requests.is_empty(), "규제 지역으로 확정되면 들고 있던 것을 버리고 아무것도 쓰지 않는다")
	return true


func _turning_off() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	for index: int in 30:
		analytics.log_event("mistake", {"level": index})
	analytics.flush()
	_check(rig.transport.requests.size() == 1 and analytics.pending_count() == 30 and rig.stored().size() == 30, "보내는 중인 것과 기다리는 것이 있다")
	analytics.set_enabled(false)
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "끄면 대기 중인 이벤트와 저장한 대기열을 버린다")
	rig.transport.reply(false, 0)
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "끈 뒤에 온 실패 응답으로 되살아나지 않는다")
	rig.run(600.0)
	_check(rig.transport.requests.size() == 1, "끈 뒤에는 다시 보내지 않는다")
	_check(rig.files.texts.has(Analytics.CLIENT_FILE), "식별자는 남긴다")
	analytics.set_enabled(true)
	analytics.log_event("share", {})
	analytics.flush()
	_check(rig.transport.requests.size() == 2 and rig.transport.names(1) == ["share"], "다시 켜면 그 뒤의 이벤트만 보낸다")

	analytics.log_event("share", {})
	analytics.discard_pending()
	rig.transport.reply(true, 204)
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "discard_pending은 켜진 채로 대기열만 비운다")
	analytics.log_event("share", {})
	_check(analytics.pending_count() == 1, "비운 뒤에도 켜져 있다")
	return true


func _queue_limits() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	analytics.flush()
	for index: int in 30:
		analytics.log_event("mistake", {"level": index})
	analytics.flush()
	for index: int in range(30, 260):
		analytics.log_event("mistake", {"level": index})
	_check(analytics.pending_count() == 25 + Analytics.QUEUE_LIMIT, "보내는 중인 25개와 대기열 200개까지 든다")
	rig.transport.reply(false, 0)
	_check(analytics.pending_count() == Analytics.QUEUE_LIMIT, "실패해 되돌려도 200개를 넘지 않는다")
	_check(rig.stored().size() == Analytics.QUEUE_LIMIT and int(rig.stored()[0]["params"]["level"]) == 60, "넘친 만큼 오래된 것부터 버린다")
	_check(int(rig.stored()[-1]["params"]["level"]) == 259, "새 이벤트는 남는다")

	rig = _rig()
	analytics = _started(rig)
	analytics.log_event("old_event", {})
	rig.now = NOON + 71.0 * 3600.0
	analytics.log_event("new_event", {})
	rig.now = NOON + 72.0 * 3600.0 + 60.0
	analytics.flush()
	_check(rig.transport.names(0) == ["new_event"], "72시간이 지난 이벤트는 보내지 않고 버린다")
	_check(Events.MAX_AGE_SECONDS == 72 * 3600, "만료 기준은 72시간이다")
	rig.transport.reply(true, 204)

	var entries: Array[Dictionary] = [Events.entry("a", {}, NOON), Events.entry("b", {}, NOON + 10.0)]
	_check(Events.fresh(entries, NOON + 72.0 * 3600.0).size() == 2, "정확히 72시간은 남긴다")
	_check(Events.fresh(entries, NOON + 72.0 * 3600.0 + 5.0).size() == 1, "72시간을 넘긴 것만 뺀다")
	_check(Events.trim(entries, 1) == [entries[1]] and Events.trim(entries, 5) == entries, "상한을 넘으면 앞부터 버린다")
	return true


func _failures() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	analytics.log_event("share", {})
	analytics.flush()
	rig.transport.reply(false, 0)
	_check(analytics.pending_count() == 1 and rig.stored().size() == 1, "연결에 실패하면 이벤트를 남긴다")
	analytics.log_event("mistake", {})
	rig.run(14.0)
	_check(rig.transport.requests.size() == 1, "15초 전에는 다시 보내지 않는다")
	rig.run(1.5)
	_check(rig.transport.requests.size() == 2 and rig.transport.names(1) == ["share", "mistake"], "15초 뒤 순서를 지켜 다시 보낸다")
	rig.transport.reply(true, 500)
	rig.run(59.0)
	_check(rig.transport.requests.size() == 2, "두 번째 실패(서버 오류) 뒤에는 60초를 기다린다")
	rig.run(1.5)
	_check(rig.transport.requests.size() == 3, "60초 뒤 다시 보낸다")
	rig.transport.reply(true, 429)
	rig.run(299.0)
	_check(rig.transport.requests.size() == 3, "세 번째 실패(요청 과다) 뒤에는 300초를 기다린다")
	rig.run(1.5)
	rig.transport.reply(true, 503)
	rig.run(299.0)
	_check(rig.transport.requests.size() == 4, "간격은 300초에서 더 늘지 않는다")
	rig.run(1.5)
	_check(rig.transport.requests.size() == 5 and analytics.pending_count() == 2, "계속 남겨 두고 다시 보낸다")
	rig.transport.reply(true, 204)
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "성공하면 대기열과 저장을 비운다")

	analytics.log_event("share", {})
	analytics.flush()
	rig.transport.reply(true, 400)
	_check(analytics.pending_count() == 0, "받는 쪽이 거부한 요청(4xx)은 다시 보내지 않고 버린다")
	analytics.log_event("share", {})
	rig.run(Analytics.FLUSH_SECONDS + 0.5)
	_check(rig.transport.requests.size() == 7, "거부 뒤에는 보통 간격으로 돌아간다")
	rig.transport.reply(true, 408)
	_check(analytics.pending_count() == 1, "시간 초과(408)는 남겨 두고 다시 보낸다")
	return true


func _restart() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	var client: Dictionary = rig.files.read(Analytics.CLIENT_FILE)
	analytics.log_event("level_start", {"level": 4})
	analytics.log_event("level_end", {"level": 4, "success": true})
	analytics.flush()
	rig.transport.reply(false, 0)
	_check(rig.stored().size() == 2, "못 보낸 이벤트가 기기에 남는다")

	# 앱을 다시 켠다: 같은 파일, 새 어댑터.
	rig.now = NOON + 3600.0
	rig.transport = FakeTransport.new()
	analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	_check(analytics.pending_count() == 0, "문이 열리기 전에는 기기의 대기열을 읽지 않는다")
	analytics.flush()
	_check(rig.transport.names(0) == ["level_start", "level_end", "app_session"], "지난 실행의 이벤트를 먼저, 순서대로 보낸다")
	var events: Array = rig.transport.body(0)["events"]
	_check(rig.transport.body(0)["client_id"] == client["client_id"], "식별자는 실행이 바뀌어도 같다")
	_check(events[0]["timestamp_micros"] == NOON * 1000000.0 and events[0]["params"]["session_id"] == str(int(NOON)), "지난 이벤트는 일어난 때의 시각과 실행을 지닌다")
	_check(events[2]["params"]["session_id"] == str(int(NOON + 3600.0)), "새 이벤트는 새 실행을 지닌다")
	_check(not _has_decimal_whole(rig.transport.requests[0]["body"]), "저장했다 읽은 정수도 소수점 없이 보낸다")
	rig.transport.reply(true, 204)

	rig.files.texts[Analytics.QUEUE_FILE] = JSON.stringify([
		{"name": "kept", "params": {"level": 1.0}, "timestamp_micros": (NOON + 3000.0) * 1000000.0},
		{"name": "expired", "params": {}, "timestamp_micros": (NOON - 80.0 * 3600.0) * 1000000.0},
		{"name": "session_start", "params": {}, "timestamp_micros": NOON * 1000000.0},
		{"name": "no_stamp", "params": {}},
		{"name": "bad_params", "params": [1], "timestamp_micros": NOON * 1000000.0},
		"not an event", 7, null,
	])
	rig.transport = FakeTransport.new()
	analytics = rig.build()
	analytics.set_enabled(true)
	analytics.flush()
	_check(rig.transport.names(0) == ["kept"], "저장된 것 가운데 만료됐거나 형식이 틀린 항목은 버린다")
	rig.transport.reply(true, 204)

	for broken: String in ["{not json", "{\"a\": 1}", "\"text\"", ""]:
		rig.files.texts[Analytics.QUEUE_FILE] = broken
		rig.files.texts[Analytics.CLIENT_FILE] = broken
		rig.transport = FakeTransport.new()
		analytics = rig.build()
		analytics.begin_session()
		analytics.set_enabled(true)
		analytics.flush()
		_check(rig.transport.names(0) == ["app_first_run", "app_session"], "읽을 수 없는 저장은 없는 것으로 보고 새로 시작한다: " + broken)
		_check(str(rig.transport.body(0)["client_id"]).length() > 3, "식별자를 새로 만든다")
	return true


func _sessions() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	analytics.flush()
	_check(rig.transport.names(0) == ["app_first_run", "app_session"], "첫 실행은 app_first_run과 app_session을 보낸다")
	var first: Dictionary = rig.transport.body(0)
	var client_id: String = first["client_id"]
	var parts: PackedStringArray = client_id.split(".")
	_check(parts.size() == 2 and parts[0].is_valid_int() and parts[1] == str(int(NOON)), "식별자는 '임의 수.만든 시각' 꼴이다")
	_check(first["events"][0]["params"]["session_index"] == 1.0 and first["events"][0]["params"]["days_since_install"] == 0.0, "첫 실행의 번호는 1, 지난 날은 0이다")
	rig.transport.reply(true, 204)
	analytics.flush()
	rig.run(60.0)
	_check(rig.transport.requests.size() == 1, "실행 시작 이벤트는 실행마다 한 번이다")

	# 오래 백그라운드에 있다가 돌아왔다: 같은 어댑터의 새 실행.
	rig.now = NOON + 2.0 * 86400.0 + 100.0
	analytics.begin_session()
	analytics.log_event("level_start", {"level": 2})
	analytics.flush()
	_check(rig.transport.names(1) == ["app_session", "level_start"], "새 실행은 app_session만 보낸다")
	var second: Dictionary = rig.transport.body(1)["events"][0]["params"]
	_check(second["session_index"] == 2.0 and second["days_since_install"] == 2.0, "실행 번호가 오르고 설치 뒤 지난 날을 싣는다")
	_check(second["session_id"] == str(int(rig.now)) and rig.transport.body(1)["client_id"] == client_id, "실행은 새것, 식별자는 그대로다")
	rig.transport.reply(true, 204)

	# 앱을 다시 켰다.
	rig.now = NOON + 9.0 * 86400.0
	rig.transport = FakeTransport.new()
	analytics = rig.build()
	analytics.begin_session()
	analytics.set_enabled(true)
	analytics.flush()
	var third: Dictionary = rig.transport.body(0)["events"][0]
	_check(rig.transport.names(0) == ["app_session"] and third["params"]["session_index"] == 3.0 and third["params"]["days_since_install"] == 9.0, "다시 켠 뒤에도 번호와 날 수가 이어진다")

	var ids: Dictionary = {}
	for _index: int in 20:
		var other: Rig = _rig()
		var adapter: Analytics = other.build()
		adapter.begin_session()
		adapter.set_enabled(true)
		adapter.flush()
		ids[other.transport.body(0)["client_id"]] = true
	_check(ids.size() >= 19, "식별자는 기기마다 다르다")
	return true


## 설정의 데이터 초기화: 식별자 파일과 대기열을 지우고, 다음 전송은 새 식별자의 첫 실행으로 시작한다.
func _forget_device() -> bool:
	var rig: Rig = _rig()
	var analytics: Analytics = _started(rig)
	var old_client: String = rig.files.read(Analytics.CLIENT_FILE)["client_id"]
	analytics.log_event("level_start", {"level": 4})
	analytics.flush()
	var late: Callable = rig.transport.waiting[0]
	analytics.log_event("level_end", {"level": 4, "success": true})
	analytics.advance(0.5)
	_check(rig.stored().size() == 2 and rig.files.read(Analytics.CLIENT_FILE) != null, "초기화 전: 대기열과 식별자가 기기에 있다")

	rig.now = NOON + 600.0
	analytics.forget_device()
	_check(rig.files.read(Analytics.CLIENT_FILE) == null and rig.files.read(Analytics.QUEUE_FILE) == null, "식별자 파일과 대기열 파일을 지운다")
	_check(analytics.pending_count() == 0, "들고 있던 이벤트와 보내는 중인 것을 버린다")
	late.call({"ok": false, "status": 0, "text": ""})
	_check(analytics.pending_count() == 0 and rig.stored().is_empty(), "초기화 전에 보낸 요청의 실패가 이벤트를 되살리지 않는다")

	rig.transport.requests.clear()
	analytics.log_event("tutorial_begin", {})
	analytics.flush()
	var body: Dictionary = rig.transport.body(rig.transport.requests.size() - 1)
	_check(rig.transport.names(rig.transport.requests.size() - 1) == ["app_first_run", "app_session", "tutorial_begin"], "다음 전송은 첫 실행처럼 app_first_run과 app_session부터다")
	_check(str(body["client_id"]) != old_client and str(body["client_id"]).ends_with("." + str(int(NOON + 600.0))), "새 식별자를 초기화한 때에 만든다")
	_check(body["events"][1]["params"]["session_index"] == 1.0 and body["events"][1]["params"]["session_id"] == str(int(NOON + 600.0)), "실행 번호는 1이고 새 실행이다")
	_check(rig.files.read(Analytics.CLIENT_FILE)["client_id"] == body["client_id"], "새 식별자를 기기에 적는다")

	var off: Rig = _rig()
	var quiet: Analytics = off.build()
	quiet.begin_session()
	quiet.set_enabled(false)
	quiet.forget_device()
	_check(off.files.texts.is_empty() and off.transport.requests.is_empty(), "꺼진 어댑터도 초기화할 수 있고 아무것도 쓰거나 보내지 않는다")
	return true


func _preference() -> bool:
	# 공통 흐름은 설정이 바뀔 때마다 port.set_enabled와 port.discard_pending을 부른다.
	var store: RefCounted = RefCounted.new()
	store.set_script(_store_script())
	var rig: Rig = _rig()
	var analytics: Analytics = rig.build()
	analytics.begin_session()
	var preference: RefCounted = AnalyticsPreference.new()
	preference.port = analytics
	preference.policy_allowed = true
	preference.apply(store)
	_check(preference.effective and preference.reason == "on" and store.analytics_allowed, "설정이 켜져 있으면 켜진다")
	analytics.log_event("share", {})
	_check(analytics.pending_count() == 3, "켜진 동안 모은다")
	store.data["settings"]["analytics"] = false
	preference.apply(store)
	_check(not preference.effective and preference.reason == "off" and analytics.pending_count() == 0, "설정에서 끄면 꺼지고 대기 중인 것을 버린다")
	analytics.log_event("share", {})
	_check(analytics.pending_count() == 0, "꺼진 동안 모으지 않는다")
	store.data["settings"]["analytics"] = true
	preference.apply(store)
	preference.apply(store)
	analytics.log_event("share", {})
	_check(preference.effective and analytics.pending_count() == 1, "다시 켜면 모으고, 같은 설정을 다시 적용해도 버리지 않는다")

	rig = _rig()
	rig.gate = Analytics.GATE_CLOSED
	analytics = rig.build()
	preference = AnalyticsPreference.new()
	preference.port = analytics
	preference.policy_allowed = true
	preference.apply(store)
	_check(not preference.effective and preference.reason == "unavailable", "규제 지역에서는 설정 화면이 수집 제한을 알린다")

	rig = _rig()
	analytics = rig.build(false)
	preference = AnalyticsPreference.new()
	preference.port = analytics
	preference.policy_allowed = true
	preference.apply(store)
	_check(not preference.effective and preference.reason == "unavailable", "측정 값이 없는 빌드도 수집 제한으로 알린다")
	return true


func _store_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nvar data: Dictionary = {\"settings\": {\"analytics\": true}}\nvar analytics_allowed: bool = false\n"
	script.reload()
	return script


func _memory_double() -> bool:
	var memory: Memory = Memory.new()
	var params: Dictionary = {"level": 3}
	memory.log_event("level_start", params)
	params["level"] = 99
	memory.log_event("mistake", {"level": 3})
	memory.log_event("level_start", {"level": 4})
	_check(memory.names() == ["level_start", "mistake", "level_start"], "받은 순서대로 적는다")
	_check(memory.count("level_start") == 2 and memory.count("share") == 0, "이름별 횟수")
	_check(memory.last("level_start") == {"level": 4} and memory.last("share") == {}, "마지막으로 받은 값")
	_check(memory.events[0]["params"] == {"level": 3}, "받은 뒤에 고친 값에 영향받지 않는다")
	memory.forget_device()
	_check(memory.forgotten == 1 and memory.events.size() == 3, "초기화 요청을 세고 받은 기록은 그대로 둔다")
	memory.clear()
	_check(memory.events.is_empty(), "비운다")
	return true


func _real_files() -> bool:
	var dir: String = "user://fa-analytics-probe-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var files: JsonFiles = JsonFiles.new(dir)
	_check(files.read("missing.json") == null, "없는 파일은 null이다")
	_check(files.write("queue.json", [{"name": "a", "params": {"level": 3}}]), "쓴다")
	var read: Variant = files.read("queue.json")
	_check(read is Array and read[0]["name"] == "a" and read[0]["params"]["level"] == 3.0, "쓴 것을 읽는다")
	_check(files.write("queue.json", {"replaced": true}) and files.read("queue.json") == {"replaced": true}, "덮어쓴다")
	_check(not FileAccess.file_exists(dir.path_join("queue.json.tmp")), "임시 파일을 남기지 않는다")
	var file: FileAccess = FileAccess.open(dir.path_join("broken.json"), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(files.read("broken.json") == null, "읽을 수 없는 파일은 null이다")
	files.remove("queue.json")
	files.remove("queue.json")
	_check(files.read("queue.json") == null, "지운다. 없는 파일을 지워도 된다")

	var transport: FakeTransport = FakeTransport.new()
	var text: String = JSON.stringify({"ga4_measurement_id": MEASUREMENT_ID, "ga4_api_secret": API_SECRET})
	var first: Analytics = Analytics.new(Values.from_text(text, false), files, transport.send, func() -> int: return Analytics.GATE_OPEN, func() -> float: return NOON, "1.0.0", false)
	first.begin_session()
	first.set_enabled(true)
	first.log_event("level_start", {"level": 7})
	first.advance(0.5)
	var second_transport: FakeTransport = FakeTransport.new()
	var second: Analytics = Analytics.new(Values.from_text(text, false), files, second_transport.send, func() -> int: return Analytics.GATE_OPEN, func() -> float: return NOON + 60.0, "1.0.0", false)
	second.begin_session()
	second.set_enabled(true)
	second.flush()
	_check(second_transport.names(0) == ["app_first_run", "app_session", "level_start", "app_session"], "실제 파일로도 다음 실행에 이어서 보낸다")

	for name: String in ["broken.json", Analytics.QUEUE_FILE, Analytics.CLIENT_FILE]:
		files.remove(name)
	DirAccess.remove_absolute(dir)
	_check(not DirAccess.dir_exists_absolute(dir), "검사용 폴더를 지운다")
	return true
