extends "res://game/core/ports/fa_clock_port.gd"
## 기기의 시계. 날짜는 기기의 현지 날짜다.


func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func today() -> String:
	return Time.get_date_string_from_system(false)
