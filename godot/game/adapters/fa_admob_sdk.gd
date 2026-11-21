class_name FaAdmobSdk
extends "res://game/adapters/fa_ad_sdk.gd"
## AdMob 플러그인(Poing Studios 5.1.0, godot/addons/admob)으로 FaAdSdk를 구현한다.
## 플러그인의 클래스를 참조하는 파일은 이것 하나다. FaLiveServices가 플러그인의 네이티브 싱글턴이 있을 때만 불러온다.
##
## 플러그인은 UMP의 canRequestAds를 내보내지 않는다. 같은 조건(동의 상태가 NOT_REQUIRED이거나 OBTAINED)을
## FaAdmobAds.can_request_ads가 동의 상태로 판정한다.
## 플러그인의 콜백은 인자 형이 일정하지 않아(오류가 없으면 null) 받는 쪽 인자에 형을 적지 않는다.

const AdShow := preload("res://game/adapters/fa_ad_show.gd")

const FORMAT_REWARDED := "rewarded"
## 광고, 동의에 쓰는 네이티브 싱글턴. 하나라도 없으면 SDK가 없는 것으로 본다.
const SINGLETONS: Array[String] = [
	"PoingGodotAdMob", "PoingGodotAdMobRewardedAd", "PoingGodotAdMobInterstitialAd",
	"PoingGodotAdMobConsentInformation", "PoingGodotAdMobUserMessagingPlatform",
]

## 형식별로 불러 둔 광고(RewardedAd 또는 InterstitialAd).
var _ads: Dictionary = {}
## 형식별 번호. 광고를 버릴 때마다 올려, 버린 광고의 늦은 알림을 걸러 낸다.
var _serial: Dictionary = {}
## 형식별로 마지막에 쓴 불러오기 객체(RewardedAdLoader 또는 InterstitialAdLoader).
## 플러그인의 불러오기 객체는 답을 받을 때까지 스스로를 붙들었다가 놓는데, 그때 다른 곳에서 붙들고 있지 않으면
## 지워지지 않고 남는다. 다음 불러오기까지 여기서 붙들어 두어 제대로 지워지게 한다.
var _loaders: Dictionary = {}


func available() -> bool:
	for singleton: String in SINGLETONS:
		if not Engine.has_singleton(singleton):
			return false
	return true


func update_consent(on_done: Callable) -> void:
	UserMessagingPlatform.consent_information.update(
		ConsentRequestParameters.new(),
		func() -> void: on_done.call(true),
		func(_error: Variant) -> void: on_done.call(false))


func consent_status() -> int:
	return UserMessagingPlatform.consent_information.get_consent_status()


func consent_form_available() -> bool:
	return UserMessagingPlatform.consent_information.get_is_consent_form_available()


func show_consent_form(on_done: Callable) -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: Variant) -> void: form.show(func(_error: Variant) -> void: on_done.call()),
		func(_error: Variant) -> void: on_done.call())


func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options(on_done: Callable) -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_error: Variant) -> void: on_done.call())


func initialize(on_done: Callable) -> void:
	var listener: OnInitializationCompleteListener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: Variant) -> void: on_done.call()
	MobileAds.initialize(listener)


func set_max_ad_content_rating(rating: String) -> void:
	var configuration: RequestConfiguration = RequestConfiguration.new()
	configuration.max_ad_content_rating = rating
	MobileAds.set_request_configuration(configuration)


func load_ad(format: String, unit_id: String, on_done: Callable) -> void:
	discard_ad(format)
	var serial: int = _serial[format]
	var loaded: Callable = func(ad: Variant) -> void:
		if _serial[format] != serial:
			ad.destroy()
			return
		_ads[format] = ad
		on_done.call(true)
	var failed: Callable = func(_error: Variant) -> void:
		if _serial[format] == serial:
			on_done.call(false)
	if format == FORMAT_REWARDED:
		var callback: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
		callback.on_ad_loaded = loaded
		callback.on_ad_failed_to_load = failed
		var loader: RewardedAdLoader = RewardedAdLoader.new()
		_loaders[format] = loader
		loader.load(unit_id, AdRequest.new(), callback)
	else:
		var callback: InterstitialAdLoadCallback = InterstitialAdLoadCallback.new()
		callback.on_ad_loaded = loaded
		callback.on_ad_failed_to_load = failed
		var loader: InterstitialAdLoader = InterstitialAdLoader.new()
		_loaders[format] = loader
		loader.load(unit_id, AdRequest.new(), callback)


func show_ad(format: String, on_event: Callable) -> void:
	var ad: Variant = _ads.get(format)
	if ad == null:
		on_event.call(AdShow.EVENT_FAILED)
		return
	var serial: int = _serial[format]
	var relay: Callable = func(kind: String) -> void:
		if _serial[format] == serial:
			on_event.call(kind)
	var content: FullScreenContentCallback = ad.full_screen_content_callback
	content.on_ad_showed_full_screen_content = func() -> void: relay.call(AdShow.EVENT_SHOWED)
	content.on_ad_impression = func() -> void: relay.call(AdShow.EVENT_SHOWED)
	content.on_ad_dismissed_full_screen_content = func() -> void: relay.call(AdShow.EVENT_DISMISSED)
	content.on_ad_failed_to_show_full_screen_content = func(_error: Variant) -> void: relay.call(AdShow.EVENT_FAILED)
	if format == FORMAT_REWARDED:
		var listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
		listener.on_user_earned_reward = func(_item: Variant) -> void: relay.call(AdShow.EVENT_REWARD)
		ad.show(listener)
	else:
		ad.show()


func discard_ad(format: String) -> void:
	_serial[format] = int(_serial.get(format, 0)) + 1
	var ad: Variant = _ads.get(format)
	if ad != null:
		ad.destroy()
		_ads.erase(format)


func shutdown() -> void:
	for format: Variant in _serial.keys():
		discard_ad(format)
	_loaders.clear()
