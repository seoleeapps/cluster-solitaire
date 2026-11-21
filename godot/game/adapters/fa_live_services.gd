class_name FaLiveServices
extends Node
## 실제 서비스 어댑터(광고와 동의, 분석, 원격 설정)를 만들어 돌린다.
## bootstrap이 하나 만들어 트리에 넣고 ads, analytics, config를 포트 묶음에 끼운다.
## 트리에 들어가면 동의 갱신과 원격 설정 받기를 시작하고, 프레임마다 어댑터의 시간을 흘린다.
## 오래 백그라운드에 있다가 돌아와 새 실행으로 볼지는 bootstrap이 정하고 begin_session()을 부른다.
## 동의가 바뀐 것은 광고 포트의 consent_changed로 알린다.
##
## AdMob 플러그인의 네이티브 싱글턴이 없는 환경(개발 PC, headless 검수)에서는 광고가 준비되지 않은 것으로,
## 분석과 원격 설정은 꺼진 것으로 동작하고 네트워크를 쓰지 않는다. 주입된 서비스 값은 내보낸 빌드에서만 읽는다.
## 화면을 다시 그릴 때 지우는 노드 아래에 두지 않는다. 지워지면 광고와 분석이 멈춘다.

const AdSdk := preload("res://game/adapters/fa_ad_sdk.gd")
const AdmobAds := preload("res://game/adapters/fa_admob_ads.gd")
const Ga4Analytics := preload("res://game/adapters/fa_ga4_analytics.gd")
const RemoteConfig := preload("res://game/adapters/fa_remote_config.gd")
const ConfigRules := preload("res://game/adapters/fa_remote_config_rules.gd")
const ServiceValues := preload("res://game/adapters/fa_service_values.gd")
const JsonFiles := preload("res://game/adapters/fa_json_files.gd")
const Http := preload("res://game/adapters/fa_http.gd")

## AdMob 플러그인을 감싼 구현. 플러그인의 클래스를 참조하므로 싱글턴이 있을 때만 불러온다.
const ADMOB_SDK_PATH := "res://game/adapters/fa_admob_sdk.gd"
const ADMOB_SINGLETON := "PoingGodotAdMob"
const PROFILE_PATH := "res://data/monetization/bm-profile.json"
## 기기 검수용 실행 인자. 디버그 빌드에서만 듣는다. 동의 양식은 규제 지역에서만 뜨므로,
## 다른 지역의 기기에서 양식을 확인하려면 UMP가 로그에 알려 주는 기기 해시와 함께 지역을 정해 준다.
##   --fa-consent-geography=eea 또는 not_eea, --fa-consent-device=<기기 해시>(여러 번 줄 수 있다)
const CONSENT_GEOGRAPHY_ARGUMENT := "--fa-consent-geography="
const CONSENT_DEVICE_ARGUMENT := "--fa-consent-device="

var ads: AdmobAds
var analytics: Ga4Analytics
var config: RemoteConfig

var _http: Http


## storage_dir은 어댑터가 파일을 두는 폴더다(실제 앱은 FaSavePaths.services). 검수는 실행마다 다른 폴더를 넘긴다.
func _init(storage_dir: String) -> void:
	name = "FaLiveServices"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var values: ServiceValues = ServiceValues.load_packed()
	var profile: Variant = _read_json(PROFILE_PATH)
	var files: JsonFiles = JsonFiles.new(storage_dir)
	_http = Http.new()
	add_child(_http)
	ads = AdmobAds.new(_make_sdk(), values.ad_units())
	var arguments: PackedStringArray = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	var consent_debug: Dictionary = consent_debug_from(arguments, OS.is_debug_build())
	if not consent_debug.is_empty():
		ads.set_consent_debug(consent_debug["geography"], consent_debug["devices"])
	analytics = Ga4Analytics.new(
		values, files, _http.send, _analytics_gate, Time.get_unix_time_from_system,
		str(ProjectSettings.get_setting("application/config/version", "")), OS.is_debug_build())
	config = RemoteConfig.new(ConfigRules.from_profile(profile), files, _http.send, values.config_url())


func _ready() -> void:
	begin_session()
	ads.start()
	config.start()


## 새 실행(세션)을 시작한다. 트리에 들어갈 때 한 번, 그리고 bootstrap이 오래 백그라운드에 있다가 돌아왔다고 판단할 때 부른다.
func begin_session() -> void:
	analytics.begin_session()


func _exit_tree() -> void:
	ads.stop()


func _process(delta: float) -> void:
	ads.advance(delta)
	analytics.advance(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			analytics.flush()
		NOTIFICATION_APPLICATION_RESUMED:
			ads.resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			analytics.flush()


## 실행 인자에서 검수용 동의 설정 {geography, devices}를 읽는다. 디버그 빌드가 아니거나 지역 인자가 없으면 빈 값이다.
static func consent_debug_from(arguments: PackedStringArray, debug_build: bool) -> Dictionary:
	if not debug_build:
		return {}
	var geography: String = ""
	var devices: PackedStringArray = []
	for argument: String in arguments:
		if argument.begins_with(CONSENT_GEOGRAPHY_ARGUMENT):
			geography = argument.trim_prefix(CONSENT_GEOGRAPHY_ARGUMENT)
		elif argument.begins_with(CONSENT_DEVICE_ARGUMENT) and argument.length() > CONSENT_DEVICE_ARGUMENT.length():
			devices.append(argument.trim_prefix(CONSENT_DEVICE_ARGUMENT))
	if geography != AdSdk.GEOGRAPHY_EEA and geography != AdSdk.GEOGRAPHY_NOT_EEA:
		return {}
	return {"geography": geography, "devices": devices}


## 분석을 보내도 되는지를 광고 어댑터의 동의 상태로 정한다.
func _analytics_gate() -> int:
	if ads.analytics_allowed():
		return Ga4Analytics.GATE_OPEN
	return Ga4Analytics.GATE_WAIT if ads.consent_pending() else Ga4Analytics.GATE_CLOSED


func _make_sdk() -> AdSdk:
	if Engine.has_singleton(ADMOB_SINGLETON):
		var script: GDScript = load(ADMOB_SDK_PATH)
		if script != null:
			return script.new()
	return AdSdk.new()


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data
