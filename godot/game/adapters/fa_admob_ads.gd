class_name FaAdmobAds
extends "res://game/core/ports/fa_ads_port.gd"
## 광고 포트의 실제 구현. 동의(UMP), 초기화, 미리 불러오기, 보여 주기와 결과 판정의 순서를 맡고
## SDK 호출은 FaAdSdk 경계에 맡긴다. 지금 내도 되는지(상한과 간격)는 FaAdPolicy와 FaAdFlow가 정한다.
##
## 순서: start()가 실행마다 동의 정보를 갱신한다. 필요하면 동의 양식을 띄운다.
## 광고를 요청해도 되는 상태(동의가 필요 없거나 받았음)일 때만 SDK를 초기화하고 보상형과 전면을 하나씩 불러 둔다.
## 보여 준 광고는 버리고 다음 것을 불러온다. 불러오기에 실패하면 RETRY_SECONDS의 간격으로 다시 시도한다.
## 동의 상태는 SDK가 기억하고 여기서는 저장하지 않는다.
## 시간은 advance()로 받는다. FaLiveServices가 프레임마다 부른다.

const AdSdk := preload("res://game/adapters/fa_ad_sdk.gd")
const AdShow := preload("res://game/adapters/fa_ad_show.gd")

## 광고가 화면을 덮기 직전에 true, 결과가 정해진 직후(on_result를 부르기 전)에 false로 알린다.
## 화면 쪽은 이 신호로 게임 소리를 멈추고 되돌린다.
signal presenting_changed(active: bool)
## 광고의 준비 여부가 바뀌었다. 광고 버튼을 다시 그릴 때 쓴다.
signal availability_changed
## 동의 상태나 개인정보 선택 요건이 바뀌었을 수 있다. 설정 화면과 분석 어댑터가 다시 읽는다.
signal consent_changed

const FORMAT_REWARDED := "rewarded"
const FORMAT_INTERSTITIAL := "interstitial"
const FORMATS: Array[String] = [FORMAT_REWARDED, FORMAT_INTERSTITIAL]

## 불러오기에 연달아 실패한 횟수에 따른 다음 시도까지의 초. 마지막 값에서 더 늘지 않는다.
const RETRY_SECONDS: Array[float] = [10.0, 30.0, 60.0, 120.0, 300.0]
## 불러오기 답이 이 시간 안에 오지 않으면 실패로 본다.
const LOAD_TIMEOUT_SECONDS := 60.0
## 한 번에 세는 시간의 상한. 백그라운드에서 돌아온 첫 프레임의 긴 간격으로 대기 시간이 한꺼번에 지나가지 않게 한다.
const MAX_STEP_SECONDS := 1.0

var _sdk: AdSdk
## 형식별 광고 단위 ID.
var _units: Dictionary
var _started: bool = false
## 동의 갱신이나 동의 양식이 진행 중인지.
var _consent_busy: bool = false
## 이번 실행의 동의 갱신이 한 번이라도 끝났는지(성공이든 실패든).
var _consent_settled: bool = false
var _consent_failures: int = 0
var _consent_retry_in: float = -1.0
var _initializing: bool = false
var _initialized: bool = false
## 형식별 상태: loaded, loading, failures, retry_in(다음 시도까지 남은 초, 예약이 없으면 음수), waited(답을 기다린 초).
var _slots: Dictionary = {}
var _show: AdShow = null
var _show_result: Callable


func _init(sdk: AdSdk, units: Dictionary) -> void:
	_sdk = sdk
	_units = units.duplicate()
	for format: String in FORMATS:
		_slots[format] = {"loaded": false, "loading": false, "failures": 0, "retry_in": -1.0, "waited": 0.0}


## 연달아 failures번 실패한 뒤 다음 시도까지 기다릴 초.
static func retry_delay(failures: int) -> float:
	return RETRY_SECONDS[clampi(failures, 1, RETRY_SECONDS.size()) - 1]


## 기기 검수용. start() 전에 부르면 UMP가 이 기기를 geography(FaAdSdk.GEOGRAPHY_*)에 있는 것으로 다룬다.
## FaLiveServices가 디버그 빌드에서 실행 인자를 받았을 때만 부른다.
func set_consent_debug(geography: String, device_ids: PackedStringArray) -> void:
	_sdk.set_consent_debug(geography, device_ids)


## 실행마다 한 번 부른다. 동의 정보를 갱신하고, 지난 실행에서 이미 광고를 요청해도 되는 상태였으면 바로 준비를 시작한다.
func start() -> void:
	if _started or not _sdk.available():
		return
	_started = true
	_update_consent()


## 어댑터를 더 쓰지 않을 때 부른다. 불러 둔 광고를 버리고 멈춘다. 떠 있던 광고의 결과는 돌려주지 않는다.
func stop() -> void:
	if not _started:
		return
	_started = false
	_show = null
	_show_result = Callable()
	_consent_retry_in = -1.0
	for format: String in FORMATS:
		_slots[format]["loaded"] = false
		_slots[format]["loading"] = false
		_slots[format]["retry_in"] = -1.0
	_sdk.shutdown()


## 게임이 화면 앞에서 돌아간 시간을 더한다. 다시 시도할 때가 된 일과 떠 있는 광고의 시간 제한을 처리한다.
func advance(seconds: float) -> void:
	if not _started or seconds <= 0.0:
		return
	var step: float = minf(seconds, MAX_STEP_SECONDS)
	if _show != null:
		_show.advance(seconds)
		_settle_show()
	if _consent_retry_in >= 0.0 and not _consent_busy:
		_consent_retry_in -= step
		if _consent_retry_in <= 0.0:
			_update_consent()
	for format: String in FORMATS:
		var slot: Dictionary = _slots[format]
		if slot["loading"]:
			slot["waited"] += step
			if slot["waited"] >= LOAD_TIMEOUT_SECONDS:
				_sdk.discard_ad(format)
				_load_finished(format, false)
		elif slot["retry_in"] >= 0.0:
			slot["retry_in"] -= step
			if slot["retry_in"] <= 0.0:
				_load(format)


## 백그라운드에서 돌아왔을 때 부른다. 동의 상태를 아직 모르면 기다리지 않고 다시 갱신한다.
## 동의 양식이 닫혔다는 알림을 놓쳤을 때를 대비해, 진행 중이면 지금의 동의 상태로 광고 준비를 다시 맞춘다.
func resume() -> void:
	if not _started:
		return
	if _consent_busy:
		_apply_consent()
	elif consent_pending():
		_update_consent()


## 광고를 요청해도 되는지. UMP의 canRequestAds와 같은 조건이다(동의가 필요 없거나 받았음).
func can_request_ads() -> bool:
	if not _started:
		return false
	var status: int = _sdk.consent_status()
	return status == AdSdk.CONSENT_NOT_REQUIRED or status == AdSdk.CONSENT_OBTAINED


## 분석 이벤트를 보내도 되는지. 이번 실행의 동의 갱신이 끝났고 동의가 필요 없는 지역일 때만 참이다.
## 규제 지역(EEA, 영국, 스위스)이거나 아직 모르면 거짓이다(결정 로그 DEC-020).
func analytics_allowed() -> bool:
	return _started and _consent_settled and _sdk.consent_status() == AdSdk.CONSENT_NOT_REQUIRED


## 동의 상태를 아직 모르는지. start() 전이거나 갱신이 끝나지 않았거나, 끝났어도 상태를 받지 못했으면 참이다.
## SDK가 없으면 알아낼 것이 없으므로 거짓이다.
func consent_pending() -> bool:
	return _sdk.available() and (not _consent_settled or _sdk.consent_status() == AdSdk.CONSENT_UNKNOWN)


func is_ready(format: String) -> bool:
	return _slots.has(format) and _slots[format]["loaded"] and _show == null and can_request_ads()


func request(format: String) -> void:
	if _slots.has(format) and _slots[format]["retry_in"] < 0.0:
		_load(format)


func show(format: String, on_result: Callable) -> void:
	if not is_ready(format):
		on_result.call(RESULT_FAILED)
		return
	_slots[format]["loaded"] = false
	var shown: AdShow = AdShow.new(format)
	_show = shown
	_show_result = on_result
	presenting_changed.emit(true)
	_sdk.show_ad(format, func(kind: String) -> void:
		# 이미 끝낸 광고의 늦은 알림은 버린다.
		if _show == shown:
			shown.event(kind)
			_settle_show())


func privacy_choice_required() -> bool:
	return _started and _sdk.privacy_options_required()


func open_privacy_choice() -> void:
	if not privacy_choice_required() or _show != null:
		return
	_sdk.show_privacy_options(_apply_consent)


func _update_consent() -> void:
	_consent_busy = true
	_consent_retry_in = -1.0
	_sdk.update_consent(_consent_updated)
	# 지난 실행에서 받은 동의는 갱신이 끝나기 전에도 유효하다. 광고 준비를 갱신 뒤로 미루지 않는다.
	_apply_consent()


func _consent_updated(ok: bool) -> void:
	if ok and _sdk.consent_status() == AdSdk.CONSENT_REQUIRED and _sdk.consent_form_available():
		_sdk.show_consent_form(func() -> void: _consent_finished(true))
		return
	_consent_finished(ok)


func _consent_finished(ok: bool) -> void:
	_consent_busy = false
	_consent_settled = true
	if not ok and _sdk.consent_status() == AdSdk.CONSENT_UNKNOWN:
		_consent_failures += 1
		_consent_retry_in = retry_delay(_consent_failures)
	else:
		_consent_failures = 0
	_apply_consent()


## 동의 상태에 맞춰 광고 준비를 시작하거나, 요청할 수 없게 됐으면 불러 둔 광고를 버린다.
func _apply_consent() -> void:
	if can_request_ads():
		_prepare()
	else:
		for format: String in FORMATS:
			var slot: Dictionary = _slots[format]
			if _show != null and _show.format == format:
				continue
			if slot["loaded"] or slot["loading"]:
				_sdk.discard_ad(format)
			slot["loaded"] = false
			slot["loading"] = false
			slot["retry_in"] = -1.0
	consent_changed.emit()
	availability_changed.emit()


func _prepare() -> void:
	if _initialized:
		for format: String in FORMATS:
			if _slots[format]["retry_in"] < 0.0:
				_load(format)
		return
	if _initializing:
		return
	_initializing = true
	_sdk.initialize(func() -> void:
		_initializing = false
		_initialized = true
		_sdk.set_max_ad_content_rating(AdSdk.RATING_PG)
		if can_request_ads():
			_prepare())


func _load(format: String) -> void:
	var slot: Dictionary = _slots[format]
	if not _initialized or not can_request_ads() or slot["loaded"] or slot["loading"]:
		return
	if _show != null and _show.format == format:
		return
	slot["loading"] = true
	slot["waited"] = 0.0
	slot["retry_in"] = -1.0
	_sdk.load_ad(format, str(_units.get(format, "")), func(ok: bool) -> void:
		if slot["loading"]:
			_load_finished(format, ok))


func _load_finished(format: String, ok: bool) -> void:
	var slot: Dictionary = _slots[format]
	slot["loading"] = false
	if ok:
		slot["loaded"] = true
		slot["failures"] = 0
		availability_changed.emit()
	else:
		slot["failures"] += 1
		slot["retry_in"] = retry_delay(slot["failures"])


## 떠 있던 광고의 결과가 정해졌으면 정리하고 결과를 한 번 돌려준다.
func _settle_show() -> void:
	if _show == null or not _show.is_done():
		return
	var result: String = _show.result
	var format: String = _show.format
	var on_result: Callable = _show_result
	_show = null
	_show_result = Callable()
	_sdk.discard_ad(format)
	presenting_changed.emit(false)
	availability_changed.emit()
	_load(format)
	on_result.call(result)
