extends "res://game/core/ports/fa_ads_port.gd"
## 화면 여정용 광고 대역. 형식별 준비 여부를 정하고, 보여 달라는 요청은 여정이 finish로 결과를 넣을 때까지 떠 있는 것으로 둔다.
## 실제 광고 SDK처럼 결과가 나중에 오므로, 화면이 광고가 떠 있는 동안 입력을 막는지도 확인할 수 있다.

var ready: Dictionary = {"rewarded": true, "interstitial": true}
## 미리 불러 달라고 한 형식과 보여 달라고 한 형식(순서대로).
var requests: Array[String] = []
var shown: Array[String] = []
## 동의: 이번 실행의 동의 확인이 끝났는지, 개인정보 선택 진입점이 필요한지, 그 화면을 연 횟수.
var consent_done: bool = true
var privacy_required: bool = false
var privacy_opened: int = 0

var _showing: String = ""
var _on_result: Callable


func is_ready(format: String) -> bool:
	return ready.get(format, false)


func request(format: String) -> void:
	requests.append(format)


func show(format: String, on_result: Callable) -> void:
	shown.append(format)
	if not is_ready(format):
		on_result.call(RESULT_FAILED)
		return
	_showing = format
	_on_result = on_result


func consent_settled() -> bool:
	return consent_done


func privacy_choice_required() -> bool:
	return privacy_required


func open_privacy_choice() -> void:
	privacy_opened += 1


## 동의 확인을 끝낸다(동의 창이 닫힌 것처럼). 개인정보 선택 요건을 함께 정하고 consent_changed를 알린다.
func settle_consent(required: bool) -> void:
	consent_done = true
	privacy_required = required
	consent_changed.emit()


## 지금 떠 있는 광고의 형식. 없으면 "".
func showing() -> String:
	return _showing


## 떠 있는 광고를 결과(earned, dismissed, failed)와 함께 끝낸다. 떠 있는 광고가 없으면 false.
func finish(result: String) -> bool:
	if _showing.is_empty():
		return false
	var on_result: Callable = _on_result
	_showing = ""
	_on_result = Callable()
	on_result.call(result)
	return true
