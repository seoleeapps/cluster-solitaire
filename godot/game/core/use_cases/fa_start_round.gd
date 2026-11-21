class_name FaStartRound
extends RefCounted
## 판을 시작하고, 진행 중인 판을 저장하고 되살린다. 레벨은 FaPickLevel이 찾은 것을 받는다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

var _store: StorePort
var _analytics: AnalyticsPort


func _init(store: StorePort, analytics: AnalyticsPort) -> void:
	_store = store
	_analytics = analytics


## 새 판을 임시 칸 2개로 시작해 진행 중인 판으로 기록한다. 이전에 진행하던 판은 덮어쓴다.
## mode는 journey, daily, tutorial이고 여정은 stage, 일일 도전은 date가 판의 id다.
## 레벨 형식이 틀리거나 아직 열리지 않은 스테이지, 잘못된 날짜면 null이다.
func start(progress: Progress, mode: String, stage: int, date: String, level: Dictionary) -> Board:
	if mode == RoundMode.JOURNEY and stage > progress.stage():
		return null
	var board: Board = Board.create(level, Board.HOLD_SLOTS_BASE)
	if board == null or not progress.set_run(mode, stage, date, 0, board):
		return null
	_store.write(progress.to_dict())
	_analytics.log_event("level_start", {"level_name": RoundMode.level_name(mode, stage, date), "mode": mode})
	return board


## 진행 중인 판을 되살린다. 없으면 null이다. 판의 종류와 id, 걸린 시간은 progress.run()에서 읽는다.
func resume(progress: Progress) -> Board:
	return Board.from_dict(progress.run()["board"]) if progress.has_run() else null


## 판이 바뀔 때마다 불러 진행 중인 판을 저장한다. seconds는 이 판에 지금까지 쓴 시간이다. 저장했으면 true.
func checkpoint(progress: Progress, board: Board, seconds: int) -> bool:
	return progress.update_run(board, seconds) and _store.write(progress.to_dict())


## 끝내지 않고 판을 버린다(다시 하기, 나가기).
func abandon(progress: Progress) -> void:
	if not progress.has_run():
		return
	var run: Dictionary = progress.run()
	progress.clear_run()
	_store.write(progress.to_dict())
	_analytics.log_event("level_end", {
		"level_name": RoundMode.level_name(run["mode"], run["stage"], run["date"]), "mode": run["mode"], "success": false,
	})
