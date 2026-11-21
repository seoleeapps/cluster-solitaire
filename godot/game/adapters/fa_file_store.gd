extends "res://game/core/ports/fa_store_port.gd"
## 제품 저장 파일. 기기 안의 JSON 파일 하나와 직전 백업 하나다.
## 쓰기는 임시 파일에 쓴 뒤 이름을 바꾸고(공통 저장 도구), 쓰기 전의 저장은 이름을 바꿔 백업으로 남긴다.
## 실행한 뒤 첫 쓰기는 백업을 건드리지 않는다. 시작할 때 본 파일이 깨져 백업에서 읽었다면, 그 백업을 깨진 파일로 덮지 않기 위해서다.

const AtomicStore := preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")

const BACKUP_SUFFIX := ".bak"

var _path: String
## 이 실행에서 본 파일을 한 번이라도 썼는지. 썼다면 본 파일은 온전하므로 다음 쓰기 때 백업으로 돌린다.
var _wrote: bool = false


func _init(path: String) -> void:
	_path = path


func path() -> String:
	return _path


func read(slot: String) -> Dictionary:
	var file: String = _path + BACKUP_SUFFIX if slot == SLOT_BACKUP else _path
	if not FileAccess.file_exists(file):
		return {"found": false, "data": null}
	var result: Dictionary = AtomicStore.read_dictionary(file)
	return {"found": true, "data": result["value"] if result["ok"] else null}


func write(data: Dictionary) -> bool:
	if _wrote and FileAccess.file_exists(_path):
		var backup: String = ProjectSettings.globalize_path(_path + BACKUP_SUFFIX)
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(_path), backup)
	var saved: bool = AtomicStore.write(_path, data)
	_wrote = _wrote or saved
	return saved
