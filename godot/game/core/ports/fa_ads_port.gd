class_name FaAdsPort
extends RefCounted
## 광고 SDK와의 경계. 구현은 adapters에서 연결하고, 이 기본 구현은 광고가 없는 것처럼 동작한다.
## 형식(format)은 rewarded와 interstitial이다. 지금 내도 되는지는 FaAdPolicy가 판정하고 여기서는 묻지 않는다.

## 동의 상태나 개인정보 선택 요건이 바뀌었을 수 있다. 분석 선택과 설정 화면이 다시 읽는다.
signal consent_changed

const RESULT_EARNED := "earned"
const RESULT_DISMISSED := "dismissed"
const RESULT_FAILED := "failed"


## 그 형식의 광고가 불러와져 바로 보여 줄 수 있는지.
func is_ready(_format: String) -> bool:
	return false


## 그 형식의 광고를 미리 불러온다.
func request(_format: String) -> void:
	pass


## 광고를 보여 주고, 끝나면 on_result를 결과 하나와 함께 한 번 부른다.
##   earned: 보상형을 끝까지 봤다. dismissed: 떴다가 닫혔다(전면의 정상 종료, 보상형의 중도 닫기).
##   failed: 뜨지 못했다.
func show(_format: String, on_result: Callable) -> void:
	on_result.call(RESULT_FAILED)


## 이번 실행의 동의 확인이 끝났는지(동의 창을 띄웠다면 닫혔는지). 타이틀은 끝나기를 기다린 뒤 시작 버튼을 보인다.
## 동의를 물을 것이 없는 구현은 참이다.
func consent_settled() -> bool:
	return true


## 개인정보 선택 화면으로 가는 진입점을 보여 줘야 하는지.
func privacy_choice_required() -> bool:
	return false


## 개인정보 선택 화면을 연다.
func open_privacy_choice() -> void:
	pass
