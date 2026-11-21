class_name FaFixedConfig
extends "res://game/core/ports/fa_config_port.gd"
## 원격 설정 포트의 테스트 대역. 넘겨받은 값을 그대로 돌려주고 아무것도 받아 오지 않는다.

## 열쇠별 값. 여정이 도중에 고쳐도 된다.
var values: Dictionary


func _init(initial: Dictionary = {}) -> void:
	values = initial.duplicate(true)


func value(key: String) -> Variant:
	return values.get(key)
