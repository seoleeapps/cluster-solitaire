class_name FaAdSdk
extends RefCounted
## 광고와 동의 SDK의 경계. FaAdmobAds는 이 메서드만 부른다. 실제 구현은 FaAdmobSdk(Android의 AdMob 플러그인)이고,
## 이 기본 구현은 SDK가 없는 환경(개발 PC, 플러그인 없이 내보낸 빌드)이다.
## 콜백은 SDK가 답할 때 한 번 부른다. 답이 오지 않는 경우는 FaAdmobAds가 시간으로 처리한다.

## UMP 동의 상태. com.google.android.ump.ConsentInformation.ConsentStatus와 같은 값이다.
const CONSENT_UNKNOWN := 0
const CONSENT_NOT_REQUIRED := 1
const CONSENT_REQUIRED := 2
const CONSENT_OBTAINED := 3

const RATING_PG := "PG"

const GEOGRAPHY_EEA := "eea"
const GEOGRAPHY_NOT_EEA := "not_eea"


## SDK를 쓸 수 있는지.
func available() -> bool:
	return false


## 동의 정보를 갱신한다. 끝나면 on_done(성공 여부)를 부른다.
func update_consent(_on_done: Callable) -> void:
	pass


## 기기 검수용. 이후의 동의 갱신에서 UMP가 이 기기를 geography(GEOGRAPHY_*)에 있는 것으로 다루게 한다.
## device_ids는 UMP가 로그에 알려 주는 기기 해시다. 등록한 기기에서만 듣는다.
func set_consent_debug(_geography: String, _device_ids: PackedStringArray) -> void:
	pass


## 지금의 동의 상태. 갱신을 요청하기 전에는 UNKNOWN이고, 요청한 뒤 갱신이 끝날 때까지는 지난 실행의 값이다.
func consent_status() -> int:
	return CONSENT_UNKNOWN


## 보여 줄 동의 양식이 있는지.
func consent_form_available() -> bool:
	return false


## 동의 양식을 불러와 보여 준다. 닫히거나 불러오지 못하면 on_done()을 부른다.
func show_consent_form(_on_done: Callable) -> void:
	pass


## 개인정보 선택 진입점을 보여 줘야 하는지.
func privacy_options_required() -> bool:
	return false


## 개인정보 선택 양식을 보여 준다. 닫히면 on_done()을 부른다.
func show_privacy_options(_on_done: Callable) -> void:
	pass


## 광고 SDK를 초기화한다. 끝나면 on_done()을 부른다.
func initialize(_on_done: Callable) -> void:
	pass


## 이후 광고 요청에 쓸 최대 콘텐츠 등급을 정한다. 어린이 대상 처리 태그는 지정하지 않는다.
func set_max_ad_content_rating(_rating: String) -> void:
	pass


## 비개인화 광고(npa=1) 요청 여부. iOS No-ATT 등 UMP 없이 광고할 때 켠다.
func set_non_personalized(_enabled: bool) -> void:
	pass


## format(rewarded, interstitial)의 광고를 불러온다. 끝나면 on_done(성공 여부)를 부른다.
func load_ad(_format: String, _unit_id: String, _on_done: Callable) -> void:
	pass


## 불러 둔 광고를 보여 준다. 일이 생길 때마다 on_event(FaAdShow의 EVENT_* 이름)를 부른다.
func show_ad(_format: String, _on_event: Callable) -> void:
	pass


## 그 형식의 광고(불러 둔 것, 불러오는 중인 것, 보여 준 것)를 버린다. 버린 광고의 알림은 더 오지 않는다.
func discard_ad(_format: String) -> void:
	pass


## 불러 둔 광고와 SDK에 넘긴 콜백을 놓는다. 어댑터를 더 쓰지 않을 때 부른다.
func shutdown() -> void:
	pass
