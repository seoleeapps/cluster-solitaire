class_name FaClockPort
extends RefCounted
## 시계. 구현은 adapters에서 연결하고, 이 기본 구현은 멈춘 시계다.


## 현재 시각(유닉스 초).
func now_unix() -> int:
	return 0


## 기기의 현지 날짜(YYYY-MM-DD).
func today() -> String:
	return ""
