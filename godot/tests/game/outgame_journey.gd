extends SceneTree
## 제품 여정. 실제 시작 장면을 띄우고 화면 좌표 입력만으로 진행한다.
## 대역은 광고와 동의(ScriptedAds), 시계(FakeClock), 분석 기록(FaMemoryAnalytics), 저장 경로, 그리고 OS 경계 셋(앱 끝내기,
## 바깥 주소 열기, 클립보드)뿐이다. 판의 상태는 읽어서 확인만 한다. 상점의 꾸미기를 사는 단계만 코인을 넣은 저장 파일(고정 자료)로 다시 띄운다.
## 단계 이름의 AC-번호는 GDD 인수 시나리오의 조건이다.

const Driver := preload("res://tests/common/e2e_driver.gd")
const Pilot := preload("res://tests/game/play_pilot.gd")
const State := preload("res://addons/seorilabs_game/flow/state.gd")
const GameServices := preload("res://game/bootstrap/fa_services.gd")
const SavePaths := preload("res://game/bootstrap/fa_save_paths.gd")
const ScriptedAds := preload("res://game/adapters/fa_scripted_ads.gd")
const MemoryAnalytics := preload("res://game/adapters/fa_memory_analytics.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const Look := preload("res://game/features/shared/fa_look.gd")
const Art := preload("res://game/features/shared/fa_art.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const FileStore := preload("res://game/adapters/fa_file_store.gd")
const AdmobAds := preload("res://game/adapters/fa_admob_ads.gd")
const AtomicStore := preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
const Licenses := preload("res://game/features/outgame/licenses_screen.gd")
const AlbumScreen := preload("res://game/features/outgame/album_screen.gd")

const SLOW := 1.0
## 같은 화면 흐름을 되풀이해 스테이지를 넘길 때만 시간을 빨리 돌린다.
const FAST := 3.0
## 전면 광고의 누적 플레이 조건(180초)을 채울 때의 배속.
const IDLE_SPEED := 30.0

var d: RefCounted
var pilot: Pilot
var ads: ScriptedAds
var clock: Pilot.FakeClock
var recorder: MemoryAnalytics
var save_dir: String = ""
var main: Control
## OS 경계의 대역: 앱 끝내기 횟수, 연 주소, 클립보드에 넣은 글.
var quits: int = 0
var opened_urls: Array[String] = []
var clipboard: Array[String] = []
## 스테이지 1 결과 창이 도감에 새로 담았다고 보인 범주.
var first_album: Array = []


func _initialize() -> void:
	call_deferred("run")


func arg(args: PackedStringArray, key: String, fallback: String) -> String:
	return args[args.find(key) + 1] if args.has(key) else fallback


func b(node_name: String) -> Control:
	return main.find_child(node_name, true, false) as Control


## 그림 판 버튼(FaUi.button)의 글자.
func label_of(control: Control) -> String:
	return str(control.get_meta("label", "")) if control != null else ""


## 바깥 화면의 팝업(출석, 도감 상세)이 다 열렸는지.
func outgame_popup_open() -> bool:
	return await d.wait_for(func() -> bool: return main.outgame_popup != null and main.outgame_popup.state == "open", 600)


func player() -> RefCounted:
	return main.session.player


func in_scroll(control: Control) -> bool:
	var node: Node = control.get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	return node != null


## 공통 화면의 버튼이 세로 화면 밖으로 나가거나 서로 겹치지 않는지 본다. 목록 안의 버튼은 스크롤로 닿으므로 제외한다.
func fits() -> String:
	var screen := Rect2(Vector2.ZERO, Vector2(d.viewport.size))
	var placed: Array[Control] = []
	for button: Control in main.content.find_children("*", "BaseButton", true, false):
		if not button.is_visible_in_tree() or in_scroll(button):
			continue
		var rect: Rect2 = button.get_global_rect()
		if not screen.encloses(rect):
			return "%s leaves the screen: %s" % [button.name, rect]
		for other: Control in placed:
			if other.get_global_rect().intersects(rect) and not other.is_ancestor_of(button):
				return "%s overlaps %s" % [button.name, other.name]
		placed.append(button)
	return "" if not placed.is_empty() else "no visible button"


func fit_step(label: String) -> void:
	var problem: String = fits()
	d.step(label + " fits the portrait screen", problem.is_empty(), problem)


## 바깥 화면 팝업의 창이 화면 안에 있고, 창 안의 버튼과 글이 창 밖으로 나가지 않고, 버튼끼리 겹치지 않는지 본다.
func popup_fits() -> String:
	var screen := Rect2(Vector2.ZERO, Vector2(d.viewport.size))
	var frame: Rect2 = (main.outgame_popup.get_node("Center/Frame") as Control).get_global_rect()
	if not screen.encloses(frame):
		return "the popup leaves the screen: %s" % frame
	var placed: Array[Control] = []
	for node: Node in main.outgame_popup.get_node("Center/Frame").find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or not (control is BaseButton or control is Label):
			continue
		var rect: Rect2 = control.get_global_rect()
		if not frame.encloses(rect):
			return "%s leaves the popup: %s" % [control.name, rect]
		if control is BaseButton:
			for other: Control in placed:
				if other.get_global_rect().intersects(rect):
					return "%s overlaps %s" % [control.name, other.name]
			placed.append(control)
	return ""


func popup_fit_step(label: String) -> void:
	var problem: String = popup_fits()
	d.step(label + " fits the screen", problem.is_empty(), problem)


func play_fit_step(label: String) -> void:
	var problem: String = pilot.fits()
	d.step(label + " fits the screen (AC-018)", problem.is_empty(), problem)


## 시작 장면을 격리 폴더의 저장 자리(FaSavePaths.under(save_dir, save_name))로 띄운다.
func mount_game(save_name: String, locale: String, wait_ready: bool = true) -> void:
	var paths: SavePaths = SavePaths.under(save_dir, save_name)
	main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.state = State.new(paths.state)
	main.device_locale = locale
	var services: GameServices = GameServices.local(paths.progress)
	services.ads = ads
	services.clock = clock
	services.analytics = recorder
	main.game_services = services
	_hook_os(main)
	pilot.main = main
	await d.mount(main)
	if wait_ready:
		d.step("actual startup completes", await d.wait_for(func() -> bool: return main.start_ready()))


func _hook_os(game: Control) -> void:
	game.quit_app = func() -> void: quits += 1
	game.open_url = func(url: String) -> void: opened_urls.append(url)
	game.clipboard_writer = func(text: String) -> bool:
		clipboard.append(text)
		return true


func restart_game(save_name: String, locale: String) -> void:
	await d.unmount(main)
	await mount_game(save_name, locale)


## 홈에서 플레이를 시작하고 배치 연출이 끝나길 기다린다.
func start_from_home() -> bool:
	return await d.tap(b("play")) and main.screen == "play" and await pilot.settle()


## 지금 판을 끝까지 풀고 결과 창에서 다음을 눌러 다음 스테이지로 간다. 판 끝에 전면 광고가 뜨면 닫는다.
func clear_and_next() -> bool:
	if not await pilot.clear_board():
		return false
	await d.wait_for(func() -> bool: return main.play.popup != null or ads.showing() == "interstitial", Pilot.SETTLE_FRAMES)
	if ads.showing() == "interstitial":
		ads.finish("dismissed")
	if not await pilot.popup_open("result"):
		return false
	return await pilot.tap_popup("next") and await pilot.popup_closed() and await pilot.settle()


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var size: PackedStringArray = arg(args, "--size", "390x844").split("x")
	d = Driver.new(self, Vector2i(int(size[0]), int(size[1])), arg(args, "--out", "user://e2e/game"), args.has("--capture"))
	pilot = Pilot.new(d)
	ads = ScriptedAds.new()
	clock = Pilot.FakeClock.new()
	recorder = MemoryAnalytics.new()
	save_dir = "user://e2e-game-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(save_dir)
	print("Isolated save: ", ProjectSettings.globalize_path(save_dir))

	await first_run()
	await wrong_answers()
	await hold_undo_drag()
	await resume_in_english()
	await result_double()
	await pause_restart_home()
	await interstitial_at_level_end()
	await stuck_extra_slot()
	await fail_continue()
	await dead_end_notice()
	await settings_support_focus()
	await replay_guide()
	await daily_challenge()
	await album_screen()
	await shop_and_decor()
	await attendance_checkin()
	await settings_privacy_licenses()
	await back_to_exit()
	await outgame_english()
	await data_reset()
	await title_error_retry()
	await live_services_offline()

	await d.unmount(main)
	var services_dir: String = SavePaths.under(save_dir, "").services
	for folder: String in [services_dir, save_dir]:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file_name: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file_name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	quit(d.finish({"sourceSha": OS.get_environment("GITHUB_SHA")}))


## (1) 첫 실행: 타이틀, 튜토리얼 세 단계, 시작 선물, 홈, 스테이지 1 클리어, 결과, 다음.
func first_run() -> void:
	d.begin("first-run-tutorial-stage-one", ["startup", "title_home", "tutorial", "core_play", "result_rewards", "account_save", "run_save",
		"inbox", "commerce", "operations", "observability", "ui_leaderboard", "ui_kit"])
	# 규제 지역처럼 동의 확인이 끝나지 않은 채로 시작한다(동의 창이 먼저 뜬 상태).
	ads.consent_done = false
	await mount_game("play", "ko-KR", false)
	d.step("SCR-001 the title waits at the privacy step", await d.wait_for(func() -> bool: return main.title_progress()["stage"] == "privacy"))
	d.expect_equal("SCR-001 consent state: no start button and the waiting text", [b("start").visible, b("status").text], [false, "개인정보 선택을 기다리는 중"])
	d.step("SCR-001 the bar shows the finished steps only", main.title_view.fill_ratio() < 1.0)
	await d.shot("title-consent")
	ads.settle_consent(false)
	d.step("SCR-001 the start button shows once consent is settled", await d.wait_for(func() -> bool: return main.start_ready()) and b("start").is_visible_in_tree())
	d.step("portrait flow on a portrait screen", not main.landscape and d.viewport.size.x < d.viewport.size.y)
	d.step("product skin theme is applied", main.skin_dir == "res://game/skins/candy_pop" and main.theme != null)
	d.expect_equal("SCR-001 title identity in Korean", [b("logo").text, b("subtitle").text, b("ribbon_label").text, label_of(b("start"))], ["끼리끼리", "연상 카드 퍼즐", "과일", "시작하기"])
	d.step("SCR-001 four fan cards", ["banana", "lemon", "grapes", "strawberry"].all(func(card: String) -> bool: return b("fan_" + card) != null))
	d.step("SCR-001 the bar is full when ready", await d.wait_for(func() -> bool: return is_equal_approx(main.title_view.fill_ratio(), 1.0)) and b("status").text == "준비 완료")
	d.expect_equal("SCR-001 version and studio", b("version").text, "v%s · %s" % [ProjectSettings.get_setting("application/config/version"), main.studio_name])
	d.expect_equal("title_ready is reported once", recorder.count("title_ready"), 1)
	fit_step("title")
	await d.frames(60)
	await d.shot("title")
	d.step("first start opens the tutorial board", await d.tap(b("start")) and main.screen == "play" and await pilot.settle())
	var play: Control = main.play
	d.expect_equal("tutorial board is the intro layout with three groups", [play.mode, pilot.board().meta()["layout"], pilot.board().categories().size()], ["tutorial", "intro", 3])
	d.expect_equal("tutorial has no boosters or coins yet", [player().coins(), player().booster("hint")], [0, 0])
	play_fit_step("tutorial board")
	await d.shot("tutorial-step-1")

	# 1단계: 강조된 네 장을 고르고 묶는다.
	var guide: Dictionary = main.session.tutorial["guide"]
	var first: Array = pilot.board().group_items(guide["order"][0])
	d.step("guide step 1 points at the first group", play.guide_step == "pick" and play.guide_targets().has(first[0]))
	var outside: String = pilot.board().front_card(1)
	d.step("guide ignores a card outside the step", await pilot.tap_card(outside) and play.selection.is_empty())
	for card: String in first:
		d.step("pick " + card, await pilot.tap_card(card) and play.selection.has(card))
	d.step("guide moves on to the group button", play.guide_step == "pick_submit")
	await d.shot("tutorial-step-1-selected")
	d.step("AC-001 group four alike", await d.tap(play.submit_button) and await pilot.settle())
	d.expect_equal("AC-001 the group is solved and its cards are gone", [pilot.board().solved(), pilot.board().reserve()], [[guide["order"][0]], ["", "", "", ""]])
	d.step("AC-001 the category medal is filled", play.medal(0).category == guide["order"][0])
	d.expect_equal("tutorial action 1 of 3 recorded", main.state.data.tutorial.hits, 1)

	# 2단계: 맨 앞 카드를 임시 칸으로 옮겨 숨은 카드를 연다.
	var hidden_before: int = pilot.board().hidden_count(0)
	d.step("guide step 2 points at the card to hold", play.guide_step == "hold_card" and play.guide_targets() == [guide["hold"]])
	await d.shot("tutorial-step-2")
	d.step("select the front card", await pilot.tap_card(guide["hold"]) and play.guide_step == "hold_cell")
	d.step("AC-004 move it to the holding slot", await d.tap(play.hold_cell(0)) and await pilot.settle())
	d.expect_equal("AC-004 the card is held and the next card opened", [pilot.board().holds()[0], pilot.board().hidden_count(0)], [guide["hold"], hidden_before - 1])
	d.step("AC-004 the opened card is face up", play.card_view(pilot.board().front_card(0)) != null and not play.card_view(pilot.board().front_card(0)).face_down)
	d.step("second group", await pilot.submit(pilot.board().group_items(guide["order"][1])))
	d.expect_equal("tutorial action 2 of 3 recorded", main.state.data.tutorial.hits, 2)

	# 3단계: 남은 네 장을 스스로 묶는다.
	d.step("guide step 3 leaves the last four to the player", play.guide_step == "last")
	await d.shot("tutorial-step-3")
	d.step("last group", await pilot.submit(pilot.board().group_items(guide["order"][2])))
	d.step("tutorial end card with the starter gift", await pilot.popup_open("tutorial_done"))
	d.expect_equal("AC-015 starter gift granted once", [player().coins() >= 200, player().booster("hint"), player().booster("undo"), player().booster("slot")], [true, 3, 3, 2])
	d.expect_equal("AC-016 no ad is requested in the tutorial", ads.shown, [])
	await d.shot("tutorial-done")
	var gifted: int = player().coins()
	d.step("claim the gift", await pilot.tap_popup("claim") and await d.wait_for(func() -> bool: return main.screen == "home", 600))
	d.expect_equal("AC-015 tutorial is complete", main.state.data.tutorial.status, "complete")
	d.step("reward ceremony impact", await d.wait_for(func() -> bool: return main.ceremony.phase == "impact", 600))
	await d.shot("reward-impact", false)
	d.step("reward ceremony settle", await d.wait_for(func() -> bool: return main.ceremony.phase == "settle", 600))
	await d.shot("reward-settle", false)
	d.step("reward ceremony finished", await d.wait_for(func() -> bool: return main.ceremony.phase == "done", 900))
	d.step("the ceremony and its dim are gone", await d.wait_for(func() -> bool: return not main.ceremony.visible and b("reward_dim") == null, 300))

	# 홈: 스테이지 카드와 시작 버튼, 일일 도전, 아래 줄.
	var home: Control = main.home_view
	d.step("SCR-002 home shows the next stage", home != null and home.stage_number == 1 and b("stage_title").text == "스테이지 1")
	d.step("home coin chip shows the product coins", b("coins") != null and b("coins").value == gifted)
	d.expect_equal("SCR-002 primary action names the stage", label_of(b("play")), "스테이지 1 시작")
	d.step("SCR-002 daily card and the album, shop, check-in buttons", b("daily") != null and b("album") != null and b("shop") != null and b("attendance") != null)
	d.step("ranking stays hidden", b("leaderboard") == null)
	d.step("SCR-002 today's daily is not done (red dot)", b("daily_dot") != null and b("daily_tick") == null)
	d.step("SCR-002 check-in has something to claim and pulses", home.pulsing.has("attendance"))
	d.step("SCR-002 the inbox shows a badge", b("inbox").find_child("badge", true, false) != null)
	d.step("home play action is the primary skin", b("play").theme_type_variation == &"PrimaryButton")
	fit_step("home")
	await d.shot("home")
	d.step("open inbox", await d.tap(b("inbox")) and main.screen == "inbox")
	await d.shot("popup-open", false)
	var welcome: Control = b("mail_local-welcome")
	d.expect_equal("SCR-015 the welcome message is the product's", welcome.find_child("title", true, false).text, "끼리끼리에 오신 걸 환영해요!")
	await d.shot("inbox")
	var before_mail: int = player().coins()
	d.step("claim the welcome coins", await d.tap(welcome.find_child("claim", true, false)) and player().coins() == before_mail + 5)
	d.step("the message shows it was received", b("mail_local-welcome").find_child("claimed", true, false) != null)
	d.step("close to home", await d.tap(b("close")) and main.screen == "home")
	d.step("the inbox badge is gone", b("inbox").find_child("badge", true, false) == null)
	gifted = player().coins()

	# 스테이지 1: 쉬운 판을 끝까지 풀고 결과를 본다.
	d.step("start stage 1", await start_from_home())
	play = main.play
	d.expect_equal("stage 1 is a journey board", [play.mode, play.stage_number, pilot.board().categories().size()], ["journey", 1, 4])
	play_fit_step("stage 1")
	await d.shot("stage-1")
	d.step("clear stage 1", await pilot.clear_board())
	d.step("AC-006 result popup", await pilot.popup_open("result"))
	d.expect_equal("AC-006 three stars for no mistakes and the next stage opens", [play.result["stars"], player().stage(), player().best_stars(1)], [3, 2, 3])
	d.expect_equal("AC-006 stage coins match the stars", play.result["coins"], Economy.stage_reward(3))
	d.expect_equal("AC-016 no interstitial in the first session", ads.shown.count("interstitial"), 0)
	first_album = play.result["album"]["new"]
	d.step("SCR-007 the result names the new album categories", not first_album.is_empty() and play.popup.find_child("album_new", true, false) != null)
	d.step("AC-017 the double button is offered while a rewarded ad is ready", play.popup_button("double") != null and play.popup_button("double").visible)
	await d.wait_for(func() -> bool: return play.result_settled, 900)
	await d.shot("result")
	d.step("next stage", await pilot.tap_popup("next") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("stage 2 board", [main.play.stage_number, pilot.board().mistakes(), pilot.board().solved().size()], [2, 0, 0])
	d.expect_equal("analytics saw the round", [recorder.count("tutorial_complete"), recorder.count("level_start") >= 2, recorder.count("group_complete") >= 4], [1, true, true])
	d.end()


## (2) 오답: 한 장 차이 안내, 같은 조합 다시 내기, 그냥 오답.
func wrong_answers() -> void:
	d.begin("wrong-answers", ["core_play"])
	var play: Control = main.play
	var one_away: Array = pilot.wrong_pick(3)
	d.step("an almost-right pick exists on this board", one_away.size() == 4)
	var before: Dictionary = pilot.board().to_dict()
	d.step("submit three alike and one other", await pilot.submit(one_away))
	d.expect_equal("AC-002 one mistake", pilot.board().mistakes(), 1)
	d.expect_equal("AC-002 one-away toast", play.toasts.back(), "한 장만 달라요!")
	d.expect_equal("AC-002 cards stay where they were", [pilot.board().to_dict()["cols"], pilot.board().to_dict()["reserve"]], [before["cols"], before["reserve"]])
	d.step("AC-002 the selection is cleared and a heart is lost", play.selection.is_empty() and play.hearts_left() == 3)
	await d.shot("one-away", false)
	d.step("submit the same four again", await pilot.submit(one_away))
	d.expect_equal("AC-003 no extra mistake", pilot.board().mistakes(), 1)
	d.expect_equal("AC-003 already-tried toast", play.toasts.back(), "이미 해 본 조합이에요")
	var miss: Array = pilot.wrong_pick(2)
	d.step("submit two and two", miss.size() == 4 and await pilot.submit(miss))
	d.expect_equal("plain miss costs a mistake without the one-away toast", [pilot.board().mistakes(), play.toasts.back()], [2, "이미 해 본 조합이에요"])
	d.expect_equal("mistake sounds and haptics were requested", [main.audio.play_count("one_away"), main.audio.play_count("miss"), main.audio.haptics.count(15) >= 2], [1, 1, true])
	# 다섯 번째 선택은 무시된다.
	var open: Array = pilot.board().open_cards()
	for index: int in 5:
		await pilot.tap_card(open[index]["card"])
	d.expect_equal("a fifth pick is ignored", play.selection.size(), 4)
	for card: String in play.selection.duplicate():
		await pilot.tap_card(card)
	d.step("tapping again deselects", play.selection.is_empty())
	d.end()


## (3) 임시 칸: 옮기기, 옮길 수 없는 카드, 되돌리기, 끌어서 옮기기, 칸 추가.
func hold_undo_drag() -> void:
	d.begin("hold-undo-drag", ["core_play", "boosters"])
	var play: Control = main.play
	var card: String = pilot.board().front_card(0)
	var hidden: int = pilot.board().hidden_count(0)
	d.step("AC-004 hold the front card of column 1", await pilot.hold(card))
	d.expect_equal("AC-004 held and the next card opened", [pilot.board().holds()[0], pilot.board().hidden_count(0)], [card, hidden - 1])
	await d.shot("card-held")
	var reserve_card: String = ""
	for candidate: String in pilot.board().reserve():
		if not candidate.is_empty():
			reserve_card = candidate
			break
	d.step("AC-005 a reserve card can be selected", await pilot.tap_card(reserve_card) and play.selection == [reserve_card])
	d.step("AC-005 but it does not move to a slot", await d.tap(play.hold_cell(1)) and await pilot.settle() and pilot.board().holds()[1] == "" and pilot.board().reserve().has(reserve_card))
	d.step("AC-005 a held card can be selected too", await pilot.tap_card(reserve_card) and await pilot.tap_card(card) and play.selection == [card])
	# 화면 크기가 바뀌어도(분할 화면, 접는 화면) 판은 새 크기에 맞게 다시 놓이고 선택은 남는다.
	var screen: Vector2i = d.viewport.size
	d.viewport.size = screen + Vector2i(0, 80)
	await d.frames(4)
	d.step("the selection survives a taller screen", play.selection == [card] and play.card_view(card).selected)
	play_fit_step("board on the taller screen")
	d.viewport.size = screen
	await d.frames(4)
	d.step("and the screen going back", play.selection == [card] and play.card_view(card).selected)
	play_fit_step("board back on the first screen")
	d.step("deselect", await pilot.tap_card(card) and play.selection.is_empty())

	var undo_before: int = player().booster("undo")
	d.step("undo button shows the owned count", play.undo_button.count == undo_before and play.undo_button.state == "ready")
	d.step("AC-009 undo", await d.tap(play.undo_button) and await pilot.settle())
	d.expect_equal("AC-009 the card is back and the opened card is hidden again", [pilot.board().front_card(0), pilot.board().hidden_count(0), pilot.board().holds()[0]], [card, hidden, ""])
	d.expect_equal("AC-009 one undo spent", player().booster("undo"), undo_before - 1)
	d.step("nothing left to undo", play.undo_button.state == "idle")

	var from: Vector2 = play.card_view(card).get_global_rect().get_center()
	var to: Vector2 = play.hold_cell(0).get_global_rect().get_center()
	await d.drag(from, to, 8)
	d.step("drag the front card onto a slot", await pilot.settle() and pilot.board().holds()[0] == card)
	var reserve_view: Control = play.card_view(reserve_card)
	await d.drag(reserve_view.get_global_rect().get_center(), play.hold_cell(1).get_global_rect().get_center(), 8)
	d.step("AC-005 dragging a reserve card does not move it", await pilot.settle() and pilot.board().holds()[1] == "")
	if play.selection.has(reserve_card):
		await pilot.tap_card(reserve_card)

	# 칸 추가: 보유분이 있으면 잠긴 칸을 누르는 것으로 바로 연다.
	d.step("the third slot is locked", pilot.board().slot_count() == 2 and play.hold_cell(2).state == "locked")
	d.step("AC-010 open the third slot with an owned booster", await d.tap(play.hold_cell(2)) and await pilot.settle())
	d.expect_equal("AC-010 three slots and one booster left", [pilot.board().slot_count(), player().booster("slot"), play.hold_cell(2).state], [3, 1, "empty"])
	await d.shot("slot-opened")
	d.step("clear stage 2", await clear_and_next())
	d.expect_equal("two stars after two mistakes", player().best_stars(2), 2)
	d.expect_equal("AC-010 the next stage starts with the slot locked again", [main.play.stage_number, pilot.board().slot_count(), main.play.hold_cell(2).state], [3, 2, "locked"])
	d.end()


## (7)(9) 판 도중 종료 뒤 재실행: 같은 상태로 돌아오고, 설정에서 영어로 바꿔 같은 판을 잇는다.
func resume_in_english() -> void:
	d.begin("resume-in-english", ["run_save", "account_save", "core_play", "boosters", "ui_locale_offline", "settings_support"])
	var play: Control = main.play
	d.step("a mistake", await pilot.submit(pilot.wrong_pick(2)))
	d.step("a held card", await pilot.hold(pilot.board().front_card(1)))
	var group: Array = pilot.open_group()
	if not group.is_empty():
		d.step("a solved group", await pilot.submit(group))
	var hint_before: int = player().booster("hint")
	d.step("AC-011 hint", await d.tap(play.hint_button) and await pilot.settle())
	d.expect_equal("AC-011 one hint spent", player().booster("hint"), hint_before - 1)
	var hinted: Array = play.hinted_cards()
	d.step("AC-011 two open cards of one category are highlighted", hinted.size() == 2 and pilot.board().category_of(hinted[0]) == pilot.board().category_of(hinted[1]) and play.card_view(hinted[0]).hinted)
	await d.shot("hint")
	var saved_board: Dictionary = pilot.board().to_dict()
	var saved_boosters: Array = [player().booster("hint"), player().booster("undo"), player().booster("slot"), player().coins()]
	var korean_name: String = play.card_view(pilot.board().open_cards()[0]["card"]).name_label.text

	await restart_game("play", "ko-KR")
	d.step("restart goes to the home screen", await d.tap(b("start")) and main.screen == "home")
	d.expect_equal("AC-015 the starter gift is not granted again", [player().booster("hint"), player().booster("undo"), player().booster("slot"), player().coins()], saved_boosters)
	d.expect_equal("home offers to continue the round", label_of(b("play")), "이어 하기")
	d.step("settings", await d.tap(b("settings")) and main.screen == "settings")
	d.step("language", await d.tap(b("language")))
	d.step("English selection", await d.tap(b("en")) and main.language() == "en")
	d.step("close settings to home", await d.tap(b("close")) and main.screen == "home")
	d.expect_equal("AC-018 home action is in English", label_of(b("play")), "Continue")
	d.step("continue the round", await start_from_home())
	play = main.play
	d.expect_equal("AC-012 the board is exactly as it was", pilot.board().to_dict(), saved_board)
	d.expect_equal("AC-012 boosters and coins are as they were", [player().booster("hint"), player().booster("undo"), player().booster("slot"), player().coins()], saved_boosters)
	d.step("AC-012 the solved medal and lost heart are shown again", play.hearts_left() == 4 - pilot.board().mistakes() and (pilot.board().solved().is_empty() or play.medal(0).category == pilot.board().solved()[0]))
	var first_open: String = pilot.board().open_cards()[0]["card"]
	d.expect_equal("AC-018 card names follow the language", [play.card_view(first_open).name_label.text, korean_name != main.session.catalog.item_name(first_open, "en")], [main.session.catalog.item_name(first_open, "en"), true])
	d.expect_equal("AC-018 play labels are in English", [play.text_of("submit"), play.text_of("hint"), play.text_of("undo"), play.text_of("hold_label"), play.text_of("reserve_label")], ["Group", "Hint", "Undo", "HOLDING", "RESERVE"])
	play_fit_step("English board")
	await d.shot("english-board")
	d.end()


## (6) 결과 2배: 보상형 광고를 끝까지 보면 그 판의 코인을 한 번 더 받는다.
func result_double() -> void:
	d.begin("result-double", ["result_rewards", "ad_placements", "boosters"])
	var play: Control = main.play
	d.step("open the third slot with the last owned booster", await d.tap(play.hold_cell(2)) and await pilot.settle() and player().booster("slot") == 0)
	d.step("clear stage 3", await pilot.clear_board() and await pilot.popup_open("result"))
	d.expect_equal("AC-016 no interstitial before three minutes of play", ads.shown.count("interstitial"), 0)
	await d.wait_for(func() -> bool: return play.result_settled, 900)
	var coins: int = player().coins()
	var bonus: int = play.result["bonus"]["coins"]
	d.step("the double button names the ad and the reward", play.popup_button("double").visible and play.text_of("double") == "Watch ad to double")
	d.step("AC-017 watch the ad", await pilot.tap_popup("double") and ads.showing() == "rewarded")
	d.expect_equal("AC-017 nothing is paid while the ad is up", player().coins(), coins)
	d.step("the screen is locked while the ad is up", play.ad_showing and not play.idle())
	ads.finish("earned")
	d.step("AC-017 the bonus is paid after the ad", await d.wait_for(func() -> bool: return player().coins() == coins + bonus, 600))
	d.step("the double button is gone", await d.wait_for(func() -> bool: return not play.popup_button("double").visible, 600))
	await d.shot("result-doubled")
	d.step("next stage", await pilot.tap_popup("next") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("stage 4 board", main.play.stage_number, 4)
	d.end()


## (8) 일시정지: 계속, 다시 하기, 홈으로.
func pause_restart_home() -> void:
	d.begin("pause-restart-home", ["core_play", "ui_navigation", "run_save"])
	var play: Control = main.play
	d.step("a mistake to lose on restart", await pilot.submit(pilot.wrong_pick(2)) and pilot.board().mistakes() == 1)
	d.step("pause", await d.tap(play.pause_button) and await pilot.popup_open("pause"))
	await d.shot("pause")
	d.step("resume", await pilot.tap_popup("resume") and await pilot.popup_closed() and play.idle())
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("the back key opens pause", await pilot.popup_open("pause"))
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("the back key closes it again", await pilot.popup_closed())
	d.step("pause again", await d.tap(play.pause_button) and await pilot.popup_open("pause"))
	d.step("restart asks first", await pilot.tap_popup("restart") and play.popup_button("confirm") != null and pilot.board().mistakes() == 1)
	await d.shot("pause-confirm")
	d.step("confirm restart", await pilot.tap_popup("confirm") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("the same stage starts over", [main.play.stage_number, pilot.board().mistakes(), pilot.board().solved().size(), play.hearts_left()], [4, 0, 0, 4])
	d.step("pause", await d.tap(play.pause_button) and await pilot.popup_open("pause"))
	d.step("home asks first", await pilot.tap_popup("home") and play.popup_button("confirm") != null)
	d.step("confirm home", await pilot.tap_popup("confirm") and await d.wait_for(func() -> bool: return main.screen == "home" and main.play == null, 600))
	d.expect_equal("the round is dropped and the stage is kept", [player().has_run(), player().stage(), label_of(b("play"))], [false, 4, "Play Stage 4"])
	fit_step("English home")
	d.step("start stage 4 again", await start_from_home())
	d.end()


## 전면 광고: 두 번째 실행, 누적 플레이 3분, 직전 전면 뒤 2판, 보상형 뒤 2분을 모두 채운 판 종료에서만 요청한다.
func interstitial_at_level_end() -> void:
	d.begin("interstitial-at-level-end", ["ad_placements", "result_rewards", "core_play"])
	Engine.time_scale = FAST
	d.step("clear stage 4", await clear_and_next())
	d.expect_equal("AC-016 still no interstitial right after a rewarded ad and under three minutes", ads.shown.count("interstitial"), 0)
	# 판 앞에서 3분을 보낸다(배속). 시계 대역도 보상형 광고 뒤 2분이 지나게 돌린다.
	Engine.time_scale = IDLE_SPEED
	d.step("three minutes at the board", await d.wait_for(func() -> bool: return main.play.seconds >= 185.0, 4000))
	Engine.time_scale = FAST
	clock.now += 600
	var play: Control = main.play
	d.step("clear stage 5", await pilot.clear_board())
	d.step("AC-016 the interstitial is requested when the round ends", await d.wait_for(func() -> bool: return ads.showing() == "interstitial", 900))
	d.step("AC-016 it comes before the result popup", play.popup == null and play.ad_showing)
	Engine.time_scale = SLOW
	ads.finish("dismissed")
	d.step("the result popup follows the ad", await pilot.popup_open("result"))
	d.expect_equal("the impression is recorded", [recorder.count("ad_impression") >= 2, player().ads()["rounds_since_interstitial"]], [true, 0])
	d.step("AC-016 the double button is not offered right after it was used this session", not play.popup_button("double").visible)
	d.step("next stage", await pilot.tap_popup("next") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("AC-016 nothing is requested after pressing next", [main.play.stage_number, ads.showing(), ads.shown.count("interstitial")], [6, "", 1])
	d.end()


## (4) 막힘: 임시 칸이 가득 차 둘 수 없으면 가능한 선택만 보이고, 광고로 칸을 하나 더 연다. 닫고 살펴볼 수도 있다.
func stuck_extra_slot() -> void:
	d.begin("stuck-extra-slot", ["boosters", "ad_placements", "core_play"])
	var play: Control = main.play
	d.expect_equal("stage 6 is a harder layout", pilot.board().meta()["layout"], "step")
	play_fit_step("two reserve rows")
	await d.shot("stage-6")
	var path: Array = pilot.stuck_holds()
	d.step("a way to get stuck exists on this board", path.size() == 2)
	for card: String in path:
		d.step("hold " + card, await pilot.hold(card))
	d.step("AC-008 stuck popup", await pilot.popup_open("stuck"))
	d.expect_equal("AC-008 only the possible choices are shown", [play.popup_button("undo").visible, play.popup_button("slot").visible, play.popup_button("restart").visible], [true, true, true])
	d.expect_equal("the slot button names the ad and the reward", play.text_of("slot"), "Watch ad for +1 slot")
	d.expect_equal("stuck is reported", recorder.count("stuck_shown"), 1)
	await d.shot("stuck")
	d.step("watch the ad for a slot", await pilot.tap_popup("slot") and ads.showing() == "rewarded")
	ads.finish("earned")
	d.step("AC-010 the third slot opens", await pilot.popup_closed() and await pilot.settle() and pilot.board().slot_count() == 3)
	d.expect_equal("the booster came from the ad", [recorder.last("booster_used")["booster"], recorder.last("booster_used")["source"], player().booster("slot")], ["slot", "ad", 0])

	# 세 번째 칸도 채워 다시 막히면 칸 추가는 더 보이지 않는다. 닫고 판을 살펴본 뒤 되돌린다.
	var third: Array = pilot.stuck_holds()
	if third.size() == 1:
		d.step("fill the third slot", await pilot.tap_card(third[0]) and await d.tap(play.hold_cell(2)) and await pilot.popup_open("stuck"))
		d.expect_equal("AC-008 no slot choice once it is open", [play.popup_button("undo").visible, play.popup_button("slot").visible], [true, false])
		d.step("close to look at the board", await d.tap(play.popup_close()) and await pilot.popup_closed())
		d.step("the tray asks for attention while stuck", play.stuck_idle and play.idle())
		await d.shot("stuck-closed")
		d.step("AC-009 undo from the board", await d.tap(play.undo_button) and await pilot.settle() and pilot.board().holds()[2] == "" and not play.stuck_idle)
	else:
		d.step("with three slots this board always has a move", third.is_empty())

	d.step("pause to restart the stage", await d.tap(play.pause_button) and await pilot.popup_open("pause"))
	d.step("restart", await pilot.tap_popup("restart") and await pilot.tap_popup("confirm") and await pilot.popup_closed() and await pilot.settle())
	d.end()


## (5) 실패와 이어하기: 광고, 중도 닫기, 코인, 코인 부족.
func fail_continue() -> void:
	d.begin("fail-continue", ["core_play", "ad_placements", "boosters", "result_rewards"])
	var play: Control = main.play
	clock.now += 600

	# 보상형을 보다가 닫으면 받지 못하고, 코인으로 사는 길이 남는다(부스터 얻기 창).
	d.step("the locked slot offers an ad once the ad interval has passed", player().booster("slot") == 0 and await d.wait_for(func() -> bool: return play.hold_cell(2).tag == "ad", 600))
	d.step("booster popup", await d.tap(play.hold_cell(2)) and await pilot.popup_open("booster"))
	d.expect_equal("two equal choices", [play.popup_button("buy").size.y == play.popup_button("watch").size.y, play.text_of("watch")], [true, "Watch ad for +1 slot"])
	await d.shot("booster-popup")
	var coins: int = player().coins()
	d.step("watch", await pilot.tap_popup("watch") and ads.showing() == "rewarded")
	ads.finish("dismissed")
	d.step("AC-017 closing the ad early gives nothing", await d.wait_for(func() -> bool: return not play.ad_showing, 300) and pilot.board().slot_count() == 2 and player().booster("slot") == 0)
	d.step("AC-017 the coin choice remains", play.popup != null and play.popup_button("buy").visible and not play.popup_button("buy").disabled)
	d.step("buy with coins", await pilot.tap_popup("buy") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("the slot is bought and opened", [pilot.board().slot_count(), player().coins()], [3, coins - Economy.price("slot")])

	# 실수 네 번: 실패 창에 남은 묶음의 정답이 보이고, 광고로 이어 간다.
	clock.now += 600
	for index: int in 4:
		d.step("mistake %d" % (index + 1), await pilot.submit(pilot.wrong_pick(2, index)))
	d.step("AC-007 fail popup", await pilot.popup_open("fail") and pilot.board().is_failed())
	d.expect_equal("AC-007 every remaining group is revealed with its name", play.revealed_groups(), pilot.board().categories().filter(func(category: String) -> bool: return not pilot.board().solved().has(category)))
	d.expect_equal("AC-007 the continue button offers the ad", [play.popup_button("continue").visible, play.popup_button("continue").get_meta("way"), play.text_of("continue")], [true, "ad", "Watch ad to continue (clears 2)"])
	d.expect_equal("three equal buttons", [play.popup_button("continue").size.y == play.popup_button("restart").size.y, play.popup_button("restart").size.y == play.popup_button("home").size.y], [true, true])
	await d.shot("fail")
	d.step("watch the ad to continue", await pilot.tap_popup("continue") and ads.showing() == "rewarded")
	ads.finish("earned")
	d.step("AC-007 two mistakes are cleared and play goes on", await pilot.popup_closed() and await pilot.settle() and pilot.board().mistakes() == 2 and play.hearts_left() == 2)
	for index: int in 2:
		d.step("mistake again %d" % (index + 1), await pilot.submit(pilot.wrong_pick(2, 4 + index)))
	d.step("second fail popup", await pilot.popup_open("fail"))
	d.step("AC-007 no continue the second time", not play.popup_button("continue").visible)
	d.step("restart", await pilot.tap_popup("restart") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("a fresh board of the same stage", [main.play.stage_number, pilot.board().mistakes(), pilot.board().continue_used()], [6, 0, false])

	# 광고를 쓸 수 없으면 같은 자리에서 코인 150으로 이어 간다(DEC-022).
	ads.ready["rewarded"] = false
	for index: int in 4:
		d.step("mistake without ads %d" % (index + 1), await pilot.submit(pilot.wrong_pick(2, index)))
	d.step("fail popup without ads", await pilot.popup_open("fail"))
	coins = player().coins()
	d.expect_equal("AC-007 the continue button asks for coins", [play.popup_button("continue").get_meta("way"), play.text_of("continue"), coins >= Economy.price("continue")], ["coins", "Continue for 150 coins", true])
	await d.shot("fail-coins")
	d.step("continue for coins", await pilot.tap_popup("continue") and await pilot.popup_closed() and await pilot.settle())
	d.expect_equal("AC-007 coins are spent and two mistakes cleared", [player().coins(), pilot.board().mistakes()], [coins - Economy.price("continue"), 2])

	# 코인이 모자라면 가격이 빨간 비활성 모양이고 누르면 모자란 수를 알린다. 코인을 써서 그 상태를 만든다.
	d.step("pause to restart", await d.tap(play.pause_button) and await pilot.popup_open("pause"))
	d.step("restart", await pilot.tap_popup("restart") and await pilot.tap_popup("confirm") and await pilot.popup_closed() and await pilot.settle())
	var guard: int = 0
	while player().coins() >= Economy.price("continue") and guard < 8:
		guard += 1
		d.step("spend coins on a slot %d" % guard, await d.tap(play.hold_cell(2)) and await pilot.popup_open("booster") and await pilot.tap_popup("buy") and await pilot.popup_closed() and await pilot.settle())
		if player().coins() >= Economy.price("continue"):
			d.step("restart to lock the slot again %d" % guard, await d.tap(play.pause_button) and await pilot.popup_open("pause") and await pilot.tap_popup("restart") and await pilot.tap_popup("confirm") and await pilot.popup_closed() and await pilot.settle())
	d.step("coins are now under the continue price", player().coins() < Economy.price("continue"))
	for index: int in 4:
		d.step("mistake when poor %d" % (index + 1), await pilot.submit(pilot.wrong_pick(2, index)))
	d.step("fail popup when poor", await pilot.popup_open("fail"))
	coins = player().coins()
	d.expect_equal("AC-007 the coin button is shown as unaffordable", [play.popup_button("continue").visible, play.popup_button("continue").get_meta("way"), play.popup_button("continue").get_meta("unaffordable", false)], [true, "short", true])
	await d.shot("fail-short")
	d.step("tapping it only tells the shortage", await pilot.tap_popup("continue") and play.popup != null and pilot.board().is_failed() and player().coins() == coins)
	d.expect_equal("shortage toast", play.toasts.back(), "%d more coins needed" % (Economy.price("continue") - coins))
	d.step("home from the fail popup", await pilot.tap_popup("home") and await d.wait_for(func() -> bool: return main.screen == "home" and main.play == null, 600))
	d.expect_equal("the failed round is dropped", player().has_run(), false)
	ads.ready["rewarded"] = true
	d.end()


## 막힌 길 안내(DEC-008): 둘 수는 있지만 지금 칸 수로는 풀 수 없게 되면 판을 멈추지 않고 알리고 되돌리기를 강조한다.
## 그런 수가 있는 판이 나올 때까지 스테이지를 넘긴다.
func dead_end_notice() -> void:
	d.begin("dead-end-notice", ["core_play", "boosters"])
	d.step("start from home", await start_from_home())
	Engine.time_scale = FAST
	clock.now += 600
	var skipped: int = 0
	while pilot.dead_end_holds().is_empty() and skipped < 8:
		skipped += 1
		d.step("clear stage %d on the way" % main.play.stage_number, await clear_and_next())
	Engine.time_scale = SLOW
	var play: Control = main.play
	var dead: Array = pilot.dead_end_holds()
	d.step("a board with a move that leaves no solution was reached", not dead.is_empty())
	var toasts_before: int = play.toasts.size()
	for card: String in dead:
		d.step("hold " + card, await pilot.hold(card) and play.idle())
	d.expect_equal("the dead end is told once without stopping the board", [play.dead_end, play.toasts.back(), play.toasts.size() - toasts_before, recorder.count("dead_end_shown")], [true, "No way through from here", 1, 1])
	d.step("undo asks for attention and the stuck sound played", play.undo_button.highlighted() and main.audio.play_count("stuck") >= 1)
	await d.shot("dead-end")
	d.step("undo clears the dead end", await d.tap(play.undo_button) and await pilot.settle() and not play.dead_end and not play.undo_button.highlighted())
	d.step("pause", await d.tap(play.pause_button) and await pilot.popup_open("pause"))
	d.step("home", await pilot.tap_popup("home") and await pilot.tap_popup("confirm") and await d.wait_for(func() -> bool: return main.screen == "home" and main.play == null, 600))
	d.end()


## 공통 설정: 분석 끄기, 지원코드, 언어, 큰 글자, 키보드 초점, 재실행 뒤 유지.
func settings_support_focus() -> void:
	d.begin("settings-language-support-focus", ["settings_support", "account_save", "ui_support_entry", "ui_analytics_opt_out", "ui_locale_offline", "ui_navigation"])
	d.step("settings", await d.tap(b("settings")))
	d.step("turn analytics off", await d.tap(b("analytics")) and not main.state.data.settings.analytics and not main.analytics.effective)
	await d.shot("settings")
	d.step("support is directly reachable", await d.tap(b("support")) and main.screen == "support")
	d.step("local support unavailable without invented identity", main.support.code.is_empty() and b("copy").disabled)
	await d.shot("support")
	d.step("back restores settings", await d.tap(b("back")) and main.screen == "settings")
	d.step("language", await d.tap(b("language")))
	d.step("Korean selection", await d.tap(b("ko")) and main.language() == "ko")
	await d.shot("korean")
	d.step("settings return", await d.tap(b("back")))
	d.step("accessibility", await d.tap(b("accessibility")))
	d.step("larger text", await d.tap(b("large_text")) and main.state.data.settings.large_text)
	await d.shot("large-text")
	d.step("back to settings", await d.tap(b("back")))
	var reached: bool = false
	for index: int in 20:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = true
		d.viewport.push_input(event, true)
		event = InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = false
		d.viewport.push_input(event, true)
		await d.frames()
		var focus: Control = d.viewport.gui_get_focus_owner()
		if focus != null and focus.name == "support":
			var scroll: ScrollContainer = main.content.find_children("*", "ScrollContainer", true, false)[0]
			reached = scroll.get_global_rect().encloses(focus.get_global_rect())
			await d.shot("keyboard-focus")
			break
	d.step("keyboard focus scrolls into view", reached)
	d.step("close settings to home", await d.tap(b("close")) and main.screen == "home")
	fit_step("Korean large-text home")
	await d.shot("home-korean-large-text")
	d.step("start a board with larger text", await start_from_home())
	play_fit_step("Korean large-text board")
	await d.shot("board-korean-large-text")
	await restart_game("play", "ko-KR")
	d.step("language and analytics survive restart", main.language() == "ko" and not main.state.data.settings.analytics and main.state.data.settings.large_text)
	d.end()


## 설정의 안내 다시 보기: 튜토리얼 판을 다시 하되 시작 선물은 또 주지 않는다.
func replay_guide() -> void:
	d.begin("replay-guide", ["tutorial", "startup", "ui_navigation", "account_save"])
	d.step("start goes home", await d.tap(b("start")) and main.screen == "home")
	var coins: int = player().coins()
	var boosters: Array = [player().booster("hint"), player().booster("undo"), player().booster("slot")]
	d.step("settings", await d.tap(b("settings")))
	d.step("replay the guide", await d.tap(b("replay")) and main.screen == "play" and await pilot.settle())
	d.expect_equal("the tutorial board again", [main.play.mode, main.play.guide_step], ["tutorial", "pick"])
	var guide: Dictionary = main.session.tutorial["guide"]
	d.step("first group", await pilot.submit(pilot.board().group_items(guide["order"][0])))
	d.step("hold", await pilot.hold(guide["hold"]))
	d.step("second group", await pilot.submit(pilot.board().group_items(guide["order"][1])))
	d.step("last group", await pilot.submit(pilot.board().group_items(guide["order"][2])))
	d.step("end card", await pilot.popup_open("tutorial_done"))
	d.step("finish", await pilot.tap_popup("claim") and await d.wait_for(func() -> bool: return main.screen == "home", 600))
	d.expect_equal("AC-015 no second gift", [player().coins(), player().booster("hint"), player().booster("undo"), player().booster("slot")], [coins] + boosters)
	d.expect_equal("the guide is complete again", main.state.data.tutorial.status, "complete")
	d.end()


## 일일 도전 진입 화면(SCR-008): 오늘의 판, 결과와 결과 복사, 놓친 날 다시 풀기(연속 기록 제외).
func daily_challenge() -> void:
	d.begin("daily-challenge", ["daily_challenge", "core_play", "result_rewards", "ui_navigation"])
	d.step("open daily from home", main.screen == "home" and await d.tap(b("daily")) and main.screen == "daily")
	var view: Control = main.outgame_view
	d.expect_equal("SCR-008 today is open and selected", [view.selected, b("day_" + clock.date).get_meta("state")], [clock.date, "open"])
	d.step("SCR-008 the no-booster rule and the today button", b("rule") != null and label_of(b("play_daily")) == "오늘의 도전")
	d.step("SCR-008 no history yet", b("no_history") != null)
	fit_step("daily")
	await d.shot("daily")
	d.step("play today", await d.tap(b("play_daily")) and main.screen == "play" and await pilot.settle())
	d.expect_equal("today's daily board", [main.play.mode, main.play.date], ["daily", clock.date])
	Engine.time_scale = FAST
	d.step("clear the daily board", await pilot.clear_board() and await pilot.popup_open("result"))
	Engine.time_scale = SLOW
	d.expect_equal("AC-014 the success counts toward the streak", [main.play.result["counted"], player().daily_streak(clock.date)], [true, 1])
	d.step("OK goes home", await pilot.tap_popup("next") and await d.wait_for(func() -> bool: return main.screen == "home" and main.play == null, 600))
	d.step("SCR-002 today's daily shows a tick", b("daily_tick") != null and b("streak_days").text == "1")
	d.step("open daily again", await d.tap(b("daily")) and main.screen == "daily")
	d.step("SCR-008 today's result with a copy button", b("result") != null and b("copy") != null)
	var order: Array = player().daily_result(clock.date)["order"]
	d.step("copy the result", await d.tap(b("copy")) and clipboard.size() == 1 and clipboard.back().contains("#1"))
	d.step("the shared text does not give away the categories", not clipboard.back().contains(main.session.catalog.category_name(order[0], "ko")))
	d.expect_equal("share is reported", recorder.last("share"), {"mode": "daily", "level": 1})
	await d.shot("daily-done")
	# 이틀 뒤: 어제를 놓쳐 연속 기록이 끊겼고, 놓친 날은 다시 풀 수 있지만 연속 기록에 들어가지 않는다.
	clock.date = "2026-12-03"
	clock.now += 2 * 86400
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.step("open daily two days later", await d.tap(b("daily")) and main.screen == "daily")
	d.expect_equal("SCR-008 calendar: done, missed, today", [b("day_2026-12-01").get_meta("state"), b("day_2026-12-02").get_meta("state"), b("day_2026-12-03").get_meta("state")], ["done", "open", "open"])
	d.step("SCR-008 the missed day shows an empty ring", b("day_2026-12-02").find_child("ring", true, false) != null and b("day_2026-12-01").find_child("tick", true, false) != null)
	d.expect_equal("SCR-008 the streak broke after a missed day", [b("streak_now").text, b("streak_best").text], ["0일 연속", "최고 1일"])
	d.step("pick the missed day", await d.tap(b("day_2026-12-02")) and main.outgame_view.selected == "2026-12-02")
	d.step("SCR-008 past days don't count toward the streak", b("past_note") != null and label_of(b("play_daily")) == "이 날 풀기")
	await d.shot("daily-past")
	d.step("play the missed day", await d.tap(b("play_daily")) and main.screen == "play" and await pilot.settle() and main.play.date == "2026-12-02")
	d.step("pause", await d.tap(main.play.pause_button) and await pilot.popup_open("pause"))
	d.step("home", await pilot.tap_popup("home") and await pilot.tap_popup("confirm") and await d.wait_for(func() -> bool: return main.screen == "home" and main.play == null, 600))
	d.end()


## 도감(SCR-009): 모은 수, 결과 창과 같은 범주, 칸 위에서 밀어도 스크롤, 상세(본 카드는 채움, 못 본 카드는 윤곽).
func album_screen() -> void:
	d.begin("album", ["album", "result_rewards", "ui_navigation"])
	d.step("open the album", await d.tap(b("album")) and main.screen == "album")
	var total: int = main.session.catalog.category_ids().size()
	d.expect_equal("SCR-009 collected count", b("album_count").text, "모은 범주 %d / %d" % [player().album_count(), total])
	d.step("SCR-007 the categories the first result named are collected here", first_album.all(func(category: String) -> bool: return b("category_" + category) != null and b("category_" + category).get_meta("collected")))
	d.step("SCR-009 every collected name fits two lines of its cell, and the cells are at least as wide as the probe assumes", album_names_fit(), album_names_problem)
	fit_step("album")
	await d.shot("album")
	var scroll: ScrollContainer = b("album_scroll")
	var from: Vector2 = scroll.get_global_rect().get_center()
	var before: int = scroll.scroll_vertical
	await d.drag(from, from - Vector2(0, 200), 10, 0.25)
	await d.frames(10)
	d.step("SCR-009 dragging over the cells scrolls the list without opening one", scroll.scroll_vertical > before and main.outgame_popup == null)
	var collected: String = player().album_categories()[0]
	d.step("open a collected category", await d.tap(b("category_" + collected)) and await outgame_popup_open())
	var cards: Array = main.outgame_popup.find_children("card_*", "", true, false)
	var filled: int = cards.filter(func(node: Node) -> bool: return node.get_meta("seen", false)).size()
	d.expect_equal("SCR-009 seen cards are filled and the rest are outlines", [filled, cards.size()], [player().album_items(collected).size(), main.session.catalog.category_members(collected).size()])
	await d.shot("album-detail")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("the back key closes the detail first", await d.wait_for(func() -> bool: return main.outgame_popup == null, 300) and main.screen == "album")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.end()


## 상점(SCR-010): 플레이 화면의 코인 칩에서 열기, 부스터 사기, 코인 부족 표시, 꾸미기 사기와 사용, 판에 적용.
func shop_and_decor() -> void:
	d.begin("shop-and-decor", ["shop", "boosters", "core_play", "ui_navigation"])
	d.step("start a board", await start_from_home())
	var add: Control = main.play.coin_chip.get_node("Row/Add")
	d.step("the play coin chip offers the shop", add.is_visible_in_tree())
	d.step("SCR-010 the plus opens the shop", await d.tap(add) and await d.wait_for(func() -> bool: return main.screen == "shop", 300))
	var coins: int = player().coins()
	var hints: int = player().booster("hint")
	d.step("enough coins for a hint", coins >= Economy.price("hint"))
	d.step("buy a hint for 100", await d.tap(b("buy_hint")) and player().coins() == coins - Economy.price("hint") and player().booster("hint") == hints + 1)
	d.expect_equal("the owned count and the spend are recorded", [b("owned_hint").text, recorder.last("spend_virtual_currency")["item_name"]], ["보유 %d개" % (hints + 1), "hint"])
	fit_step("shop")
	await d.shot("shop")
	d.step("decor tab", await d.tap(b("tab_decor")) and main.outgame_view.tab == "decor")
	coins = player().coins()
	var dear: Control = b("buy_background_night")
	d.step("SCR-010 a theme you cannot afford shows a red price", dear != null and dear.get_meta("unaffordable", false))
	d.step("tapping it only tells the shortage", await d.tap(dear) and player().coins() == coins and not player().owns_theme("background_night"))
	d.expect_equal("shortage toast", main.toasts.back(), "코인이 %d개 모자라요" % (Economy.theme_price("background_night") - coins))
	await d.shot("shop-decor")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.expect_equal("the board was kept", label_of(b("play")), "이어 하기")

	# 고정 자료: 저장 파일에 코인을 넣고 다시 띄워 꾸미기를 사고 쓴다.
	await d.unmount(main)
	var save_path: String = SavePaths.under(save_dir, "play").progress
	var saved: Dictionary = AtomicStore.read_dictionary(save_path)["value"]
	saved["profile"]["coins"] = int(saved["profile"]["coins"]) + 3000
	d.step("fixture: 3,000 coins added to the save", AtomicStore.write(save_path, saved))
	await mount_game("play", "ko-KR")
	d.step("start goes home", await d.tap(b("start")) and main.screen == "home")
	d.step("open the shop", await d.tap(b("shop")) and main.screen == "shop")
	d.step("decor tab", await d.tap(b("tab_decor")))
	coins = player().coins()
	d.step("buy mint card backs", await d.tap(b("buy_card_back_mint")) and player().owns_theme("card_back_mint") and player().coins() == coins - 600)
	d.step("SCR-010 the bought theme is in use and the default can be picked", b("using_card_back_mint") != null and b("use_card_back_default") != null)
	d.step("buy the peach background", await d.tap(b("buy_background_peach")) and main.backdrop.theme_id == "background_peach")
	await d.shot("shop-bought")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	var next_back: Control = b("next_backs").get_child(0)
	d.step("the home shows the mint card backs", next_back._back.texture == Look.back_plate("card_back_mint"))
	await d.shot("home-decor")
	d.step("continue the board with the new look", await start_from_home() and main.play.get_node("Backdrop").theme_id == "background_peach")
	await d.shot("board-decor")
	d.step("pause", await d.tap(main.play.pause_button) and await pilot.popup_open("pause"))
	d.step("home", await pilot.tap_popup("home") and await pilot.tap_popup("confirm") and await d.wait_for(func() -> bool: return main.screen == "home", 600))
	d.step("open the shop again", await d.tap(b("shop")) and await d.tap(b("tab_decor")))
	d.step("use the default card back again", await d.tap(b("use_card_back_default")) and player().selected_theme("card_back") == "" and Look.card_back_id == "")
	d.step("use the default background again", await d.tap(b("use_background_default")) and main.backdrop.theme_id == "")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.end()


## 출석(SCR-011): 받을 것이 있으면 맥동, 일곱 칸, 받기와 보상 연출, 받은 날은 내일을 기다림, 하루를 건너뛰어도 이어서 받음.
func attendance_checkin() -> void:
	d.begin("attendance", ["attendance", "ui_kit"])
	d.step("SCR-002 check-in pulses", main.home_view.pulsing.has("attendance"))
	d.step("open check-in", await d.tap(b("attendance")) and await outgame_popup_open())
	var days: Array = main.outgame_popup.find_children("day_*", "", true, false)
	d.expect_equal("SCR-011 seven days and today is day 1", [days.size(), b("day_1").get_meta("state"), b("day_2").get_meta("state")], [7, "today", "later"])
	await d.shot("attendance")
	var coins: int = player().coins()
	d.step("claim day 1", await d.tap(b("claim")) and await d.wait_for(func() -> bool: return main.outgame_popup == null and main.screen == "home", 600))
	d.expect_equal("20 coins paid and reported", [player().coins(), recorder.last("attendance_claim")], [coins + 20, {"day": 1}])
	d.step("reward ceremony impact", await d.wait_for(func() -> bool: return main.ceremony.phase == "impact", 600))
	await d.shot("attendance-reward", false)
	d.step("reward ceremony finished", await d.wait_for(func() -> bool: return main.ceremony.phase == "done", 900))
	d.step("the pulse stops after claiming", not main.home_view.pulsing.has("attendance"))
	d.step("open check-in again", await d.tap(b("attendance")) and await outgame_popup_open())
	d.step("day 1 is ticked and claiming waits for tomorrow", b("day_1").get_meta("state") == "claimed" and b("claim").disabled)
	d.step("close", await d.tap(main.outgame_popup.get_node("Center/Frame/Body/Header/Close")) and await d.wait_for(func() -> bool: return main.outgame_popup == null, 300))
	# 이틀을 건너뛰어도 2일째(힌트 1)를 받는다.
	clock.date = "2026-12-05"
	clock.now += 2 * 86400
	var hints: int = player().booster("hint")
	d.step("open check-in two days later", await d.tap(b("attendance")) and await outgame_popup_open() and b("day_2").get_meta("state") == "today")
	d.step("claim day 2", await d.tap(b("claim")) and await d.wait_for(func() -> bool: return main.outgame_popup == null, 600) and player().booster("hint") == hints + 1)
	d.step("ceremony finished", await d.wait_for(func() -> bool: return main.ceremony.phase == "done", 900))
	d.end()


## 설정(SCR-014): 개인정보처리방침, 동의 지역에서만 보이는 개인정보 선택, 오픈소스 고지, 제품 스위치.
func settings_privacy_licenses() -> void:
	d.begin("settings-privacy-licenses", ["settings_support", "ad_placements", "ui_navigation", "ui_analytics_opt_out"])
	d.step("settings", await d.tap(b("settings")) and main.screen == "settings")
	d.step("SCR-014 no privacy choice outside consent regions", b("privacy_choice") == null)
	d.step("the privacy policy opens the site", await d.tap(b("privacy_policy")) and opened_urls == ["https://www.seorilabs.com/en/apps/four-alike/privacy/"])
	ads.settle_consent(true)
	d.step("SCR-014 the privacy choice appears when it is required", await d.wait_for(func() -> bool: return b("privacy_choice") != null and main.screen == "settings"))
	# 설정 화면이 다시 그려졌다. 자리가 잡힌 뒤에 누른다.
	await d.frames(3)
	d.step("it opens the consent form", await d.tap(b("privacy_choice")) and ads.privacy_opened == 1)
	d.step("toggles use the product switch", (b("music") as CheckButton).get_theme_icon("checked") == Art.outgame("switch_on"))
	await d.shot("settings-privacy")
	d.step("open-source notices", await d.tap(b("licenses")) and main.screen == "licenses")
	d.step("read the Fluent Emoji notice", await d.tap(b("license_fluent")) and b("license_text") != null and b("license_text").text.contains("MIT License"))
	d.step("every notice text ships with the game", Licenses.ENTRIES.all(func(entry: Array) -> bool: return not Licenses.text_of(entry[3]).is_empty()))
	await d.shot("licenses")
	d.step("back to settings", await d.tap(b("back")) and main.screen == "settings")
	d.step("vibration toggle reports the change", await d.tap(b("vibration")) and recorder.last("settings_change") == {"key": "vibration", "value": "false"} and not main.audio.vibration)
	d.step("turn it back on", await d.tap(b("vibration")) and main.audio.vibration)
	ads.settle_consent(false)
	d.step("close to home", await d.tap(b("close")) and main.screen == "home")
	d.end()


## 홈에서 뒤로 가기: 처음에는 안내만 하고, 곧바로 한 번 더 누르면 끝낸다.
func back_to_exit() -> void:
	d.begin("back-to-exit", ["ui_navigation"])
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("the first back only tells you", quits == 0 and main.toasts.back() == "한 번 더 누르면 게임을 끝내요" and main.screen == "home")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("a second back exits", quits == 1)
	d.end()


## 영어와 큰 글자(앞 시나리오에서 켰다)로 바깥 화면을 다시 돌며 화면 밖으로 나가거나 겹치는 곳이 없는지 본다(AC-018).
func outgame_english() -> void:
	d.begin("outgame-english-large-text", ["title_home", "daily_challenge", "album", "shop", "attendance", "inbox", "ui_locale_offline"])
	d.step("settings", await d.tap(b("settings")) and main.screen == "settings")
	d.step("language", await d.tap(b("language")))
	d.step("English", await d.tap(b("en")) and main.language() == "en")
	d.step("close to home", await d.tap(b("close")) and main.screen == "home")
	d.step("large text is still on", main.state.data.settings.large_text)
	d.expect_equal("AC-018 home in English", [b("stage_title").text, label_of(b("play"))], ["Stage %d" % player().stage(), "Play Stage %d" % player().stage()])
	fit_step("AC-018 English large-text home")
	await d.shot("home-en")
	d.step("daily", await d.tap(b("daily")) and main.screen == "daily")
	fit_step("AC-018 English large-text daily")
	await d.shot("daily-en")
	# 오늘(12월 5일)은 토요일이라 달력의 맨 오른쪽 열이다. 풀고 나면 그 칸의 완료 체크가 목록 가장자리에서 잘리지 않아야 한다.
	d.step("SCR-008 today is a Saturday, the last column", Daily.weekday(clock.date) == 6)
	d.step("play today's daily", await d.tap(b("play_daily")) and main.screen == "play" and await pilot.settle())
	Engine.time_scale = FAST
	d.step("clear it", await pilot.clear_board())
	await d.wait_for(func() -> bool: return main.play.popup != null or ads.showing() == "interstitial", Pilot.SETTLE_FRAMES)
	if ads.showing() == "interstitial":
		ads.finish("dismissed")
	d.step("the daily result", await pilot.popup_open("result"))
	Engine.time_scale = SLOW
	d.step("OK goes home", await pilot.tap_popup("next") and await d.wait_for(func() -> bool: return main.screen == "home" and main.play == null, 600))
	d.step("daily again", await d.tap(b("daily")) and main.screen == "daily")
	var saturday: Control = b("day_" + clock.date)
	var tick: Control = saturday.find_child("tick", true, false) as Control if saturday != null else null
	d.step("SCR-008 the Saturday tick is inside the list, not cut off", tick != null and (b("daily_scroll") as Control).get_global_rect().encloses(tick.get_global_rect()),
		"tick %s, list %s" % [tick.get_global_rect() if tick != null else Rect2(), (b("daily_scroll") as Control).get_global_rect()])
	await d.shot("daily-saturday-en")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.step("album", await d.tap(b("album")) and main.screen == "album")
	fit_step("AC-018 English large-text album")
	await d.shot("album-en")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.step("shop", await d.tap(b("shop")) and main.screen == "shop")
	fit_step("AC-018 English large-text shop")
	await d.shot("shop-en")
	d.step("decor tab", await d.tap(b("tab_decor")))
	await d.shot("shop-decor-en")
	d.step("back home", await d.tap(b("back")) and main.screen == "home")
	d.step("check-in", await d.tap(b("attendance")) and await outgame_popup_open())
	await d.shot("attendance-en")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("the back key closes the popup", await d.wait_for(func() -> bool: return main.outgame_popup == null, 300) and main.screen == "home")
	d.step("inbox", await d.tap(b("inbox")) and main.screen == "inbox")
	d.expect_equal("SCR-015 the welcome message in English", b("mail_local-welcome").find_child("title", true, false).text, "Welcome to Four Alike!")
	fit_step("AC-018 English large-text inbox")
	await d.shot("inbox-en")
	d.step("close to home", await d.tap(b("close")) and main.screen == "home")
	d.end()

## 설정의 데이터 초기화(SCR-014): 두 번 확인해야만 지우고, 지우면 처음 실행한 것처럼 타이틀과 튜토리얼부터 시작한다.
## 앞 시나리오의 영어와 큰 글자로 두 단계를 본 뒤 둘째 단계를 뒤로 가기로 닫는다. 한국어 보통 글자로 바꿔 첫 확인을 취소하고,
## 다시 열어 두 번 확인해 지운다. 지운 뒤 공통 상태와 제품 저장 파일이 첫 실행의 기본값인지 파일에서 확인한다.
func data_reset() -> void:
	d.begin("data-reset", ["data_reset", "settings_support", "account_save", "run_save", "startup", "tutorial", "ui_analytics_opt_out", "ui_navigation"])
	var paths: SavePaths = SavePaths.under(save_dir, "play")
	var kept: Dictionary = player().to_dict()
	var fresh: Dictionary = Progress.create().to_dict()
	d.step("there is something to lose in every part of the save", ["profile", "journey", "daily", "album", "attendance"].all(func(key: String) -> bool: return kept[key] != fresh[key]))
	d.step("analytics is off and its marker file is kept", not main.state.data.settings.analytics and FileAccess.file_exists(paths.state + SavePaths.ANALYTICS_OFF_SUFFIX))
	d.step("the product save has a backup", FileAccess.file_exists(paths.progress + FileStore.BACKUP_SUFFIX))
	var common: Dictionary = main.state.data.duplicate(true)

	# 영어와 큰 글자: 설정 줄, 첫 확인, 둘째 확인, 뒤로 가기.
	d.step("settings", await d.tap(b("settings")) and main.screen == "settings")
	var row: Button = b("data_reset") as Button
	d.step("SCR-014 the reset row is the last row", row != null and row.get_index() == row.get_parent().get_child_count() - 2)
	d.step("SCR-014 it has the red row icon, a chevron and red text", row.icon == Art.outgame("set_data_reset") and row.find_child("chevron", false, false) != null and row.get_theme_color("font_color") == Ui.DANGER_INK)
	d.step("scroll to the reset row", await d.scroll_into_view(row))
	await d.shot("settings-reset-en")
	d.step("open the reset check", await d.tap(row) and await outgame_popup_open())
	d.expect_equal("SCR-014 the first check names what is erased", erased_items(), ["Stage progress", "Coins", "Boosters", "Album", "Daily & check-in", "Decor", "Settings"])
	d.expect_equal("SCR-014 first check: Delete and Cancel", [label_of(b("delete")), label_of(b("cancel")), b("delete").get_meta("danger", false)], ["Delete", "Cancel", false])
	popup_fit_step("SCR-014 first check in English large text")
	await d.shot("reset-first-en")
	d.step("Delete moves to the final check", await d.tap(b("delete")) and await d.wait_for(func() -> bool: return main.outgame_popup.get_meta("step") == "final" and b("delete_all") != null and b("delete") == null))
	await d.frames(3)
	d.step("SCR-014 the final check says it cannot be undone", b("warning").text.contains("can't be undone"))
	d.expect_equal("SCR-014 the final check has a red main button", [label_of(b("delete_all")), b("delete_all").get_meta("danger", false), label_of(b("cancel"))], ["Delete all", true, "Cancel"])
	popup_fit_step("SCR-014 final check in English large text")
	await d.shot("reset-final-en")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	d.step("the back key closes the final check", await d.wait_for(func() -> bool: return main.outgame_popup == null, 300) and main.screen == "settings")
	d.step("closing the final check erases nothing", player().to_dict() == kept and main.state.data == common and recorder.forgotten == 0)

	# 한국어와 보통 글자로 바꾼다.
	d.step("language", await d.tap(b("language")))
	d.step("Korean", await d.tap(b("ko")) and main.language() == "ko")
	d.step("back to settings", await d.tap(b("back")) and main.screen == "settings")
	d.step("accessibility", await d.tap(b("accessibility")))
	d.step("normal text", await d.tap(b("large_text")) and not main.state.data.settings.large_text)
	d.step("back to settings", await d.tap(b("back")) and main.screen == "settings")
	common = main.state.data.duplicate(true)
	d.step("scroll to the reset row", await d.scroll_into_view(b("data_reset")))
	await d.shot("settings-reset-ko")
	d.step("open the reset check in Korean", await d.tap(b("data_reset")) and await outgame_popup_open())
	d.expect_equal("SCR-014 the first check in Korean", [erased_items(), label_of(b("delete")), label_of(b("cancel"))],
		[["스테이지 진행", "코인", "부스터", "도감", "일일 도전과 출석", "꾸미기", "설정"], "지우기", "취소"])
	popup_fit_step("SCR-014 first check in Korean")
	await d.shot("reset-first-ko")
	d.step("cancel the first check", await d.tap(b("cancel")) and await d.wait_for(func() -> bool: return main.outgame_popup == null, 300) and main.screen == "settings")
	d.step("cancelling the first check erases nothing", player().to_dict() == kept and main.state.data == common and FileAccess.file_exists(paths.state + SavePaths.ANALYTICS_OFF_SUFFIX) and recorder.forgotten == 0)

	# 두 번 확인해 지운다.
	var settings_events: int = recorder.count("settings_change")
	d.step("open the reset check again", await d.tap(b("data_reset")) and await outgame_popup_open())
	d.step("first check: delete", await d.tap(b("delete")) and await d.wait_for(func() -> bool: return b("delete_all") != null))
	await d.frames(3)
	d.expect_equal("SCR-014 the final check in Korean", [main.outgame_popup.get_node("Center/Frame/Body/Header/Title").text, label_of(b("delete_all"))], ["정말 지울까요?", "모두 지우기"])
	popup_fit_step("SCR-014 final check in Korean")
	await d.shot("reset-final-ko")
	d.step("final check: delete all", await d.tap(b("delete_all")))
	d.step("SCR-001 the title comes back as on a first run", await d.wait_for(func() -> bool: return main.start_ready() and main.outgame_popup == null, 600))
	d.expect_equal("nothing is left behind the title", [main.screen, main.navigation.size(), main.play == null], ["title", 0, true])
	d.step("the common state is the default and its files are gone",
		main.state.data == main.state.defaults() and not FileAccess.file_exists(paths.state) and not FileAccess.file_exists(paths.state + SavePaths.ANALYTICS_OFF_SUFFIX))
	d.expect_equal("settings are back to the defaults and analytics is allowed again",
		[main.state.data.settings.language, main.language(), main.state.data.settings.large_text, main.state.data.settings.analytics], ["system", "ko", false, true])
	var expected: Progress = Progress.create()
	expected.roll_date(clock.today())
	AdPolicy.begin_session(expected.ads())
	var stored: Dictionary = AtomicStore.read_dictionary(paths.progress)["value"]
	d.step("the product save file holds only what a first run writes", stored == JSON.parse_string(JSON.stringify(expected.to_dict())), "stage %s, coins %s" % [stored.get("journey", {}).get("stage"), stored.get("profile", {}).get("coins")])
	d.step("the old backup is gone", not FileAccess.file_exists(paths.progress + FileStore.BACKUP_SUFFIX))
	d.expect_equal("stage 1, no coins, boosters, album or decor",
		[player().stage(), player().coins(), player().booster("hint"), player().booster("undo"), player().booster("slot"), player().album_count(), player().owns_theme("card_back_mint")],
		[1, 0, 0, 0, 0, 0, false])
	d.expect_equal("analytics starts over on this device once", recorder.forgotten, 1)
	d.expect_equal("the reset itself reports no settings change", recorder.count("settings_change"), settings_events)
	d.expect_equal("SCR-001 Korean title", [b("logo").text, label_of(b("start"))], ["끼리끼리", "시작하기"])
	fit_step("title after the reset")
	await d.frames(60)
	await d.shot("title-after-reset")
	d.step("start opens the tutorial board", await d.tap(b("start")) and main.screen == "play" and await pilot.settle())
	d.expect_equal("the tutorial from its first step with nothing in hand", [main.play.mode, main.play.guide_step, player().coins()], ["tutorial", "pick", 0])
	d.end()


## 도감의 모은 칸마다 이름이 맞춰졌는지(AlbumScreen.fit_name), 이름 자리가 프로브가 가정한 가장 좁은 폭 이상인지 본다.
var album_names_problem: String = ""


func album_names_fit() -> bool:
	album_names_problem = ""
	for node: Node in main.outgame_view.find_children("category_*", "Button", true, false):
		var cell: Button = node as Button
		if not cell.get_meta("collected", false):
			continue
		var label: Label = cell.find_child("name", true, false) as Label
		if label == null or not label.get_meta("fits", false) or label.get_line_count() > AlbumScreen.NAME_LINES:
			album_names_problem = "%s does not fit" % cell.name
			return false
		if label.size.x + 0.5 < AlbumScreen.NAME_MIN_WIDTH:
			album_names_problem = "%s name room %.1f is below %.1f" % [cell.name, label.size.x, AlbumScreen.NAME_MIN_WIDTH]
			return false
	return true


## 데이터 초기화 첫 확인의 꼬리표 글.
func erased_items() -> Array:
	var items: Array = []
	for label: Node in main.outgame_popup.find_child("erased", true, false).find_children("*", "Label", true, false):
		items.append((label as Label).text)
	return items


## 타이틀의 오류 상태(SCR-001): 공통 저장을 읽지 못하면 막대 대신 문구와 다시 시도가 보이고, 고친 뒤 다시 시도하면 준비된다.
func title_error_retry() -> void:
	d.begin("title-error-retry", ["startup", "title_home", "account_save"])
	await d.unmount(main)
	var broken: String = save_dir + "/broken.json"
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	await mount_game("broken", "ko-KR", false)
	d.step("SCR-001 the title shows the error", await d.wait_for(func() -> bool: return main.title_progress()["stage"] == "error"))
	d.step("SCR-001 retry instead of start, no bar", b("retry").is_visible_in_tree() and not b("start").visible and not b("bar").visible)
	d.expect_equal("SCR-001 the error text", b("status").text, "저장을 읽지 못했습니다. 기존 데이터는 보존했습니다.")
	await d.frames(60)
	await d.shot("title-error")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken))
	d.step("retry after the save is fixed", await d.tap(b("retry")) and await d.wait_for(func() -> bool: return main.start_ready()))
	d.step("start opens the tutorial board", await d.tap(b("start")) and main.screen == "play" and await pilot.settle())
	d.end()

## 실제 어댑터(FaLiveServices)를 끼운 기본 구성: 개발 PC에는 광고 SDK가 없어 광고는 준비되지 않고, 동의는 기다릴 것이 없다.
func live_services_offline() -> void:
	d.begin("live-services-offline", ["startup", "ad_placements", "observability", "tutorial"])
	await d.unmount(main)
	var paths: SavePaths = SavePaths.under(save_dir, "live")
	main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.state = State.new(paths.state)
	main.device_locale = "en-US"
	main.game_services.store = FileStore.new(paths.progress)
	main.game_services.clock = clock
	main.use_live_services(paths.services)
	_hook_os(main)
	pilot.main = main
	await d.mount(main)
	d.step("startup with the real adapters", await d.wait_for(func() -> bool: return main.start_ready()))
	d.step("FaLiveServices runs as a direct child of the start scene", main.live != null and main.live.get_parent() == main)
	d.step("the real adapters fill the ports and the analytics choice", main.game_services.ads is AdmobAds and main.analytics.port == main.live.analytics and main.config["analytics_policy_allowed"])
	d.step("without the native SDK no ad is ready and there is no consent to wait for", not main.game_services.ads.is_ready("rewarded") and main.game_services.ads.consent_settled())
	d.expect_equal("SCR-001 English title", [b("logo").text, b("subtitle").text, label_of(b("start"))], ["Four Alike", "HIDDEN CATEGORY CARDS", "Play"])
	await d.frames(60)
	await d.shot("title-en")
	d.step("first start opens the tutorial board", await d.tap(b("start")) and main.screen == "play" and await pilot.settle())
	d.step("no ad is offered without an ad", main.play.hold_cell(2) == null or main.play.hold_cell(2).tag != "ad")
	d.end()
