extends SceneTree
## 제품 여정. 실제 시작 장면을 띄우고 화면 좌표 입력만으로 진행한다.
## 대역은 광고(ScriptedAds), 시계(FakeClock), 분석 기록(FaMemoryAnalytics), 저장 경로뿐이다. 판의 상태는 읽어서 확인만 한다.
## 단계 이름의 AC-번호는 GDD 인수 시나리오의 조건이다.

const Driver := preload("res://tests/common/e2e_driver.gd")
const Pilot := preload("res://tests/game/play_pilot.gd")
const State := preload("res://addons/seorilabs_game/flow/state.gd")
const GameServices := preload("res://game/bootstrap/fa_services.gd")
const ScriptedAds := preload("res://game/adapters/fa_scripted_ads.gd")
const MemoryAnalytics := preload("res://game/adapters/fa_memory_analytics.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")

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


func _initialize() -> void:
	call_deferred("run")


func arg(args: PackedStringArray, key: String, fallback: String) -> String:
	return args[args.find(key) + 1] if args.has(key) else fallback


func b(node_name: String) -> Control:
	return main.find_child(node_name, true, false) as Control


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


func play_fit_step(label: String) -> void:
	var problem: String = pilot.fits()
	d.step(label + " fits the screen (AC-018)", problem.is_empty(), problem)


func mount_game(save_name: String, locale: String) -> void:
	main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.state = State.new(save_dir + "/" + save_name + ".json")
	main.device_locale = locale
	var services: GameServices = GameServices.local(save_dir + "/" + save_name + "-progress.json")
	services.ads = ads
	services.clock = clock
	services.analytics = recorder
	main.game_services = services
	pilot.main = main
	await d.mount(main)
	d.step("actual startup completes", await d.wait_for(func() -> bool: return main.initialized))


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

	await d.unmount(main)
	for file_name: String in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	quit(d.finish({"sourceSha": OS.get_environment("GITHUB_SHA")}))


## (1) 첫 실행: 타이틀, 튜토리얼 세 단계, 시작 선물, 홈, 스테이지 1 클리어, 결과, 다음.
func first_run() -> void:
	d.begin("first-run-tutorial-stage-one", ["startup", "tutorial", "core_play", "result_rewards", "account_save", "run_save",
		"inbox", "commerce", "operations", "observability", "ui_leaderboard", "ui_kit"])
	await mount_game("play", "ko-KR")
	d.step("portrait flow on a portrait screen", not main.landscape and d.viewport.size.x < d.viewport.size.y)
	d.step("product skin theme is applied", main.skin_dir == "res://game/skins/candy_pop" and main.theme != null)
	fit_step("title")
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

	# 홈: 다음 스테이지와 시작 버튼.
	d.step("home shows the next stage", b("home_stage") != null and b("home_stage").stage_number == 1)
	d.step("home coin chip shows the product coins", b("coins") != null and b("coins").value == gifted)
	d.step("unsupported commerce and ranking hidden", b("shop") == null and b("leaderboard") == null)
	d.step("home play action is the primary skin", b("play") != null and b("play").theme_type_variation == &"PrimaryButton")
	fit_step("home")
	await d.shot("home")
	d.step("open inbox", await d.tap(b("inbox")) and main.screen == "inbox")
	await d.shot("popup-open", false)
	await d.shot("inbox")
	d.step("close to home", await d.tap(b("close")) and main.screen == "home")

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
	d.expect_equal("home offers to continue the round", b("play").text, "이어 하기")
	d.step("settings", await d.tap(b("settings")) and main.screen == "settings")
	d.step("language", await d.tap(b("language")))
	d.step("English selection", await d.tap(b("en")) and main.language() == "en")
	d.step("close settings to home", await d.tap(b("close")) and main.screen == "home")
	d.expect_equal("AC-018 home action is in English", b("play").text, "Continue")
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
	d.expect_equal("the round is dropped and the stage is kept", [player().has_run(), player().stage(), b("play").text], [false, 4, "Play Stage 4"])
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
