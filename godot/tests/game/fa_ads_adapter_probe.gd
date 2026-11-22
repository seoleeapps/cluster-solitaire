extends SceneTree
## 광고 어댑터 검사: 떠 있는 광고의 결과 판정(알림 순서, 시간 제한, 한 번만), 다시 시도 간격,
## 동의 상태에 따른 초기화와 불러오기, 보여 주기와 다시 불러오기, 개인정보 선택, 주입 값과 테스트 단위.
## SDK는 메모리 안의 대역으로 바꿔 끼운다. 네트워크와 기기를 쓰지 않는다.

const AdsPort := preload("res://game/core/ports/fa_ads_port.gd")
const AdSdk := preload("res://game/adapters/fa_ad_sdk.gd")
const AdShow := preload("res://game/adapters/fa_ad_show.gd")
const Ads := preload("res://game/adapters/fa_admob_ads.gd")
const Values := preload("res://game/adapters/fa_service_values.gd")
const LiveServices := preload("res://game/adapters/fa_live_services.gd")

const UNITS := {"rewarded": "unit-rewarded", "interstitial": "unit-interstitial"}

var _checks: int = 0
var _failed: PackedStringArray = []
var _sdks: Array[FakeSdk] = []


## SDK 대역. 부른 순서를 적어 두고, 검사가 콜백을 원하는 때에 직접 부른다.
class FakeSdk extends AdSdk:
	var present: bool = true
	var status: int = CONSENT_UNKNOWN
	var form: bool = false
	var privacy: bool = false
	var calls: Array[String] = []
	var rating: String = ""
	var non_personalized: bool = false
	var units: Dictionary = {}
	var update_done: Callable
	var form_done: Callable
	var privacy_done: Callable
	var init_done: Callable
	var load_done: Dictionary = {}
	var show_event: Dictionary = {}
	var consent_debug: Array = []

	func available() -> bool:
		return present

	func set_consent_debug(geography: String, device_ids: PackedStringArray) -> void:
		consent_debug = [geography, device_ids]

	func update_consent(on_done: Callable) -> void:
		calls.append("update")
		update_done = on_done

	func consent_status() -> int:
		return status

	func consent_form_available() -> bool:
		return form

	func show_consent_form(on_done: Callable) -> void:
		calls.append("form")
		form_done = on_done

	func privacy_options_required() -> bool:
		return privacy

	func show_privacy_options(on_done: Callable) -> void:
		calls.append("privacy")
		privacy_done = on_done

	func initialize(on_done: Callable) -> void:
		calls.append("initialize")
		init_done = on_done

	func set_max_ad_content_rating(value: String) -> void:
		rating = value

	func set_non_personalized(enabled: bool) -> void:
		non_personalized = enabled

	func load_ad(format: String, unit_id: String, on_done: Callable) -> void:
		calls.append("load:" + format)
		units[format] = unit_id
		load_done[format] = on_done

	func show_ad(format: String, on_event: Callable) -> void:
		calls.append("show:" + format)
		show_event[format] = on_event

	func discard_ad(format: String) -> void:
		calls.append("discard:" + format)

	func count(call: String) -> int:
		return calls.count(call)

	## 어댑터가 넘긴 콜백을 놓는다. 콜백이 어댑터를 잡고 있어 놓지 않으면 끝날 때까지 서로를 붙든다.
	func release() -> void:
		update_done = Callable()
		form_done = Callable()
		privacy_done = Callable()
		init_done = Callable()
		load_done.clear()
		show_event.clear()


func _initialize() -> void:
	_section("결과 판정: 알림 순서", _show_orders)
	_section("결과 판정: 시간 제한", _show_timeouts)
	_section("다시 시도 간격", _retry_delays)
	_section("동의 뒤에만 초기화", _consent_gate)
	_section("동의 갱신 실패와 SDK 없음", _consent_failures)
	_section("불러오기와 다시 시도", _loading)
	_section("보여 주기", _showing)
	_section("개인정보 선택", _privacy)
	_section("주입 값과 테스트 단위", _service_values)
	_section("검수용 동의 설정", _consent_debug)
	for sdk: FakeSdk in _sdks:
		sdk.release()
	print("Fa ads adapter probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _sdk() -> FakeSdk:
	var sdk: FakeSdk = FakeSdk.new()
	_sdks.append(sdk)
	return sdk


## 알림을 순서대로 넣은 뒤의 결과. 아직 정해지지 않았으면 "".
func _result(format: String, events: Array) -> String:
	var shown: AdShow = AdShow.new(format)
	for kind: String in events:
		shown.event(kind)
	return shown.result


## 0.1초씩 seconds초를 흘린다.
func _run(target: Object, seconds: float) -> void:
	for _step: int in int(round(seconds * 10.0)):
		target.advance(0.1)


## 동의가 필요 없는 지역에서 광고 둘을 불러 둔 어댑터.
func _ready_ads(sdk: FakeSdk) -> Ads:
	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	var ads: Ads = Ads.new(sdk, UNITS)
	ads.start()
	sdk.update_done.call(true)
	sdk.init_done.call()
	sdk.load_done["rewarded"].call(true)
	sdk.load_done["interstitial"].call(true)
	return ads


func _show_orders() -> bool:
	_check(_result("rewarded", ["showed", "reward", "dismissed"]) == "earned", "보상 뒤 닫힘은 earned")
	_check(_result("rewarded", ["showed", "reward"]) == "", "닫히기 전에는 정하지 않는다")
	_check(_result("rewarded", ["showed", "dismissed"]) == "", "보상 없이 닫히면 늦은 보상 알림을 기다린다")
	_check(_result("rewarded", ["showed", "dismissed", "reward"]) == "earned", "닫힘 뒤에 온 보상도 earned")
	_check(_result("rewarded", ["reward", "showed", "dismissed"]) == "earned", "보상 알림이 맨 먼저 와도 earned")
	_check(_result("rewarded", ["dismissed", "reward"]) == "earned", "떴다는 알림 없이도 보상과 닫힘이면 earned")
	_check(_result("interstitial", ["showed", "dismissed"]) == "dismissed", "전면은 닫히면 dismissed")
	_check(_result("interstitial", ["showed", "reward", "dismissed"]) == "dismissed", "전면의 보상 알림은 무시한다")
	_check(_result("interstitial", ["dismissed"]) == "dismissed", "전면은 닫힘만 와도 dismissed")
	_check(_result("rewarded", ["failed"]) == "failed", "뜨지 못하면 failed")
	_check(_result("interstitial", ["failed"]) == "failed", "전면도 뜨지 못하면 failed")
	_check(_result("rewarded", ["showed", "reward", "failed"]) == "earned", "보상 알림을 받은 뒤의 실패는 보상을 지킨다")
	_check(_result("rewarded", ["showed", "unknown"]) == "", "모르는 알림은 무시한다")

	var shown: AdShow = AdShow.new("rewarded")
	shown.event("showed")
	shown.event("dismissed")
	_run(shown, AdShow.REWARD_GRACE_SECONDS - 0.2)
	_check(not shown.is_done(), "기다리는 시간 안에는 정하지 않는다")
	_run(shown, 0.4)
	_check(shown.result == "dismissed", "기다려도 보상이 없으면 dismissed")
	shown.event("reward")
	shown.event("failed")
	_check(shown.result == "dismissed", "정한 뒤에 온 알림은 결과를 바꾸지 않는다")

	shown = AdShow.new("rewarded")
	shown.event("showed")
	shown.event("reward")
	shown.event("dismissed")
	shown.event("dismissed")
	shown.event("failed")
	_run(shown, 200.0)
	_check(shown.result == "earned", "닫힘이 두 번 와도, 시간이 흘러도 earned 그대로다")
	return true


func _show_timeouts() -> bool:
	var shown: AdShow = AdShow.new("rewarded")
	_run(shown, AdShow.START_STALL_SECONDS - 0.5)
	_check(not shown.is_done(), "뜨기를 기다리는 시간 안에는 정하지 않는다")
	_run(shown, 1.0)
	_check(shown.result == "failed", "떴다는 알림이 끝내 없으면 failed")

	shown = AdShow.new("interstitial")
	shown.advance(3600.0)
	_check(not shown.is_done(), "광고에서 돌아온 첫 프레임의 긴 간격은 한 걸음으로만 센다")
	for _frame: int in 30:
		shown.advance(3600.0)
	_check(not shown.is_done(), "긴 간격이 서른 번 와도 7.5초다")
	for _frame: int in 15:
		shown.advance(3600.0)
	_check(shown.result == "failed", "한 걸음씩 세어 제한에 닿으면 failed")

	shown = AdShow.new("interstitial")
	shown.event("showed")
	_run(shown, AdShow.START_STALL_SECONDS + 5.0)
	_check(not shown.is_done(), "뜬 광고는 짧은 제한으로 끝내지 않는다")
	_run(shown, AdShow.OPEN_STALL_SECONDS)
	_check(shown.result == "dismissed", "뜬 전면에서 닫힘 알림이 끝내 없으면 dismissed")

	shown = AdShow.new("rewarded")
	shown.event("showed")
	_run(shown, AdShow.OPEN_STALL_SECONDS + 1.0)
	_check(shown.result == "dismissed", "뜬 보상형에서 아무 알림이 없으면 dismissed")

	shown = AdShow.new("rewarded")
	shown.event("showed")
	_run(shown, 60.0)
	shown.event("reward")
	_run(shown, AdShow.OPEN_STALL_SECONDS - 1.0)
	_check(not shown.is_done(), "알림이 오면 제한을 다시 센다")
	_run(shown, 2.0)
	_check(shown.result == "earned", "보상 알림을 받고 닫힘 알림이 없으면 earned")

	shown = AdShow.new("rewarded")
	shown.advance(0.0)
	shown.advance(-5.0)
	_run(shown, 9.0)
	_check(not shown.is_done(), "0과 음수 시간은 세지 않는다")
	return true


func _retry_delays() -> bool:
	_check(Ads.retry_delay(1) == 10.0 and Ads.retry_delay(2) == 30.0 and Ads.retry_delay(3) == 60.0, "10초, 30초, 60초로 늘어난다")
	_check(Ads.retry_delay(4) == 120.0 and Ads.retry_delay(5) == 300.0, "120초, 300초")
	_check(Ads.retry_delay(6) == 300.0 and Ads.retry_delay(1000) == 300.0, "300초에서 더 늘지 않는다")
	_check(Ads.retry_delay(0) == 10.0 and Ads.retry_delay(-3) == 10.0, "0 이하는 첫 간격이다")
	for failures: int in range(2, 8):
		_check(Ads.retry_delay(failures) >= Ads.retry_delay(failures - 1), "간격은 줄지 않는다: %d" % failures)
	return true


func _consent_gate() -> bool:
	var sdk: FakeSdk = _sdk()
	var ads: Ads = Ads.new(sdk, UNITS)
	_check(not ads.can_request_ads() and not ads.is_ready("rewarded") and sdk.calls.is_empty(), "start 전에는 아무것도 부르지 않는다")
	_check(ads.consent_pending() and not ads.analytics_allowed(), "start 전의 동의 상태는 모름이다")
	ads.start()
	ads.start()
	_check(sdk.calls == ["update"], "첫 실행은 동의 갱신만 요청하고 초기화하지 않는다")
	_check(not ads.can_request_ads() and ads.consent_pending() and not ads.analytics_allowed(), "갱신이 끝나기 전에는 요청할 수 없다")

	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	sdk.update_done.call(true)
	_check(sdk.calls == ["update", "initialize"], "동의가 필요 없으면 초기화한다")
	_check(ads.can_request_ads() and ads.analytics_allowed() and not ads.consent_pending(), "규제 지역이 아니면 분석을 보낼 수 있다")
	_check(sdk.count("load:rewarded") == 0, "초기화가 끝나기 전에는 불러오지 않는다")
	sdk.init_done.call()
	_check(sdk.rating == "PG", "광고 최대 콘텐츠 등급은 PG다")
	_check(sdk.calls == ["update", "initialize", "load:rewarded", "load:interstitial"], "초기화 뒤 보상형과 전면을 하나씩 불러온다")
	_check(sdk.units == UNITS, "넘겨받은 광고 단위로 불러온다")
	_check(not ads.is_ready("rewarded"), "불러오는 중에는 준비되지 않았다")
	sdk.load_done["rewarded"].call(true)
	_check(ads.is_ready("rewarded") and not ads.is_ready("interstitial") and not ads.is_ready("banner"), "불러온 형식만 준비됐다")

	sdk = _sdk()
	sdk.status = AdSdk.CONSENT_OBTAINED
	ads = Ads.new(sdk, UNITS)
	ads.start()
	_check(sdk.calls == ["update", "initialize"], "지난 실행에서 받은 동의가 있으면 갱신을 기다리지 않고 초기화한다")
	_check(not ads.analytics_allowed() and ads.consent_pending(), "이번 실행의 갱신이 끝나기 전에는 분석을 보내지 않는다")
	sdk.init_done.call()
	sdk.update_done.call(true)
	_check(sdk.count("initialize") == 1 and sdk.count("load:rewarded") == 1, "갱신이 끝나도 초기화와 불러오기를 되풀이하지 않는다")
	_check(ads.can_request_ads() and not ads.analytics_allowed() and not ads.consent_pending(), "동의를 받은 규제 지역: 광고는 되고 분석은 안 된다")

	sdk = _sdk()
	ads = Ads.new(sdk, UNITS)
	ads.start()
	sdk.status = AdSdk.CONSENT_REQUIRED
	sdk.form = true
	sdk.update_done.call(true)
	_check(sdk.calls == ["update", "form"], "동의가 필요하면 양식을 보여 주고 초기화하지 않는다")
	_check(not ads.can_request_ads() and ads.consent_pending(), "양식이 떠 있는 동안은 요청할 수 없다")
	sdk.status = AdSdk.CONSENT_OBTAINED
	sdk.form_done.call()
	_check(sdk.calls == ["update", "form", "initialize"] and ads.can_request_ads(), "양식에서 동의하면 초기화한다")
	_check(not ads.analytics_allowed() and not ads.consent_pending(), "양식을 거친 지역은 분석을 보내지 않는다")

	sdk = _sdk()
	ads = Ads.new(sdk, UNITS)
	var changes: Array[int] = [0]
	ads.consent_changed.connect(func() -> void: changes[0] += 1)
	ads.start()
	sdk.status = AdSdk.CONSENT_REQUIRED
	sdk.update_done.call(true)
	_check(sdk.calls == ["update"] and not ads.can_request_ads(), "동의가 필요한데 양식이 없으면 광고를 준비하지 않는다")
	_check(not ads.analytics_allowed() and not ads.consent_pending() and changes[0] >= 1, "규제 지역으로 확정되고 바뀐 것을 알린다")
	var failures: Array[String] = []
	ads.show("rewarded", func(result: String) -> void: failures.append(result))
	_check(failures == ["failed"] and sdk.count("show:rewarded") == 0, "동의가 없으면 보여 주지 않고 failed를 한 번 돌려준다")
	return true


func _consent_failures() -> bool:
	var sdk: FakeSdk = _sdk()
	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	var ads: Ads = Ads.new(sdk, UNITS)
	ads.start()
	sdk.init_done.call()
	_check(ads.can_request_ads() and not ads.analytics_allowed() and ads.consent_pending(), "지난 실행이 규제 지역이 아니었어도 이번 갱신이 끝나기 전에는 분석을 보내지 않는다")
	sdk.update_done.call(false)
	_check(ads.can_request_ads() and ads.analytics_allowed(), "갱신에 실패해도 지난 실행의 상태를 쓴다")
	_run(ads, 400.0)
	_check(sdk.count("update") == 1, "상태를 아는 실패는 다시 갱신하지 않는다")

	sdk = _sdk()
	ads = Ads.new(sdk, UNITS)
	ads.start()
	sdk.update_done.call(false)
	_check(not ads.can_request_ads() and not ads.analytics_allowed() and ads.consent_pending(), "상태를 모르는 실패는 계속 모름이다")
	_check(sdk.calls == ["update"], "모르는 동안 초기화하지 않는다")
	_run(ads, 9.0)
	_check(sdk.count("update") == 1, "다시 시도할 때가 되기 전에는 갱신하지 않는다")
	_run(ads, 1.5)
	_check(sdk.count("update") == 2, "10초 뒤 다시 갱신한다")
	sdk.update_done.call(false)
	_run(ads, 29.0)
	_check(sdk.count("update") == 2, "두 번째 실패 뒤에는 30초를 기다린다")
	ads.resume()
	_check(sdk.count("update") == 3, "화면으로 돌아오면 기다리지 않고 다시 갱신한다")
	_run(ads, 100.0)
	_check(sdk.count("update") == 3, "갱신 답을 기다리는 동안에는 또 요청하지 않는다")
	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	sdk.update_done.call(true)
	_check(ads.can_request_ads() and ads.analytics_allowed() and sdk.count("initialize") == 1, "갱신에 성공하면 준비를 시작한다")

	sdk = _sdk()
	sdk.present = false
	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	sdk.privacy = true
	ads = Ads.new(sdk, UNITS)
	ads.start()
	_run(ads, 100.0)
	ads.resume()
	ads.request("rewarded")
	ads.open_privacy_choice()
	_check(sdk.calls.is_empty(), "SDK가 없으면 아무것도 부르지 않는다")
	_check(not ads.is_ready("rewarded") and not ads.is_ready("interstitial"), "SDK가 없으면 준비된 광고가 없다")
	_check(not ads.privacy_choice_required() and not ads.analytics_allowed() and not ads.consent_pending(), "SDK가 없으면 개인정보 선택도 분석 허용도 없다")
	var results: Array[String] = []
	ads.show("interstitial", func(result: String) -> void: results.append(result))
	_check(results == ["failed"], "SDK가 없으면 보여 주기는 failed를 한 번 돌려준다")
	return true


func _loading() -> bool:
	var sdk: FakeSdk = _sdk()
	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	var ads: Ads = Ads.new(sdk, UNITS)
	var availability: Array[int] = [0]
	ads.availability_changed.connect(func() -> void: availability[0] += 1)
	ads.start()
	sdk.update_done.call(true)
	sdk.init_done.call()
	sdk.load_done["interstitial"].call(true)
	var before: int = availability[0]
	sdk.load_done["rewarded"].call(false)
	_check(not ads.is_ready("rewarded") and ads.is_ready("interstitial"), "실패한 형식만 준비되지 않았다")
	ads.request("rewarded")
	_check(sdk.count("load:rewarded") == 1, "다시 시도를 기다리는 동안 request는 간격을 건너뛰지 않는다")
	_run(ads, 9.5)
	_check(sdk.count("load:rewarded") == 1, "10초 전에는 다시 불러오지 않는다")
	_run(ads, 1.0)
	_check(sdk.count("load:rewarded") == 2, "10초 뒤 다시 불러온다")
	sdk.load_done["rewarded"].call(false)
	_run(ads, 29.0)
	_check(sdk.count("load:rewarded") == 2, "두 번째 실패 뒤에는 30초를 기다린다")
	_run(ads, 1.5)
	_check(sdk.count("load:rewarded") == 3, "30초 뒤 다시 불러온다")
	for expected: float in [60.0, 120.0, 300.0, 300.0]:
		sdk.load_done["rewarded"].call(false)
		_run(ads, expected - 1.0)
		var attempts: int = sdk.count("load:rewarded")
		_run(ads, 2.0)
		_check(sdk.count("load:rewarded") == attempts + 1, "%d초 뒤 다시 불러온다" % int(expected))
	sdk.load_done["rewarded"].call(true)
	_check(ads.is_ready("rewarded") and availability[0] > before, "불러오면 준비되고 바뀐 것을 알린다")
	_run(ads, 1000.0)
	_check(sdk.count("load:rewarded") == 7 and sdk.count("load:interstitial") == 1, "불러 둔 광고가 있으면 더 불러오지 않는다")
	ads.request("rewarded")
	ads.request("banner")
	_check(sdk.count("load:rewarded") == 7, "준비된 형식과 모르는 형식의 request는 아무 일도 하지 않는다")

	sdk = _sdk()
	sdk.status = AdSdk.CONSENT_NOT_REQUIRED
	ads = Ads.new(sdk, UNITS)
	ads.start()
	sdk.update_done.call(true)
	sdk.init_done.call()
	var stale: Callable = sdk.load_done["rewarded"]
	_run(ads, Ads.LOAD_TIMEOUT_SECONDS - 1.0)
	_check(sdk.count("discard:rewarded") == 0, "답을 기다리는 시간 안에는 버리지 않는다")
	_run(ads, 2.0)
	_check(sdk.count("discard:rewarded") == 1 and not ads.is_ready("rewarded"), "답이 없으면 버리고 실패로 본다")
	stale.call(true)
	_check(not ads.is_ready("rewarded"), "버린 뒤에 온 답은 받지 않는다")
	_run(ads, 10.5)
	_check(sdk.count("load:rewarded") == 2, "답이 없던 불러오기도 간격을 두고 다시 시도한다")
	ads.advance(100000.0)
	_check(sdk.count("discard:rewarded") == 1, "돌아온 첫 프레임의 긴 간격으로 제한 시간이 한꺼번에 지나가지 않는다")
	sdk.load_done["rewarded"].call(true)
	_check(ads.is_ready("rewarded"), "다시 불러온 광고는 준비된다")
	return true


func _showing() -> bool:
	var sdk: FakeSdk = _sdk()
	var ads: Ads = _ready_ads(sdk)
	var log: Array[String] = []
	ads.presenting_changed.connect(func(active: bool) -> void: log.append("presenting:" + str(active)))
	var on_result: Callable = func(result: String) -> void: log.append("result:" + result)

	ads.show("banner", on_result)
	_check(log == ["result:failed"], "모르는 형식은 failed를 한 번 돌려주고 소리 신호를 내지 않는다")
	log.clear()

	ads.show("rewarded", on_result)
	_check(log == ["presenting:true"] and sdk.count("show:rewarded") == 1, "보여 주기 전에 소리 신호를 낸다")
	_check(not ads.is_ready("rewarded") and not ads.is_ready("interstitial"), "광고가 떠 있는 동안에는 어느 형식도 준비되지 않았다")
	ads.show("interstitial", on_result)
	_check(log == ["presenting:true", "result:failed"] and sdk.count("show:interstitial") == 0, "떠 있는 중의 보여 주기는 failed다")
	log.clear()
	var events: Callable = sdk.show_event["rewarded"]
	events.call("showed")
	events.call("reward")
	_check(log.is_empty(), "닫히기 전에는 결과를 돌려주지 않는다")
	events.call("dismissed")
	_check(log == ["presenting:false", "result:earned"], "닫히면 소리 신호를 되돌린 뒤 earned를 돌려준다")
	_check(sdk.calls.slice(-2) == ["discard:rewarded", "load:rewarded"], "보여 준 광고는 버리고 다음 것을 불러온다")
	events.call("dismissed")
	events.call("reward")
	events.call("failed")
	_run(ads, 200.0)
	_check(log == ["presenting:false", "result:earned"], "끝난 광고의 늦은 알림과 시간은 결과를 다시 부르지 않는다")
	_check(not ads.is_ready("rewarded") and ads.is_ready("interstitial"), "다음 보상형을 불러오는 동안 전면은 준비돼 있다")
	sdk.load_done["rewarded"].call(true)
	_check(ads.is_ready("rewarded"), "다음 보상형이 준비됐다")
	log.clear()

	ads.show("rewarded", on_result)
	events = sdk.show_event["rewarded"]
	events.call("showed")
	events.call("dismissed")
	_check(log == ["presenting:true"], "보상 없이 닫힌 보상형은 늦은 보상을 잠깐 기다린다")
	_run(ads, AdShow.REWARD_GRACE_SECONDS + 0.2)
	_check(log == ["presenting:true", "presenting:false", "result:dismissed"], "보상이 오지 않으면 dismissed를 한 번 돌려준다")
	sdk.load_done["rewarded"].call(true)
	log.clear()

	ads.show("rewarded", on_result)
	events = sdk.show_event["rewarded"]
	events.call("showed")
	events.call("dismissed")
	events.call("reward")
	_check(log == ["presenting:true", "presenting:false", "result:earned"], "닫힘 뒤에 온 보상도 earned로 돌려준다")
	sdk.load_done["rewarded"].call(true)
	log.clear()

	ads.show("interstitial", on_result)
	events = sdk.show_event["interstitial"]
	events.call("showed")
	events.call("dismissed")
	_check(log == ["presenting:true", "presenting:false", "result:dismissed"], "전면은 닫히면 dismissed다")
	_check(sdk.calls.slice(-2) == ["discard:interstitial", "load:interstitial"], "전면도 버리고 다시 불러온다")
	sdk.load_done["interstitial"].call(true)
	log.clear()

	ads.show("interstitial", on_result)
	sdk.show_event["interstitial"].call("failed")
	_check(log == ["presenting:true", "presenting:false", "result:failed"], "뜨지 못하면 failed다")
	sdk.load_done["interstitial"].call(true)
	log.clear()

	ads.show("rewarded", on_result)
	_run(ads, AdShow.START_STALL_SECONDS + 0.5)
	_check(log == ["presenting:true", "presenting:false", "result:failed"], "알림이 전혀 오지 않으면 시간 제한 뒤 failed다")
	_check(sdk.calls.slice(-2) == ["discard:rewarded", "load:rewarded"], "시간 제한으로 끝낸 광고도 버리고 다시 불러온다")
	sdk.show_event["rewarded"].call("reward")
	sdk.show_event["rewarded"].call("dismissed")
	_check(log.size() == 3, "시간 제한 뒤에 온 알림은 결과를 다시 부르지 않는다")
	sdk.load_done["rewarded"].call(true)
	log.clear()

	# 결과를 받은 자리에서 곧바로 다른 광고를 보여 줄 수 있다.
	var chained: Array[String] = []
	ads.show("interstitial", func(result: String) -> void:
		chained.append(result)
		ads.show("rewarded", func(second: String) -> void: chained.append(second)))
	sdk.show_event["interstitial"].call("dismissed")
	_check(chained == ["dismissed"] and sdk.count("show:rewarded") == 5, "결과 콜백 안에서 다음 광고를 보여 줄 수 있다")
	sdk.show_event["rewarded"].call("reward")
	sdk.show_event["rewarded"].call("dismissed")
	_check(chained == ["dismissed", "earned"], "이어서 보여 준 광고의 결과도 한 번 온다")
	return true


func _privacy() -> bool:
	var sdk: FakeSdk = _sdk()
	var ads: Ads = _ready_ads(sdk)
	_check(not ads.privacy_choice_required(), "요건이 없으면 진입점을 보이지 않는다")
	ads.open_privacy_choice()
	_check(sdk.count("privacy") == 0, "요건이 없으면 양식을 열지 않는다")

	sdk = _sdk()
	sdk.status = AdSdk.CONSENT_OBTAINED
	sdk.privacy = true
	var ads_eu: Ads = Ads.new(sdk, UNITS)
	_check(not ads_eu.privacy_choice_required(), "start 전에는 요건을 묻지 않는다")
	ads_eu.start()
	sdk.init_done.call()
	sdk.update_done.call(true)
	sdk.load_done["rewarded"].call(true)
	sdk.load_done["interstitial"].call(true)
	_check(ads_eu.privacy_choice_required(), "요건이 있으면 진입점을 보인다")
	var changes: Array[int] = [0]
	ads_eu.consent_changed.connect(func() -> void: changes[0] += 1)
	ads_eu.open_privacy_choice()
	_check(sdk.count("privacy") == 1 and changes[0] == 0, "개인정보 선택 양식을 연다")
	sdk.privacy_done.call()
	_check(changes[0] == 1 and ads_eu.is_ready("rewarded"), "양식을 닫으면 동의 상태를 다시 읽고, 동의가 그대로면 광고도 그대로다")

	ads_eu.open_privacy_choice()
	sdk.status = AdSdk.CONSENT_REQUIRED
	sdk.privacy_done.call()
	_check(not ads_eu.can_request_ads() and not ads_eu.is_ready("rewarded") and not ads_eu.is_ready("interstitial"), "요청할 수 없게 되면 준비된 광고가 없다")
	_check(sdk.count("discard:rewarded") == 1 and sdk.count("discard:interstitial") == 1, "불러 둔 광고를 버린다")
	sdk.status = AdSdk.CONSENT_OBTAINED
	ads_eu.open_privacy_choice()
	sdk.privacy_done.call()
	_check(sdk.count("load:rewarded") == 2 and sdk.count("initialize") == 1, "다시 요청할 수 있게 되면 초기화 없이 불러온다")

	sdk.load_done["rewarded"].call(true)
	ads_eu.show("rewarded", func(_result: String) -> void: pass)
	ads_eu.open_privacy_choice()
	_check(sdk.count("privacy") == 3, "광고가 떠 있는 동안에는 양식을 열지 않는다")
	return true


func _service_values() -> bool:
	var empty: Values = Values.from_text("", false)
	_check(empty.ad_unit("rewarded") == "ca-app-pub-3940256099942544/5224354917", "값이 없으면 보상형은 Google 테스트 단위다")
	_check(empty.ad_unit("interstitial") == "ca-app-pub-3940256099942544/1033173712", "값이 없으면 전면은 Google 테스트 단위다")
	_check(empty.uses_test_ads() and not empty.analytics_configured() and empty.config_url() == "", "값이 없으면 분석과 원격 설정은 꺼진다")
	_check(empty.ad_unit("banner") == "", "모르는 형식의 단위는 없다")

	var document: Dictionary = {
		"admob_app_id": "ca-app-pub-1234567890123456~1234567890",
		"admob_rewarded_unit": "ca-app-pub-1234567890123456/1111111111",
		"admob_interstitial_unit": "ca-app-pub-1234567890123456/2222222222",
		"ga4_measurement_id": "G-ABCDE12345",
		"ga4_api_secret": "probe_secret_value-01",
		"remote_config_url": "https://example.github.io/game/config.json",
	}
	var release: Values = Values.from_text(JSON.stringify(document), false)
	_check(release.ad_unit("rewarded") == document["admob_rewarded_unit"] and release.ad_unit("interstitial") == document["admob_interstitial_unit"], "릴리스 빌드는 주입한 단위를 쓴다")
	_check(not release.uses_test_ads() and release.analytics_configured(), "릴리스 빌드는 테스트 단위가 아니고 분석이 켜진다")
	_check(release.measurement_id() == "G-ABCDE12345" and release.api_secret() == "probe_secret_value-01", "측정 값을 읽는다")
	_check(release.config_url() == document["remote_config_url"], "원격 설정 주소를 읽는다")
	_check(release.ad_units() == {"rewarded": document["admob_rewarded_unit"], "interstitial": document["admob_interstitial_unit"]}, "단위 묶음")

	var debug: Values = Values.from_text(JSON.stringify(document), true)
	_check(debug.uses_test_ads() and debug.ad_unit("rewarded") == Values.TEST_UNITS["rewarded"] and debug.ad_unit("interstitial") == Values.TEST_UNITS["interstitial"], "디버그 빌드는 주입 값이 있어도 테스트 단위를 쓴다")

	var half: Dictionary = document.duplicate()
	half.erase("admob_interstitial_unit")
	_check(Values.from_text(JSON.stringify(half), false).uses_test_ads(), "단위가 하나만 있으면 둘 다 테스트 단위다")
	var bad_unit: Dictionary = document.duplicate()
	bad_unit["admob_rewarded_unit"] = "ca-app-pub-123/456"
	_check(Values.from_text(JSON.stringify(bad_unit), false).ad_unit("interstitial") == Values.TEST_UNITS["interstitial"], "형식이 틀린 단위는 받지 않는다")
	var no_secret: Dictionary = document.duplicate()
	no_secret["ga4_api_secret"] = ""
	_check(not Values.from_text(JSON.stringify(no_secret), false).analytics_configured(), "비밀값이 없으면 분석은 꺼진다")
	var bad_id: Dictionary = document.duplicate()
	bad_id["ga4_measurement_id"] = "UA-123"
	_check(not Values.from_text(JSON.stringify(bad_id), false).analytics_configured(), "측정 ID의 형식이 틀리면 분석은 꺼진다")
	var plain_url: Dictionary = document.duplicate()
	plain_url["remote_config_url"] = "http://example.com/config.json"
	_check(Values.from_text(JSON.stringify(plain_url), false).config_url() == "", "https가 아닌 주소는 받지 않는다")
	for text: String in ["[1, 2]", "not json", "null", "{\"admob_rewarded_unit\": 5}"]:
		var broken: Values = Values.from_text(text, false)
		_check(broken.uses_test_ads() and not broken.analytics_configured() and broken.config_url() == "", "읽을 수 없는 값은 없는 것으로 본다: " + text)

	var packed: Values = Values.load_packed()
	_check(packed.uses_test_ads() and not packed.analytics_configured() and packed.config_url() == "", "에디터와 headless 실행은 주입 파일을 읽지 않는다")
	return true


func _consent_debug() -> bool:
	var arguments: PackedStringArray = ["--fa-consent-geography=eea", "--fa-consent-device=AAAA", "--other", "--fa-consent-device=BBBB", "--fa-consent-device="]
	_check(LiveServices.consent_debug_from(arguments, true) == {"geography": "eea", "devices": PackedStringArray(["AAAA", "BBBB"])}, "디버그 빌드는 실행 인자의 지역과 기기 해시를 읽는다")
	_check(LiveServices.consent_debug_from(arguments, false).is_empty(), "릴리스 빌드는 인자가 있어도 듣지 않는다")
	_check(LiveServices.consent_debug_from(["--fa-consent-geography=not_eea"], true) == {"geography": "not_eea", "devices": PackedStringArray()}, "규제 지역이 아닌 것으로도 정할 수 있다")
	for unusable: PackedStringArray in [PackedStringArray(), PackedStringArray(["--fa-consent-device=AAAA"]), PackedStringArray(["--fa-consent-geography=mars"]), PackedStringArray(["--fa-consent-geography="])]:
		_check(LiveServices.consent_debug_from(unusable, true).is_empty(), "지역 인자가 없거나 모르는 값이면 듣지 않는다: " + str(unusable))

	var sdk: FakeSdk = _sdk()
	var ads: Ads = Ads.new(sdk, UNITS)
	_check(sdk.consent_debug.is_empty(), "정하지 않으면 SDK에 검수 설정을 넘기지 않는다")
	ads.set_consent_debug("eea", ["AAAA"])
	_check(sdk.consent_debug == ["eea", PackedStringArray(["AAAA"])], "정한 검수 설정을 SDK에 넘긴다")

	# iOS No-UMP 모드: UMP를 부르지 않고 비개인화(npa=1)로 바로 준비한다.
	var ios_sdk: FakeSdk = _sdk()
	ios_sdk.privacy = true
	var ios_ads: Ads = Ads.new(ios_sdk, UNITS, true)
	ios_ads.start()
	_check(ios_sdk.count("update") == 0 and ios_sdk.count("form") == 0, "iOS No-UMP 모드는 UMP를 호출하지 않는다")
	_check(ios_ads.consent_settled() and not ios_ads.consent_pending(), "iOS No-UMP 모드는 즉시 동의 완료 상태다")
	_check(ios_ads.can_request_ads() and ios_ads.analytics_allowed(), "광고와 1차 사용 통계를 허용한다")
	_check(not ios_ads.privacy_choice_required() and ios_sdk.non_personalized, "개인정보 선택 메뉴는 숨기고 비개인화(npa=1)로 요청한다")
	_check(ios_sdk.count("initialize") == 1, "동의 대기 없이 SDK를 초기화한다")
	ios_ads.open_privacy_choice()
	_check(ios_sdk.count("privacy") == 0, "iOS No-UMP 모드는 UMP 개인정보 선택 창을 열지 않는다")
	_check(Values.test_units_for("iOS") == Values.IOS_TEST_UNITS, "iOS 디버그·미주입 단위는 Apple 테스트 단위다")
	return true
