class_name FaServiceValues
extends RefCounted
## 빌드할 때 넣는 서비스 값. tools/prepare_services.py가 로컬 자격증명에서 읽어 PATH에 쓰고,
## 저장소는 그 파일을 추적하지 않는다.
##
## 값이 없으면 광고는 Google의 공개 테스트 단위를 쓰고 분석과 원격 설정은 꺼진다.
## 디버그 빌드는 값이 있어도 테스트 단위를 쓴다. 에디터와 headless 실행은 파일이 남아 있어도 읽지 않는다.
## 파일의 형식: {"admob_app_id", "admob_rewarded_unit", "admob_interstitial_unit",
##   "ga4_measurement_id", "ga4_api_secret", "remote_config_url"}. 모두 문자열이다.
## admob_app_id는 Android 매니페스트에 들어가는 값이고 실행 중에는 쓰지 않는다.

const Self := preload("res://game/adapters/fa_service_values.gd")

const PATH := "res://data/services/release.json"

## Google이 공개한 Android 테스트 광고 단위. https://developers.google.com/admob/android/test-ads
const TEST_UNITS := {
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
}

const UNIT_KEYS := {"rewarded": "admob_rewarded_unit", "interstitial": "admob_interstitial_unit"}
const UNIT_PATTERN := "^ca-app-pub-[0-9]{16}/[0-9]{10}$"
const MEASUREMENT_PATTERN := "^G-[A-Z0-9]{4,20}$"
const SECRET_PATTERN := "^[A-Za-z0-9_-]{8,64}$"
const URL_PATTERN := "^https://[A-Za-z0-9.-]+/[A-Za-z0-9._~/-]*$"

var _units: Dictionary = TEST_UNITS.duplicate()
var _test_ads: bool = true
var _measurement_id: String = ""
var _api_secret: String = ""
var _config_url: String = ""


## 내보낸 빌드에 든 값을 읽는다. 에디터와 headless 실행에서는 값이 없는 것으로 본다.
static func load_packed() -> Self:
	if not OS.has_feature("template") or not FileAccess.file_exists(PATH):
		return new()
	return from_text(FileAccess.get_file_as_string(PATH), OS.is_debug_build())


## 주입 파일의 글자에서 값을 만든다. 형식이 틀린 값은 없는 것으로 본다.
static func from_text(text: String, debug_build: bool) -> Self:
	var values: Self = new()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return values
	var document: Dictionary = parser.data
	var units: Dictionary = {}
	for format: String in UNIT_KEYS:
		var unit: String = _matching(document.get(UNIT_KEYS[format]), UNIT_PATTERN)
		if not unit.is_empty():
			units[format] = unit
	# 보상형과 전면이 모두 있어야 운영 단위를 쓴다. 한쪽만 있으면 설정이 깨진 것이므로 둘 다 테스트 단위로 둔다.
	if not debug_build and units.size() == UNIT_KEYS.size():
		values._units = units
		values._test_ads = false
	var measurement_id: String = _matching(document.get("ga4_measurement_id"), MEASUREMENT_PATTERN)
	var api_secret: String = _matching(document.get("ga4_api_secret"), SECRET_PATTERN)
	if not measurement_id.is_empty() and not api_secret.is_empty():
		values._measurement_id = measurement_id
		values._api_secret = api_secret
	values._config_url = _matching(document.get("remote_config_url"), URL_PATTERN)
	return values


## format(rewarded, interstitial)의 광고 단위 ID.
func ad_unit(format: String) -> String:
	return _units.get(format, "")


func ad_units() -> Dictionary:
	return _units.duplicate()


## 테스트 광고 단위를 쓰는지.
func uses_test_ads() -> bool:
	return _test_ads


## 분석을 보낼 값(측정 ID와 API 비밀값)이 있는지.
func analytics_configured() -> bool:
	return not _measurement_id.is_empty()


func measurement_id() -> String:
	return _measurement_id


func api_secret() -> String:
	return _api_secret


## 원격 설정 JSON의 주소. 없으면 "".
func config_url() -> String:
	return _config_url


static func _matching(value: Variant, pattern: String) -> String:
	if not value is String:
		return ""
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	return value if regex.search(value) != null else ""
