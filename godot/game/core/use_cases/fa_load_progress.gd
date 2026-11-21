class_name FaLoadProgress
extends RefCounted
## 앱을 시작할 때 저장을 읽는다. 높은 버전이나 깨진 파일이면 직전 백업을 읽고, 백업도 쓸 수 없으면 새로 시작한다.

const Progress := preload("res://game/core/domain/fa_progress.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")

const ORIGIN_NEW := "new"

var _store: StorePort


func _init(store: StorePort) -> void:
	_store = store


## 결과는 {progress, origin, reset}다.
##   origin: 읽은 곳(main, backup) 또는 새로 시작했으면 new.
##   reset: 저장 파일이 있었는데도 쓸 수 없어 새로 시작했는지. true면 화면이 그 사실을 알린다.
func execute() -> Dictionary:
	var found: bool = false
	for slot: String in [StorePort.SLOT_MAIN, StorePort.SLOT_BACKUP]:
		var stored: Dictionary = _store.read(slot)
		if not stored["found"]:
			continue
		found = true
		var progress: Progress = Progress.read(stored["data"])["progress"]
		if progress != null:
			return {"progress": progress, "origin": slot, "reset": false}
	return {"progress": Progress.create(), "origin": ORIGIN_NEW, "reset": found}
