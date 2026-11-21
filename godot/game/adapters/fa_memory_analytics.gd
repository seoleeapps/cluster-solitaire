class_name FaMemoryAnalytics
extends "res://game/core/ports/fa_analytics_port.gd"
## 분석 포트의 테스트 대역. 받은 이벤트를 메모리에 순서대로 적어 두고 아무 데도 보내지 않는다.

## 받은 이벤트. 한 항목은 {name, params}다.
var events: Array[Dictionary] = []


func log_event(name: String, params: Dictionary) -> void:
	events.append({"name": name, "params": params.duplicate(true)})


## 받은 이벤트 이름(받은 순서).
func names() -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in events:
		result.append(event["name"])
	return result


## 그 이름의 이벤트를 받은 횟수.
func count(name: String) -> int:
	return names().count(name)


## 그 이름으로 마지막에 받은 이벤트의 매개변수. 받은 적이 없으면 빈 Dictionary.
func last(name: String) -> Dictionary:
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["name"] == name:
			return events[index]["params"]
	return {}


func clear() -> void:
	events.clear()
