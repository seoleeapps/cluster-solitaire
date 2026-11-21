class_name FaStorePort
extends RefCounted
## 제품 저장 파일의 읽기와 쓰기. 구현은 adapters에서 연결하고, 이 기본 구현은 저장이 없는 것처럼 동작한다.
## 저장은 기기 안 파일 하나와 직전 백업 하나다.

const SLOT_MAIN := "main"
const SLOT_BACKUP := "backup"


## slot(main 또는 backup)의 저장을 읽는다. 결과는 {found, data}다.
##   found: 파일이 있는지. data: JSON으로 읽은 값이고, 파일이 있어도 읽지 못했으면 null.
func read(_slot: String) -> Dictionary:
	return {"found": false, "data": null}


## 저장을 쓴다. 구현은 쓰기 전의 저장을 backup으로 남긴다. 성공하면 true.
func write(_data: Dictionary) -> bool:
	return false


## 저장과 백업을 지운다(설정의 데이터 초기화). 지운 뒤 읽으면 저장이 없는 것과 같다. 모두 지웠으면 true.
func erase() -> bool:
	return true
