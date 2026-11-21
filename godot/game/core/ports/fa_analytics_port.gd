class_name FaAnalyticsPort
extends RefCounted
## 분석 이벤트 전송. 구현은 adapters에서 연결하고, 이 기본 구현은 아무것도 보내지 않는다.
## 전송 실패는 구현이 버리며 게임 진행에 영향을 주지 않는다.


## 이벤트 이름과 매개변수를 보낸다. 이름은 GA4 권장 게임 이벤트를 먼저 쓴다.
func log_event(_name: String, _params: Dictionary) -> void:
	pass


## 기기에 남긴 분석 식별자와 보내지 않은 이벤트를 지우고, 처음 설치한 것처럼 다시 시작한다(설정의 데이터 초기화).
func forget_device() -> void:
	pass
