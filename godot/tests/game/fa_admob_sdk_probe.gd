extends SceneTree
## AdMob 플러그인 연결 검사. FaLiveServices, FaAdmobAds, FaAdmobSdk와 플러그인의 GDScript 층을 실제 그대로 쓰고,
## Android에서만 있는 네이티브 싱글턴 다섯 개만 같은 메서드와 신호를 가진 대역으로 바꿔 끼운다.
## 동의 갱신 실패와 재시도, 동의 양식, 초기화, 요청 설정, 불러오기, 보상형과 전면의 표시와 결과,
## 개인정보 선택까지 한 번의 실행으로 따라간다. 네이티브 층과 실제 SDK의 동작은 기기 확인(AND-05~07)의 몫이다.
##
## 플러그인의 클래스 이름은 가져오기 캐시가 있어야 풀린다. `godot --headless --path godot --import`가 한 번 돈 뒤에 실행한다.
## tools/check.py는 가져오기를 먼저 하므로 npm test에서는 항상 돈다.

const LiveServices := preload("res://game/adapters/fa_live_services.gd")
const Values := preload("res://game/adapters/fa_service_values.gd")

const ADMOB_SDK_PATH := "res://game/adapters/fa_admob_sdk.gd"

var _checks: int = 0
var _failed: PackedStringArray = []
var _natives: Dictionary = {}


## PoingGodotAdMob의 대역.
class NativeAds extends Object:
	signal on_initialization_complete(status: Dictionary)
	signal on_ad_inspector_closed(error: Dictionary)
	var initialized: int = 0
	var configuration: Dictionary = {}
	var test_devices: Array = []

	func initialize() -> void:
		initialized += 1

	func set_request_configuration(config: Dictionary, device_ids: Array) -> void:
		configuration = config
		test_devices = device_ids


## PoingGodotAdMobRewardedAd의 대역.
class NativeRewarded extends Object:
	signal on_rewarded_ad_loaded(uid: int)
	signal on_rewarded_ad_failed_to_load(uid: int, error: Dictionary)
	signal on_rewarded_ad_clicked(uid: int)
	signal on_rewarded_ad_dismissed_full_screen_content(uid: int)
	signal on_rewarded_ad_failed_to_show_full_screen_content(uid: int, error: Dictionary)
	signal on_rewarded_ad_impression(uid: int)
	signal on_rewarded_ad_showed_full_screen_content(uid: int)
	signal on_rewarded_ad_paid(uid: int, value: Dictionary)
	signal on_rewarded_ad_user_earned_reward(uid: int, reward: Dictionary)
	var uids: int = 0
	var loads: Array[Dictionary] = []
	var shown: Array[int] = []
	var destroyed: Array[int] = []

	func create() -> int:
		uids += 1
		return uids

	func load(unit_id: String, request: Dictionary, keywords: Array, uid: int) -> void:
		loads.append({"unit": unit_id, "request": request, "keywords": keywords, "uid": uid})

	func show(uid: int) -> void:
		shown.append(uid)

	func destroy(uid: int) -> void:
		destroyed.append(uid)


## PoingGodotAdMobInterstitialAd의 대역.
class NativeInterstitial extends Object:
	signal on_interstitial_ad_loaded(uid: int)
	signal on_interstitial_ad_failed_to_load(uid: int, error: Dictionary)
	signal on_interstitial_ad_clicked(uid: int)
	signal on_interstitial_ad_dismissed_full_screen_content(uid: int)
	signal on_interstitial_ad_failed_to_show_full_screen_content(uid: int, error: Dictionary)
	signal on_interstitial_ad_impression(uid: int)
	signal on_interstitial_ad_showed_full_screen_content(uid: int)
	signal on_interstitial_ad_paid(uid: int, value: Dictionary)
	var uids: int = 100
	var loads: Array[Dictionary] = []
	var shown: Array[int] = []
	var destroyed: Array[int] = []

	func create() -> int:
		uids += 1
		return uids

	func load(unit_id: String, request: Dictionary, keywords: Array, uid: int) -> void:
		loads.append({"unit": unit_id, "request": request, "keywords": keywords, "uid": uid})

	func show(uid: int) -> void:
		shown.append(uid)

	func destroy(uid: int) -> void:
		destroyed.append(uid)


## PoingGodotAdMobConsentInformation의 대역.
class NativeConsent extends Object:
	signal on_consent_info_updated_success
	signal on_consent_info_updated_failure(error: Dictionary)
	var status: int = 0
	var form_available: bool = false
	var privacy_status: int = 0
	var updates: Array[Dictionary] = []

	func get_consent_status() -> int:
		return status

	func get_is_consent_form_available() -> bool:
		return form_available

	func get_privacy_options_requirement_status() -> int:
		return privacy_status

	func update(parameters: Dictionary) -> void:
		updates.append(parameters)

	func reset() -> void:
		status = 0


## PoingGodotAdMobUserMessagingPlatform의 대역.
class NativeMessaging extends Object:
	signal on_consent_form_load_success_listener(uid: int)
	signal on_consent_form_load_failure_listener(error: Dictionary)
	signal on_consent_form_dismissed(uid: int, error: Dictionary)
	signal on_privacy_options_form_dismissed_listener(error: Dictionary)
	var form_loads: int = 0
	var forms_shown: Array[int] = []
	var privacy_forms: int = 0

	func load_consent_form() -> void:
		form_loads += 1

	func show(uid: int) -> void:
		forms_shown.append(uid)

	func show_privacy_options_form() -> void:
		privacy_forms += 1


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


## 플러그인의 지연 호출이 모두 돌 만큼 프레임을 넘긴다.
func _frames() -> void:
	for _frame: int in 4:
		await process_frame


func _has_plugin_classes() -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class") == "MobileAds":
			return true
	return false


func _run() -> void:
	if not _has_plugin_classes():
		print("Fa admob sdk probe: 가져오기 캐시가 없어 실행하지 못했다. `godot --headless --path godot --import`를 먼저 실행한다.")
		quit(1)
		return
	var without: LiveServices = LiveServices.new("user://fa-admob-sdk-probe-unused")
	_check(not without.ads.consent_pending() and not without.ads.analytics_allowed() and not without.ads.is_ready("rewarded"), "네이티브 싱글턴이 없으면 광고와 동의가 꺼진 것으로 동작한다")
	without.free()

	_natives = {
		"PoingGodotAdMob": NativeAds.new(),
		"PoingGodotAdMobRewardedAd": NativeRewarded.new(),
		"PoingGodotAdMobInterstitialAd": NativeInterstitial.new(),
		"PoingGodotAdMobConsentInformation": NativeConsent.new(),
		"PoingGodotAdMobUserMessagingPlatform": NativeMessaging.new(),
	}
	for singleton: String in _natives:
		Engine.register_singleton(singleton, _natives[singleton])
	await _journey()
	await _frames()
	_release_plugin_callbacks()
	for singleton: String in _natives:
		Engine.unregister_singleton(singleton)
		_natives[singleton].free()
	_natives.clear()
	print("Fa admob sdk probe: %d checks, %d failed" % [_checks, _failed.size()])
	for line: String in _failed:
		print("  FAILED ", line)
	quit(0 if _failed.is_empty() else 1)


func _journey() -> void:
	var ads_native: NativeAds = _natives["PoingGodotAdMob"]
	var rewarded: NativeRewarded = _natives["PoingGodotAdMobRewardedAd"]
	var interstitial: NativeInterstitial = _natives["PoingGodotAdMobInterstitialAd"]
	var consent: NativeConsent = _natives["PoingGodotAdMobConsentInformation"]
	var messaging: NativeMessaging = _natives["PoingGodotAdMobUserMessagingPlatform"]

	var sdk_script: GDScript = load(ADMOB_SDK_PATH)
	_check(sdk_script != null and sdk_script.new().available(), "싱글턴 다섯 개가 있으면 플러그인 구현을 쓸 수 있다")

	var live: LiveServices = LiveServices.new("user://fa-admob-sdk-probe-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	_check(live.ads.consent_pending() and not live.ads.can_request_ads(), "시작 전의 동의 상태는 모름이다")
	var log: Array[String] = []
	live.ads.presenting_changed.connect(func(active: bool) -> void: log.append("presenting:" + str(active)))
	var consent_changes: Array[int] = [0]
	live.ads.consent_changed.connect(func() -> void: consent_changes[0] += 1)
	var on_result: Callable = func(result: String) -> void: log.append("result:" + result)
	root.add_child(live)
	await _frames()

	# 동의 갱신: 첫 시도는 실패, 화면으로 돌아와 다시 시도해 성공.
	_check(consent.updates.size() == 1 and consent.updates[0].get("tag_for_under_age_of_consent") == false, "트리에 들어가면 동의 갱신을 요청한다(미성년 동의 태그 없음)")
	_check(consent.updates[0].has("consent_debug_settings") and consent.updates[0]["consent_debug_settings"] == null, "검수용 동의 설정은 넣지 않는다")
	_check(ads_native.initialized == 0, "동의를 모르는 동안 광고 SDK를 초기화하지 않는다")
	_check(not live.ads.consent_settled(), "갱신 답이 오기 전에는 동의 확인이 끝나지 않았다(타이틀이 기다린다)")
	consent.on_consent_info_updated_failure.emit({"error_code": 2, "message": "offline"})
	await _frames()
	_check(live.ads.consent_pending() and ads_native.initialized == 0, "갱신에 실패했고 상태를 모르면 계속 기다린다")
	_check(live.ads.consent_settled(), "갱신이 실패해도 확인은 끝난 것으로 본다(타이틀은 더 기다리지 않는다)")
	live.ads.resume()
	_check(consent.updates.size() == 2, "다시 갱신을 요청한다")
	consent.status = 2
	consent.form_available = true
	consent.on_consent_info_updated_success.emit()
	await _frames()
	_check(messaging.form_loads == 1 and ads_native.initialized == 0, "동의가 필요하면 양식을 불러오고 초기화는 미룬다")
	messaging.on_consent_form_load_success_listener.emit(31)
	await _frames()
	_check(messaging.forms_shown == [31], "불러온 양식을 보여 준다")
	consent.status = 3
	messaging.on_consent_form_dismissed.emit(31, {})
	await _frames()
	_check(ads_native.initialized == 1 and live.ads.can_request_ads(), "동의를 받으면 광고 SDK를 초기화한다")
	_check(not live.ads.analytics_allowed() and not live.ads.consent_pending(), "동의 양식을 거친 지역은 분석을 보내지 않는다")
	_check(rewarded.loads.is_empty() and interstitial.loads.is_empty(), "초기화가 끝나기 전에는 불러오지 않는다")

	# 초기화와 불러오기.
	ads_native.on_initialization_complete.emit({})
	await _frames()
	_check(ads_native.configuration == {"max_ad_content_rating": "PG", "tag_for_child_directed_treatment": -1, "tag_for_under_age_of_consent": -1}, "최대 콘텐츠 등급은 PG, 어린이 대상 태그는 지정하지 않는다")
	_check(ads_native.test_devices.is_empty(), "테스트 기기 ID를 넣지 않는다")
	_check(rewarded.loads.size() == 1 and rewarded.loads[0]["unit"] == Values.TEST_UNITS["rewarded"], "주입 값이 없으면 보상형은 Google 테스트 단위로 불러온다")
	_check(interstitial.loads.size() == 1 and interstitial.loads[0]["unit"] == Values.TEST_UNITS["interstitial"], "전면도 Google 테스트 단위로 불러온다")
	_check(str(rewarded.loads[0]["request"].get("google_request_agent", "")).begins_with("Godot-PoingStudios-"), "플러그인의 요청 표식이 붙는다")
	_check(not live.ads.is_ready("rewarded") and not live.ads.is_ready("interstitial"), "불러오는 중이다")
	rewarded.on_rewarded_ad_loaded.emit(rewarded.loads[0]["uid"])
	interstitial.on_interstitial_ad_failed_to_load.emit(interstitial.loads[0]["uid"], {"code": 3, "domain": "probe", "message": "no fill", "cause": {}, "response_info": {}})
	await _frames()
	_check(live.ads.is_ready("rewarded") and not live.ads.is_ready("interstitial"), "불러온 보상형만 준비됐다")

	# 보상형: 끝까지 봤다.
	var first: int = rewarded.loads[0]["uid"]
	live.ads.show("rewarded", on_result)
	_check(log == ["presenting:true"] and rewarded.shown == [first], "소리 신호를 내고 불러 둔 광고를 보여 준다")
	rewarded.on_rewarded_ad_showed_full_screen_content.emit(first)
	rewarded.on_rewarded_ad_impression.emit(first)
	rewarded.on_rewarded_ad_user_earned_reward.emit(first, {"amount": 1, "type": "reward"})
	await _frames()
	_check(log == ["presenting:true"], "닫히기 전에는 결과가 없다")
	rewarded.on_rewarded_ad_dismissed_full_screen_content.emit(first)
	await _frames()
	_check(log == ["presenting:true", "presenting:false", "result:earned"], "보상을 받고 닫으면 earned다")
	_check(rewarded.destroyed == [first] and rewarded.loads.size() == 2, "보여 준 광고를 버리고 다음 것을 불러온다")
	log.clear()

	# 보상형: 닫힘 알림이 보상 알림보다 먼저 왔다.
	var second: int = rewarded.loads[1]["uid"]
	rewarded.on_rewarded_ad_loaded.emit(second)
	await _frames()
	live.ads.show("rewarded", on_result)
	rewarded.on_rewarded_ad_showed_full_screen_content.emit(second)
	rewarded.on_rewarded_ad_dismissed_full_screen_content.emit(second)
	rewarded.on_rewarded_ad_user_earned_reward.emit(second, {"amount": 1, "type": "reward"})
	await _frames()
	_check(log == ["presenting:true", "presenting:false", "result:earned"], "닫힘이 먼저 와도 보상이 뒤따르면 earned다")
	log.clear()

	# 보상형: 중간에 닫았다. 늦은 보상을 기다리는 시간은 프레임으로 흐른다.
	var third: int = rewarded.loads[2]["uid"]
	rewarded.on_rewarded_ad_loaded.emit(third)
	await _frames()
	live.ads.show("rewarded", on_result)
	rewarded.on_rewarded_ad_showed_full_screen_content.emit(third)
	rewarded.on_rewarded_ad_dismissed_full_screen_content.emit(third)
	await _frames()
	_check(log == ["presenting:true"], "보상 없이 닫히면 잠깐 기다린다")
	for _step: int in 10:
		live.ads.advance(0.25)
	_check(log == ["presenting:true", "presenting:false", "result:dismissed"], "보상이 오지 않으면 dismissed다")
	rewarded.on_rewarded_ad_user_earned_reward.emit(third, {"amount": 1, "type": "reward"})
	await _frames()
	_check(log.size() == 3, "끝난 광고의 늦은 보상 알림은 무시한다")
	log.clear()

	# 전면: 다시 불러와 보여 주고 닫는다.
	for _step: int in 12:
		live.ads.advance(1.0)
	_check(interstitial.loads.size() == 2, "실패한 전면은 간격을 두고 다시 불러온다")
	var banner: int = interstitial.loads[1]["uid"]
	interstitial.on_interstitial_ad_loaded.emit(banner)
	await _frames()
	_check(live.ads.is_ready("interstitial"), "전면이 준비됐다")
	live.ads.show("interstitial", on_result)
	_check(interstitial.shown == [banner], "전면을 보여 준다")
	interstitial.on_interstitial_ad_showed_full_screen_content.emit(banner)
	interstitial.on_interstitial_ad_dismissed_full_screen_content.emit(banner)
	await _frames()
	_check(log == ["presenting:true", "presenting:false", "result:dismissed"], "전면을 닫으면 dismissed다")
	_check(interstitial.destroyed.has(banner) and interstitial.loads.size() == 3, "전면도 버리고 다시 불러온다")
	log.clear()

	# 전면: 뜨지 못했다.
	var broken: int = interstitial.loads[2]["uid"]
	interstitial.on_interstitial_ad_loaded.emit(broken)
	await _frames()
	live.ads.show("interstitial", on_result)
	interstitial.on_interstitial_ad_failed_to_show_full_screen_content.emit(broken, {"code": 1, "domain": "probe", "message": "not ready", "cause": {}})
	await _frames()
	_check(log == ["presenting:true", "presenting:false", "result:failed"], "뜨지 못하면 failed다")
	log.clear()

	# 개인정보 선택.
	_check(not live.ads.privacy_choice_required(), "요건이 없으면 진입점이 없다")
	consent.privacy_status = 2
	_check(live.ads.privacy_choice_required(), "요건이 있으면 진입점을 보인다")
	var before: int = consent_changes[0]
	live.ads.open_privacy_choice()
	_check(messaging.privacy_forms == 1, "개인정보 선택 양식을 연다")
	messaging.on_privacy_options_form_dismissed_listener.emit({})
	await _frames()
	_check(consent_changes[0] == before + 1 and live.ads.can_request_ads(), "양식을 닫으면 동의 상태를 다시 읽는다")

	# 답을 기다리는 불러오기를 끝내고 어댑터를 지운다.
	rewarded.on_rewarded_ad_loaded.emit(rewarded.loads[-1]["uid"])
	interstitial.on_interstitial_ad_loaded.emit(interstitial.loads[-1]["uid"])
	await _frames()
	_check(live.ads.is_ready("rewarded") and live.ads.is_ready("interstitial"), "마지막에 불러온 광고 둘이 준비됐다")
	var destroyed: int = rewarded.destroyed.size() + interstitial.destroyed.size()
	live.queue_free()
	await _frames()
	_check(rewarded.destroyed.size() + interstitial.destroyed.size() == destroyed + 2, "트리에서 빠지면 불러 둔 광고를 버린다")

	# 기기 검수용 설정: 등록한 기기를 규제 지역에 있는 것으로 다루게 한다.
	var debug_live: LiveServices = LiveServices.new("user://fa-admob-sdk-probe-unused")
	debug_live.ads.set_consent_debug("eea", ["AAAA", "BBBB"])
	root.add_child(debug_live)
	await _frames()
	_check(consent.updates[-1]["consent_debug_settings"] == {"debug_geography": 1, "test_device_hashed_ids": {0: "AAAA", 1: "BBBB"}}, "검수용 설정은 UMP의 지역(EEA)과 기기 해시로 전해진다")
	debug_live.queue_free()
	await _frames()


## 플러그인의 정적 변수가 붙들고 있는 콜백을 놓는다. 놓지 않으면 끝날 때 어댑터가 남는다.
func _release_plugin_callbacks() -> void:
	var mobile_ads: GDScript = load("res://addons/admob/gdscript/src/api/MobileAds.gd")
	mobile_ads.set("_current_on_initialization_complete_listener", null)
	var messaging: GDScript = load("res://addons/admob/gdscript/src/ump/api/UserMessagingPlatform.gd")
	for field: String in ["_on_consent_form_load_success_listener_callback", "_on_consent_form_load_failure_listener_callback", "_on_privacy_options_form_dismissed_callback", "active_consent_form"]:
		messaging.set(field, null)
	var information: Object = messaging.get("consent_information")
	if information != null:
		information.set("_on_consent_info_updated_success_callback", null)
		information.set("_on_consent_info_updated_failure_callback", null)
