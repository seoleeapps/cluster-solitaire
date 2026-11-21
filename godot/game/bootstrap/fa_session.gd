class_name FaSession
extends RefCounted
## 실행 한 번 동안의 제품 상태: 포트 묶음, 콘텐츠와 레벨 팩, 저장(진행), 유스케이스.
## 화면은 이 묶음을 받아 유스케이스를 부르고, 파일과 광고 SDK에는 직접 닿지 않는다.

const Self := preload("res://game/bootstrap/fa_session.gd")
const GameServices := preload("res://game/bootstrap/fa_services.gd")
const Content := preload("res://game/core/domain/fa_content.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const LoadProgress := preload("res://game/core/use_cases/fa_load_progress.gd")
const PickLevel := preload("res://game/core/use_cases/fa_pick_level.gd")
const StartRound := preload("res://game/core/use_cases/fa_start_round.gd")
const FinishRound := preload("res://game/core/use_cases/fa_finish_round.gd")
const UseBooster := preload("res://game/core/use_cases/fa_use_booster.gd")
const ContinueRound := preload("res://game/core/use_cases/fa_continue_round.gd")
const AdFlow := preload("res://game/core/use_cases/fa_ad_flow.gd")
const Shop := preload("res://game/core/use_cases/fa_shop.gd")
const Attendance := preload("res://game/core/use_cases/fa_attendance.gd")

const ITEMS_PATH := "res://data/content/items.json"
const CATEGORIES_PATH := "res://data/content/categories.json"
const JOURNEY_PATH := "res://data/levels/journey.json"
const DAILY_PATH := "res://data/levels/daily.json"
const TUTORIAL_PATH := "res://data/levels/tutorial.json"
const BM_PROFILE_PATH := "res://data/monetization/bm-profile.json"
## 공통 저장의 지급 기록 가운데 제품 코인으로 옮기는 것(우편 보상)의 열쇠 머리말.
const OUTGAME_MAIL_PREFIX := "mail:"
const OUTGAME_GRANT_PREFIX := "outgame:"

var services: GameServices
var catalog: Content
var levels: PickLevel
## 튜토리얼 판 {level, guide}. guide는 {order: 묶는 범주 순서, hold: 임시 칸으로 옮길 카드}다.
var tutorial: Dictionary = {}
var player: Progress
var ad_flow: AdFlow
var start_round: StartRound
var finish_round: FinishRound
var use_booster: UseBooster
var continue_round: ContinueRound
var shop: Shop
var attendance: Attendance
## 읽지 못한 자료(콘텐츠, 팩). 비어 있으면 문제 없음.
var problems: PackedStringArray = []
## 저장 파일이 있었는데 쓸 수 없어 새로 시작했는지. 화면이 알린다.
var save_reset: bool = false
## 뒤에 이만큼(초) 넘게 있다가 돌아오면 새 실행으로 본다(수익화 프로필의 값).
var session_reset_seconds: int = 0


## 콘텐츠와 팩, 저장을 읽어 실행 상태를 만든다.
static func open(bundle: GameServices) -> Self:
	var session: Self = new()
	session.services = bundle
	session.catalog = Content.new(_read(ITEMS_PATH), _read(CATEGORIES_PATH))
	session.problems.append_array(session.catalog.problems())
	session.levels = PickLevel.new(session.catalog, _read(JOURNEY_PATH), _read(DAILY_PATH))
	session.problems.append_array(session.levels.problems())
	var pack: Dictionary = _read(TUTORIAL_PATH)
	var pack_levels: Variant = pack.get("levels")
	if pack_levels is Array and pack_levels.size() == 1 and pack.get("guide") is Dictionary \
			and Board.create(pack_levels[0], Board.HOLD_SLOTS_BASE) != null:
		session.tutorial = {"level": pack_levels[0], "guide": pack["guide"]}
	else:
		session.problems.append("bad_pack: tutorial")
	var caps: Variant = _read(BM_PROFILE_PATH).get("caps")
	if caps is Dictionary:
		session.session_reset_seconds = int(caps.get("interstitial_session_reset_s", 0))

	var loaded: Dictionary = LoadProgress.new(bundle.store).execute()
	session.player = loaded["progress"]
	session.save_reset = loaded["reset"]
	session.ad_flow = AdFlow.new(bundle.store, bundle.ads, bundle.clock, bundle.config, bundle.analytics)
	session.start_round = StartRound.new(bundle.store, bundle.analytics, bundle.clock)
	session.finish_round = FinishRound.new(bundle.store, bundle.analytics)
	session.use_booster = UseBooster.new(bundle.store, bundle.analytics)
	session.continue_round = ContinueRound.new(bundle.store, bundle.analytics, session.ad_flow)
	session.shop = Shop.new(bundle.store, bundle.analytics)
	session.attendance = Attendance.new(bundle.store, bundle.analytics)
	return session


## 실행(세션)을 시작한다. 앱을 켰을 때와, 오래 뒤에 있다가 돌아왔을 때 부른다.
func begin_session() -> void:
	ad_flow.begin_session(player)
	services.ads.request("rewarded")
	services.ads.request("interstitial")


## 플레이할 판을 정한다. 튜토리얼이 진행 중이면 튜토리얼 판, 아니면 하던 판이나 다음 스테이지다.
## 결과는 {ok: true, board, mode, stage, date, seconds, resumed} 또는 {ok: false, error}다.
func open_round(tutorial_active: bool) -> Dictionary:
	var wanted: String = RoundMode.TUTORIAL if tutorial_active else RoundMode.JOURNEY
	if player.has_run():
		var mode: String = player.run()["mode"]
		if (mode == RoundMode.TUTORIAL) == tutorial_active:
			return _resumed()
		# 다른 종류의 판이 남아 있으면 버리고(완성한 범주는 도감에 남는다) 새로 시작한다.
		start_round.abandon(player)
	if wanted == RoundMode.TUTORIAL:
		return _started(RoundMode.TUTORIAL, 0, "", tutorial.get("level", {}))
	return _start_stage(player.stage())


## 지금 판을 버리고 같은 판을 처음부터 다시 시작한다.
func restart_round() -> Dictionary:
	if not player.has_run():
		return {"ok": false, "error": "no_run"}
	var run: Dictionary = player.run()
	start_round.abandon(player)
	match run["mode"]:
		RoundMode.TUTORIAL:
			return _started(RoundMode.TUTORIAL, 0, "", tutorial.get("level", {}))
		RoundMode.DAILY:
			return open_daily(run["date"])
	return _start_stage(run["stage"])


## 날짜의 일일 도전 판을 시작한다. 하던 판이 그 날짜의 일일 도전이면 잇는다.
func open_daily(date: String) -> Dictionary:
	if player.has_run():
		var run: Dictionary = player.run()
		if run["mode"] == RoundMode.DAILY and run["date"] == date:
			return _resumed()
		start_round.abandon(player)
	var found: Dictionary = levels.daily(date)
	if not found["ok"]:
		return {"ok": false, "error": found["error"]}
	return _started(RoundMode.DAILY, 0, date, found["level"])


## 진행 중인 판을 버린다(홈으로). 버린 판에서 완성한 범주는 도감에 남는다.
func drop_round() -> void:
	start_round.abandon(player)


## 공통 저장의 우편 보상을 제품 코인으로 한 번씩 옮긴다. grants는 공통 저장의 지급 기록 {열쇠: 코인}이다.
## 옮긴 것이 있으면 저장하고 true를 돌려준다.
func absorb_outgame_grants(grants: Dictionary) -> bool:
	var moved: bool = false
	for key: Variant in grants:
		var amount: Variant = grants[key]
		if key is String and key.begins_with(OUTGAME_MAIL_PREFIX) and (amount is int or amount is float) and amount > 0:
			moved = player.grant(OUTGAME_GRANT_PREFIX + key, {"coins": int(amount)}) or moved
	if moved:
		services.store.write(player.to_dict())
	return moved


func _start_stage(stage: int) -> Dictionary:
	var found: Dictionary = levels.journey(stage, player.recent_categories())
	if not found["ok"]:
		return {"ok": false, "error": found["error"]}
	return _started(RoundMode.JOURNEY, stage, "", found["level"])


func _started(mode: String, stage: int, date: String, level: Dictionary) -> Dictionary:
	var board: Board = start_round.start(player, mode, stage, date, level)
	if board == null:
		return {"ok": false, "error": "cannot_start"}
	return {"ok": true, "board": board, "mode": mode, "stage": stage, "date": date, "seconds": 0, "resumed": false}


func _resumed() -> Dictionary:
	var run: Dictionary = player.run()
	var board: Board = start_round.resume(player)
	if board == null:
		return {"ok": false, "error": "cannot_resume"}
	return {"ok": true, "board": board, "mode": run["mode"], "stage": run["stage"], "date": run["date"],
		"seconds": run["seconds"], "resumed": true}


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
