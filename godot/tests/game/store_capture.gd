extends SceneTree
## Google Play 휴대전화 스크린숏의 원본 화면. 실제 시작 장면을 띄우고 화면 입력으로 여섯 상태를 만들어 3배 해상도로 찍는다.
## 문구와 배경은 tools/store/build_screenshots.py가 얹는다. 이 스크립트를 직접 돌리기보다 그 도구를 쓴다.
##
##   godot --audio-driver Dummy --fixed-fps 60 --path godot --script res://tests/game/store_capture.gd -- --out <폴더> --language en|ko
## 렌더링 모드(--headless 없이)에서만 PNG가 남는다. --fixed-fps는 연출의 시간을 프레임 수로 고정해 같은 커밋에서 같은 그림이 나오게 한다.
##
## 진행 기록은 손으로 쓴 저장 파일이 아니라 실제 유스케이스(FaSession의 판 시작과 FaFinishRound의 정산)로 판을 풀어 만든다:
## 12월 1일부터 9일까지 날마다 출석을 받고 일일 도전과 스테이지 몇 개를 푼 플레이어가 10일에 게임을 켠 상태다(스테이지 30).
## 대역은 광고(ScriptedAds), 시계(FakeClock), 저장 경로뿐이다. 진행 기록을 만든 뒤의 화면은 모두 탭으로 움직인다.

const Driver := preload("res://tests/common/e2e_driver.gd")
const Pilot := preload("res://tests/game/play_pilot.gd")
const State := preload("res://addons/seorilabs_game/flow/state.gd")
const GameServices := preload("res://game/bootstrap/fa_services.gd")
const Session := preload("res://game/bootstrap/fa_session.gd")
const ScriptedAds := preload("res://game/adapters/fa_scripted_ads.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Look := preload("res://game/features/shared/fa_look.gd")

## 게임의 논리 화면(9:16)과 그리는 배율. 휴대전화처럼 논리 크기는 그대로 두고 그리는 배율만 올린다.
const SCREEN := Vector2i(390, 693)
const FACTOR := 3
var _screen: Vector2i = SCREEN
const DAY_SECONDS := 86400
## 게임을 켠 날과 그 전까지 날마다 푼 스테이지 수(합 29: 튜토리얼 뒤 스테이지 1~29).
const TODAY := "2026-12-10"
const STAGES_PER_DAY: Array[int] = [5, 3, 4, 2, 3, 4, 3, 2, 3]
## 날마다의 일일 도전에 걸린 시간(초). 고정값이다.
const DAILY_SECONDS: Array[int] = [142, 96, 188, 121, 75, 163, 110, 134, 97]
## 꾸미기 장면에서 사는 테마.
const DECOR_CARD_BACK := "card_back_mint"
const DECOR_BACKGROUND := "background_peach"

var d: RefCounted
var pilot: Pilot
var ads: ScriptedAds
var clock: Pilot.FakeClock
var save_dir: String = ""
var main: Control
var language: String = "en"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "user://store-capture"
	language = args[args.find("--language") + 1] if args.has("--language") else "en"
	if args.has("--size"):
		var parts: PackedStringArray = args[args.find("--size") + 1].split("x")
		if parts.size() == 2:
			_screen = Vector2i(int(parts[0]), int(parts[1]))
	# 연출 입자처럼 전역 난수를 쓰는 곳도 실행마다 같게 한다.
	seed(20261210)
	d = Driver.new(self, _screen, out, true)
	pilot = Pilot.new(d)
	ads = ScriptedAds.new()
	clock = Pilot.FakeClock.new()
	save_dir = "user://store-capture-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(save_dir)

	d.begin("store-history-" + language, ["core_play", "daily_challenge", "album", "attendance"])
	var history: Dictionary = build_history(save_dir + "/progress.json")
	d.expect_equal("history reaches stage 30 with a nine-day daily streak", [history["stage"], history["streak"]], [30, 9])
	d.step("history collected album categories", history["album"] >= 40, str(history["album"]))
	d.end()

	d.begin("store-screens-" + language, ["title_home", "core_play", "daily_challenge", "album", "shop", "ui_navigation"])
	d.step("home", await open_home())
	await outgame_shots()
	await play_shots()
	await decor_shot()
	d.end()

	if main != null:
		await d.unmount(main)
	Look.select("", "")
	for file_name: String in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	quit(d.finish())


# =====================================================================
# 진행 기록: 실제 유스케이스로 판을 풀어 만든다
# =====================================================================

func set_day(index: int) -> void:
	clock.date = Daily.add_days(Daily.BASE_DATE, index)
	clock.now = 1796126400 + index * DAY_SECONDS


## 튜토리얼, 날마다의 출석과 일일 도전, 스테이지를 푼 저장을 만든다. 결과는 {stage, streak, album, coins}.
func build_history(progress_path: String) -> Dictionary:
	var services: GameServices = GameServices.local(progress_path)
	services.ads = ads
	services.clock = clock
	set_day(0)
	var session: Session = Session.open(services)
	play_round(session, session.open_round(true), 0)
	var stage_index: int = 0
	for day: int in STAGES_PER_DAY.size():
		set_day(day)
		session.attendance.claim(session.player, clock.date)
		var daily: Dictionary = session.open_daily(clock.date)
		play_round(session, daily, DAILY_SECONDS[day], day % 3 == 1)
		for count: int in STAGES_PER_DAY[day]:
			stage_index += 1
			# 몇 판은 한 번 틀려 별 둘로 끝낸다.
			play_round(session, session.open_round(false), 60 + stage_index * 7 % 90, stage_index % 4 == 2)
	set_day(Daily.days_between(Daily.BASE_DATE, TODAY))
	return {"stage": session.player.stage(), "streak": session.player.daily_streak(clock.date),
		"album": session.player.album_count(), "coins": session.player.coins()}


## 판을 끝까지 풀고 정산한다. miss가 참이면 처음에 오답을 한 번 낸다(열린 카드로 오답을 만들 수 있을 때).
func play_round(session: Session, round: Dictionary, seconds: int, miss: bool = false) -> void:
	if not round.get("ok", false):
		d.step("round opens: " + str(round.get("error", "")), false)
		return
	var board: Board = round["board"]
	if miss:
		var wrong: Array = wrong_cards(board)
		if not wrong.is_empty():
			board.submit(wrong)
	for move: int in 60:
		if board.is_won():
			break
		var group: Array = open_group(board)
		if not group.is_empty():
			board.submit(group)
			continue
		var column: int = Solver.solve_board(board, board.slot_count())["next_hold"]
		if column == -1:
			break
		board.hold(board.front_card(column))
	var settled: Dictionary = session.finish_round.execute(session.player, board, seconds)
	if not settled.get("ok", false):
		d.step("round settles: %s %s" % [round["mode"], settled.get("reason", "")], false)


func open_group(board: Board) -> Array:
	var groups: Dictionary = {}
	for entry: Dictionary in board.open_cards():
		var category: String = board.category_of(entry["card"])
		groups[category] = groups.get(category, []) + [entry["card"]]
	for category: String in groups:
		if groups[category].size() == Board.GROUP_SIZE:
			return groups[category]
	return []


## 같은 범주가 두 장 이하인 열린 카드 네 장. 없으면 빈 배열.
func wrong_cards(board: Board) -> Array:
	var open: Array = []
	for entry: Dictionary in board.open_cards():
		open.append(entry["card"])
	if open.size() < Board.GROUP_SIZE:
		return []
	for start: int in open.size() - 3:
		var cards: Array = open.slice(start, start + 4)
		var counts: Dictionary = {}
		for card: String in cards:
			counts[board.category_of(card)] = counts.get(board.category_of(card), 0) + 1
		if counts.values().max() <= 2:
			return cards
	return []


# =====================================================================
# 화면
# =====================================================================

func b(node_name: String) -> Control:
	return main.find_child(node_name, true, false) as Control


## 공통 저장(설정, 튜토리얼 완료)을 만들고 게임을 띄워 타이틀의 시작을 누른다.
func open_home() -> bool:
	var state := State.new(save_dir + "/state.json")
	state.load_state()
	var next: Dictionary = state.data.duplicate(true)
	next.consentVersion = 1
	next.settings.language = language
	next.settings.analytics = false
	next.tutorial = {"version": State.TUTORIAL_VERSION, "step": 2, "status": "complete", "hits": 3, "replay": false}
	state.commit(next)
	main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.state = State.new(save_dir + "/state.json")
	main.device_locale = "ko-KR" if language == "ko" else "en-US"
	var services: GameServices = GameServices.local(save_dir + "/progress.json")
	services.ads = ads
	services.clock = clock
	main.game_services = services
	main.safe_insets_override = Vector2.ZERO
	pilot.main = main
	await d.mount(main)
	if not await d.wait_for(func() -> bool: return main.start_ready()):
		return false
	return await d.tap(b("start")) and main.screen == "home"


## 논리 화면은 그대로 두고 3배로 그려 찍는다.
func shot(shot_name: String, settle: bool = true) -> void:
	d.viewport.size = _screen * FACTOR
	d.viewport.size_2d_override = _screen
	d.viewport.size_2d_override_stretch = true
	await d.shot(shot_name, settle)
	d.viewport.size_2d_override_stretch = false
	d.viewport.size_2d_override = Vector2i.ZERO
	d.viewport.size = _screen


## 4: 일일 도전(아흐레 연속 성공, 오늘의 판이 기다림). 5: 도감.
func outgame_shots() -> void:
	d.step("open daily", await d.tap(b("daily")) and main.screen == "daily")
	var done: Array = []
	for day: int in range(1, 10):
		done.append(b("day_2026-12-%02d" % day).get_meta("state"))
	d.expect_equal("the calendar shows nine done days and today open", [done.count("done"), b("day_" + TODAY).get_meta("state")], [9, "open"])
	d.expect_equal("the streak", b("streak_now").text, tr_text("9-day streak", "9일 연속"))
	await shot("04-daily")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.step("open album", await d.tap(b("album")) and main.screen == "album")
	d.step("the album count", b("album_count").text.contains("%d / %d" % [main.session.player.album_count(), main.session.catalog.category_ids().size()]), b("album_count").text)
	await shot("05-album")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")


## 3: 맨 앞 카드를 임시 칸으로 옮겨 뒤 카드가 열린 판. 1: 묶음 하나를 맞힌 뒤 같은 범주 네 장을 고른 판. 2: 그 네 장을 묶어 범주 이름이 드러난 판.
func play_shots() -> void:
	d.step("play stage 30", await d.tap(b("play")) and main.screen == "play" and await pilot.settle())
	d.expect_equal("stage 30 opens on the classic layout", [main.play.stage_number, pilot.board().meta()["layout"]], [30, "classic"])
	d.step("the board opens without a ready group", pilot.open_group().is_empty())
	var column: int = Solver.solve_board(pilot.board(), pilot.board().slot_count())["next_hold"]
	var hidden: int = pilot.board().hidden_count(column) if column != -1 else 0
	d.step("hold the front card the solver picks", column != -1 and await pilot.hold(pilot.board().front_card(column)))
	d.expect_equal("the card behind opened", pilot.board().hidden_count(column), hidden - 1)
	await shot("03-hold")
	d.step("solve the first group", await solve_next_group())
	d.step("reach the next group", await reach_group())
	var group: Array = pilot.open_group()
	for card: String in group:
		await pilot.tap_card(card)
	d.expect_equal("four alike are picked and Group is on", [main.play.selection.size(), main.play.submit_button.disabled, main.play.text_of("submit")], [4, false, tr_text("Group", "묶기")])
	await shot("01-group")
	var category: String = pilot.board().category_of(group[0])
	d.step("group them", await d.tap(main.play.submit_button) and await pilot.settle())
	d.expect_equal("the medal shows the category", [main.play.medal(1).category, main.play.medal(1).tag_text()], [category, main.session.catalog.category_name(category, language)])
	await shot("02-category")


## 열린 묶음이 생길 때까지 해법 탐색기가 고른 카드를 임시 칸으로 옮긴다.
func reach_group() -> bool:
	for move: int in 8:
		if not pilot.open_group().is_empty():
			return true
		if not await pilot.advance():
			return false
	return not pilot.open_group().is_empty()


func solve_next_group() -> bool:
	return await reach_group() and await pilot.submit(pilot.open_group()) and await pilot.settle()


## 6: 상점에서 카드 뒷면과 배경을 사서 바꾼 뒤의 홈.
func decor_shot() -> void:
	d.step("pause and go home", await d.tap(main.play.pause_button) and await pilot.popup_open("pause")
		and await pilot.tap_popup("home") and await pilot.tap_popup("confirm")
		and await d.wait_for(func() -> bool: return main.screen == "home", 600))
	d.step("open the shop", await d.tap(b("shop")) and main.screen == "shop")
	d.step("decor tab", await d.tap(b("tab_decor")))
	d.step("buy and use the card back", await d.tap(b("buy_" + DECOR_CARD_BACK))
		and await d.wait_for(func() -> bool: return main.outgame_popup != null and main.outgame_popup.state == "open", 600)
		and await d.tap(b("confirm_buy"))
		and await d.wait_for(func() -> bool: return main.outgame_popup == null, 300)
		and b("using_" + DECOR_CARD_BACK) != null)
	d.step("buy and use the background", await d.tap(b("buy_" + DECOR_BACKGROUND))
		and await d.wait_for(func() -> bool: return main.outgame_popup != null and main.outgame_popup.state == "open", 600)
		and await d.tap(b("confirm_buy"))
		and await d.wait_for(func() -> bool: return main.outgame_popup == null, 300)
		and main.backdrop.theme_id == DECOR_BACKGROUND)
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.step("the home shows the new card backs", b("next_backs").get_child(0)._back.texture == Look.back_plate(DECOR_CARD_BACK))
	# 코인 칩이 줄어드는 연출이 끝난 뒤에 찍는다.
	await d.frames(90)
	await shot("06-decor")


func tr_text(en: String, ko: String) -> String:
	return ko if language == "ko" else en
