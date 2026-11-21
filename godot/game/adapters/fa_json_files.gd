class_name FaJsonFiles
extends RefCounted
## 어댑터가 기기에 두는 작은 JSON 파일(분석 대기열, 분석 식별자, 원격 설정 캐시).
## 폴더 하나 아래에서 이름으로 읽고 쓴다. 쓰기는 임시 파일에 쓴 뒤 이름을 바꾼다.

const Store := preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")

const DEFAULT_DIR := "user://services"

var _dir: String


func _init(dir: String = DEFAULT_DIR) -> void:
	_dir = dir


## 이름의 파일을 JSON으로 읽는다. 없거나 읽을 수 없으면 null.
func read(name: String) -> Variant:
	var path: String = _dir.path_join(name)
	if not FileAccess.file_exists(path):
		return null
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data


## 이름의 파일에 쓴다. 성공하면 true.
func write(name: String, data: Variant) -> bool:
	if DirAccess.make_dir_recursive_absolute(_dir) != OK:
		return false
	return Store.write(_dir.path_join(name), data)


## 이름의 파일을 지운다. 없으면 아무 일도 하지 않는다.
func remove(name: String) -> void:
	var path: String = _dir.path_join(name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
