class_name FaConfigPort
extends RefCounted
## 원격 설정 값 조회. 구현은 adapters에서 연결하고, 이 기본 구현은 받은 값이 없는 것처럼 동작한다.


## 열쇠의 원격 값. 받지 못했거나 없는 열쇠는 null이고, 그때는 쓰는 쪽이 내장 기본값을 쓴다.
func value(_key: String) -> Variant:
	return null
