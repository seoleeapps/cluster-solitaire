extends SceneTree
## 플레이 화면의 시안 비교용 캡처. 기준 그림(docs/game-design/ui/direction/b-play-*.png)과 같은 상태를 만들어 찍는다.
## 여정(outgame_journey.gd)과 달리 저장 파일을 미리 만들어 원하는 판에서 시작한다(고정 자료). 그 뒤의 선택은 화면 입력으로 한다.
##
##   godot --audio-driver Dummy --path godot --script res://tests/game/play_capture.gd -- --out <폴더> [--only <묶음>]
##   묶음: reference(기준 그림과 같은 상태, 한국어와 영어, 3배), sizes(세 화면 크기), layouts(모든 배치),
##         states(카드·칸·버튼의 상태 시트), motion(묶음 완성·오답·결과 연출의 중간 프레임),
##         daily(일일 도전 모드. 진입 화면을 거치지 않고 시작 장면의 launch_daily로 바로 띄운다)
## 렌더링 모드(--headless 없이)에서만 PNG가 남는다. 출력 폴더는 build/ 아래에 둔다.
##
## 기준 그림은 위 50, 아래 30의 여백으로 그려졌다. 같은 여백이 나오게 안전 영역을 위 34, 아래 16으로 넣는다.

const Driver := preload("res://tests/common/e2e_driver.gd")
const Pilot := preload("res://tests/game/play_pilot.gd")
const State := preload("res://addons/seorilabs_game/flow/state.gd")
const GameServices := preload("res://game/bootstrap/fa_services.gd")
const ScriptedAds := preload("res://game/adapters/fa_scripted_ads.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Layout := preload("res://game/features/play/play_layout.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const SlotCell := preload("res://game/features/play/slot_cell.gd")
const MedalView := preload("res://game/features/play/medal_view.gd")
const BoosterButton := preload("res://game/features/play/booster_button.gd")
const Backdrop := preload("res://game/features/shared/fa_backdrop.gd")
const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")

const BASE := Vector2i(390, 844)
const REFERENCE_INSETS := Vector2(34, 16)
const SIZES: Array[Vector2i] = [Vector2i(390, 693), Vector2i(390, 844), Vector2i(390, 866)]
## 배치별로 그 배치가 처음 나오는 스테이지(intro는 튜토리얼 판).
const LAYOUT_STAGES := {"open": 1, "step": 6, "classic": 22, "deep": 69}
const REFERENCE_SELECTION: Array[String] = ["banana", "strawberry", "lemon", "grapes"]

var d: RefCounted
var pilot: Pilot
var ads: ScriptedAds
var clock: Pilot.FakeClock
var save_dir: String = ""
var main: Control
var serial: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "user://capture"
	var only: String = args[args.find("--only") + 1] if args.has("--only") else ""
	d = Driver.new(self, BASE, out, true)
	pilot = Pilot.new(d)
	ads = ScriptedAds.new()
	clock = Pilot.FakeClock.new()
	save_dir = "user://capture-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(save_dir)
	d.begin("play-capture", ["core_play"])
	if only in ["", "reference"]:
		await reference()
	if only in ["", "sizes"]:
		await sizes()
	if only in ["", "layouts"]:
		await layouts()
	if only in ["", "states"]:
		await states()
	if only in ["", "motion"]:
		await motion()
	if only in ["", "daily"]:
		await daily()
	if main != null:
		await d.unmount(main)
	d.end()
	for file_name: String in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	quit(d.finish())


# =====================================================================
# 묶음
# =====================================================================

## 기준 그림과 같은 상태: 스테이지 12, 날씨 완성, 과일 네 장 선택, 임시 칸에 기타, 실수 1, 코인 1,250, 힌트 2, 되돌리기 1.
func reference() -> void:
	for language: String in ["ko", "en"]:
		d.step("reference state in " + language, await open_reference(language, BASE, REFERENCE_INSETS))
		await d.shot("reference-" + language)
		# 2배(기준 그림의 배율)와 3배 화면: 논리 크기는 그대로 두고 그리는 배율만 올린다(휴대전화와 같은 방식).
		for factor: int in [2, 3]:
			d.viewport.size = BASE * factor
			d.viewport.size_2d_override = BASE
			d.viewport.size_2d_override_stretch = true
			await d.shot("reference-%s-%dx" % [language, factor])
		d.viewport.size_2d_override_stretch = false
		d.viewport.size_2d_override = Vector2i.ZERO
		d.viewport.size = BASE


## 같은 상태를 작은 화면, 기준, 긴 화면에서. 안전 영역이 없는 기기를 가정한다.
func sizes() -> void:
	for language: String in ["ko", "en"]:
		for size: Vector2i in SIZES + [Vector2i(360, 640)]:
			d.step("reference state at %s in %s" % [size, language], await open_reference(language, size, Vector2.ZERO))
			var problem: String = pilot.fits()
			d.step("fits %s in %s" % [size, language], problem.is_empty(), problem)
			await d.shot("size-%s-%dx%d" % [language, size.x, size.y])
	d.viewport.size = BASE


## 모든 배치(intro, open, step, classic, deep)를 세 크기에서.
func layouts() -> void:
	for size: Vector2i in SIZES:
		d.step("intro at %s" % size, await open_stage(0, "ko", size))
		await shot_layout("intro", size)
		for layout: String in LAYOUT_STAGES:
			d.step("%s at %s" % [layout, size], await open_stage(LAYOUT_STAGES[layout], "en" if layout == "classic" else "ko", size))
			d.expect_equal("layout of stage %d" % LAYOUT_STAGES[layout], pilot.board().meta()["layout"], layout)
			await shot_layout(layout, size)
	d.viewport.size = BASE


func shot_layout(layout: String, size: Vector2i) -> void:
	var problem: String = pilot.fits()
	d.step("%s fits %s" % [layout, size], problem.is_empty(), problem)
	await d.shot("layout-%s-%dx%d" % [layout, size.x, size.y])


## 묶음 완성, 오답, 결과 연출의 중간 프레임.
func motion() -> void:
	d.step("stage 1", await open_stage(1, "ko", BASE))
	var play: Control = main.play
	var near: Array = pilot.wrong_pick(3)
	for card: String in near:
		await pilot.tap_card(card)
	await d.tap(play.submit_button)
	await pause(0.1)
	await d.shot("motion-miss", false)
	await pilot.settle()
	var group: Array = pilot.open_group()
	for card: String in group:
		await pilot.tap_card(card)
	await d.tap(play.submit_button)
	await pause(0.2)
	await d.shot("motion-group-fly", false)
	await pause(0.28)
	await d.shot("motion-group-medal", false)
	await pilot.settle()
	await pilot.hold(pilot.board().front_card(0))
	await d.shot("after-hold")
	# 마지막 묶음 앞까지 풀고, 마지막 묶음은 직접 내서 클리어 연출의 중간을 찍는다.
	while pilot.board().remaining_groups() > 1:
		await pilot.advance()
	while pilot.open_group().is_empty():
		await pilot.advance()
	for card: String in pilot.open_group():
		await pilot.tap_card(card)
	await d.tap(play.submit_button)
	d.step("clear ceremony starts", await d.wait_for(func() -> bool: return pilot.board().is_won() and not play.result.is_empty(), 900))
	await pause(0.45)
	await d.shot("motion-clear", false)
	d.step("result popup", await d.wait_for(func() -> bool: return play.popup != null and play.popup.state == "open", 900))
	await pause(0.62)
	await d.shot("motion-result-stars", false)
	await d.wait_for(func() -> bool: return play.result_settled, 900)
	await d.shot("result")


## 연출의 중간을 찍으려고 정해진 시간만큼 기다린다(화면 주사율과 무관하게).
func pause(seconds: float) -> void:
	await create_timer(seconds).timeout


## 카드, 칸, 메달, 버튼, 하트, 토스트의 모든 상태를 한 장에.
func states() -> void:
	if main != null:
		await d.unmount(main)
		main = null
	for language: String in ["ko", "en"]:
		var sheet: Control = build_state_sheet(language)
		await d.mount(sheet)
		await d.frames(10)
		d.step("state sheet in " + language, sheet.get_child_count() > 30)
		await d.shot("states-" + language)
		await d.unmount(sheet)


## 일일 도전 모드: 부스터는 회색이고 잠긴 칸이 없으며 표지에 날짜가 보인다.
func daily() -> void:
	d.step("home", await open_game(seed_save("ko", stage_progress(30), true), BASE, Vector2.ZERO, false))
	main.launch_daily(clock.date)
	d.step("daily board", await pilot.settle())
	var play: Control = main.play
	d.expect_equal("daily mode shows two slots and no boosters", [play.mode, play.hold_cell_count(), play.hint_button.state, play.undo_button.state, play.hint_button.disabled], ["daily", 2, "off", "off", true])
	d.expect_equal("the ribbon shows the date", play.text_of("stage"), "일일 도전 12/1")
	var problem: String = pilot.fits()
	d.step("daily board fits", problem.is_empty(), problem)
	await d.shot("daily")
	for index: int in 4:
		await pilot.submit(pilot.wrong_pick(2, index))
	d.step("daily fail popup has no continue", await pilot.popup_open("fail") and not play.popup_button("continue").visible)
	await d.shot("daily-fail")


# =====================================================================
# 고정 자료와 실행
# =====================================================================

func reference_progress() -> Dictionary:
	var data: Dictionary = Progress.create().to_dict()
	data["profile"]["coins"] = 1250
	data["profile"]["boosters"] = {"hint": 2, "undo": 1, "slot": 0}
	data["journey"]["stage"] = 12
	data["flags"] = {Progress.FLAG_TUTORIAL_DONE: true}
	data["grants"] = {"starter_gift": true}
	data["run"] = {"mode": "journey", "stage": 12, "date": "", "started": "", "seconds": 75, "board": {
		"n": 12, "layout": "classic", "tier": 3, "f": 0.33,
		"groups": [
			{"cat": "weather", "items": ["rainbow", "cloud_with_lightning", "snowflake", "tornado"]},
			{"cat": "fruits", "items": ["banana", "strawberry", "lemon", "grapes"]},
			{"cat": "instruments", "items": ["drum", "guitar", "trumpet", "violin"]},
			{"cat": "sea_creatures", "items": ["dolphin", "octopus", "seal", "squid"]},
		],
		"cols": [["octopus", "violin", "banana"], ["seal", "strawberry"], ["squid", "drum"], ["lemon"]],
		"reserve": ["dolphin", "grapes", "", "trumpet"], "holds": ["guitar", ""],
		"mistakes": 1, "solved": ["weather"], "undo": {"card": "guitar", "column": 3, "slot": 0},
		"continued": false, "tried": ["banana|drum|grapes|lemon"], "hold_moves": 1,
	}}
	return data


func stage_progress(stage: int) -> Dictionary:
	var data: Dictionary = Progress.create().to_dict()
	data["profile"]["coins"] = 320
	data["profile"]["boosters"] = {"hint": 3, "undo": 2, "slot": 1}
	data["journey"]["stage"] = stage
	data["flags"] = {Progress.FLAG_TUTORIAL_DONE: true}
	data["grants"] = {"starter_gift": true}
	return data


## 공통 저장(설정, 튜토리얼 상태)과 제품 저장을 만든다. tutorial_done이 false면 첫 실행 상태다.
func seed_save(language: String, progress: Dictionary, tutorial_done: bool) -> String:
	serial += 1
	var save_name: String = "capture-%d" % serial
	var state := State.new(save_dir + "/" + save_name + ".json")
	state.load_state()
	var next: Dictionary = state.data.duplicate(true)
	next.consentVersion = 1
	next.settings.language = language
	next.settings.analytics = false
	if tutorial_done:
		next.tutorial = {"version": State.TUTORIAL_VERSION, "step": 2, "status": "complete", "hits": 3, "replay": false}
	state.commit(next)
	if not progress.is_empty():
		if Progress.read(progress)["progress"] == null:
			push_error("capture fixture is not a valid save")
		var file := FileAccess.open(save_dir + "/" + save_name + "-progress.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(progress))
		file.close()
	return save_name


## 게임을 띄우고 타이틀의 시작을 누른다. enter_play가 참이면 홈에서 플레이까지 들어간다.
func open_game(save_name: String, size: Vector2i, insets: Vector2, enter_play: bool = true) -> bool:
	if main != null:
		await d.unmount(main)
	d.viewport.size = size
	main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.state = State.new(save_dir + "/" + save_name + ".json")
	main.device_locale = "en-US"
	var services: GameServices = GameServices.local(save_dir + "/" + save_name + "-progress.json")
	services.ads = ads
	services.clock = clock
	main.game_services = services
	main.safe_insets_override = insets
	pilot.main = main
	await d.mount(main)
	if not await d.wait_for(func() -> bool: return main.start_ready()):
		return false
	if not await d.tap(main.find_child("start", true, false)):
		return false
	if not enter_play:
		return main.screen == "home"
	if main.screen == "home" and not await d.tap(main.find_child("play", true, false)):
		return false
	return main.screen == "play" and await pilot.settle()


func open_reference(language: String, size: Vector2i, insets: Vector2) -> bool:
	if not await open_game(seed_save(language, reference_progress(), true), size, insets):
		return false
	for card: String in REFERENCE_SELECTION:
		if not await pilot.tap_card(card):
			return false
	await d.frames(30)
	return main.play.selection.size() == REFERENCE_SELECTION.size()


## 스테이지의 새 판을 연다. stage가 0이면 첫 실행의 튜토리얼 판이다.
func open_stage(stage: int, language: String, size: Vector2i) -> bool:
	var save_name: String = seed_save(language, {}, false) if stage == 0 else seed_save(language, stage_progress(stage), true)
	return await open_game(save_name, size, Vector2.ZERO)


# =====================================================================
# 상태 시트
# =====================================================================

func build_state_sheet(language: String) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load("res://game/skins/candy_pop/theme.tres")
	Art.sharpen(root.theme)
	root.add_child(Backdrop.new())
	var ko: bool = language == "ko"
	var y: float = 14.0
	caption(root, "카드: 기본, 선택, 힌트, 뒷면" if ko else "Card: default, selected, hint, back", y)
	y += 22.0
	var names: Array = [["banana", "바나나", "Banana"], ["strawberry", "딸기", "Strawberry"], ["lemon", "레몬", "Lemon"], ["", "", ""]]
	for index: int in names.size():
		var view := CardView.new()
		root.add_child(view)
		view.configure(Vector2(84.5, 110), 48, language, false)
		view.position = Vector2(14 + index * 92.5, y + 10)
		if names[index][0] == "":
			view.set_face_down(true)
		else:
			view.show_card(names[index][0], names[index][0], names[index][1] if ko else names[index][2])
			view.set_face_down(false)
		if index == 1:
			view.set_selected(true, false)
		if index == 2:
			view.set_hinted(true)
	y += 140.0
	caption(root, "긴 이름(두 줄), 큰 글자, 작은 카드 84" if ko else "Long names (two lines), large text, small card 84", y)
	y += 22.0
	var long_names: Array = [["wheelchair_symbol", "휠체어 표시", "Wheelchair Access"], ["sauropod", "브라키오사우루스", "Brachiosaurus"], ["convenience_store", "편의점", "Convenience Store"], ["banana", "바나나", "Banana"]]
	for index: int in long_names.size():
		var view := CardView.new()
		root.add_child(view)
		view.configure(Vector2(80, 84), 38, language, index == 3)
		view.position = Vector2(23 + index * 88, y)
		var icon: String = long_names[index][0] if ResourceLoader.exists("res://game/assets/icons/%s.png" % long_names[index][0]) else "banana"
		view.show_card(long_names[index][0], icon, long_names[index][1] if ko else long_names[index][2])
		view.set_face_down(false)
	y += 106.0
	caption(root, "칸: 빈 칸, 놓을 수 있음, 잠김(광고, 코인, 보유)" if ko else "Slot: empty, drop target, locked (ad, coins, owned)", y)
	y += 22.0
	var cells: Array = [[SlotCell.EMPTY, ""], [SlotCell.TARGET, ""], [SlotCell.LOCKED, SlotCell.TAG_AD], [SlotCell.LOCKED, SlotCell.TAG_COINS], [SlotCell.LOCKED, SlotCell.TAG_OWNED]]
	for index: int in cells.size():
		var cell := SlotCell.new()
		root.add_child(cell)
		cell.size = Vector2(66, 96)
		cell.position = Vector2(14 + index * 74, y)
		cell.set_state(cells[index][0])
		if cells[index][0] == SlotCell.LOCKED:
			var texts: Dictionary = {SlotCell.TAG_AD: "광고" if ko else "AD", SlotCell.TAG_COINS: "150", SlotCell.TAG_OWNED: "×2"}
			cell.set_lock("+1칸" if ko else "+1 slot", cells[index][1], texts[cells[index][1]], Art.skin("icon_coin"))
	y += 112.0
	caption(root, "부스터: 보유, 0개, 쓸 데 없음, 쓸 수 없음, 강조" if ko else "Booster: owned, none, no use now, off, highlighted", y)
	y += 26.0
	var boosters: Array = [[BoosterButton.READY, 2], [BoosterButton.EMPTY, 0], [BoosterButton.IDLE, 1], [BoosterButton.OFF, 3], [BoosterButton.READY, 1]]
	for index: int in boosters.size():
		var button := BoosterButton.new()
		root.add_child(button)
		button.position = Vector2(18 + index * 74, y)
		var undo: bool = index % 2 == 1
		button.configure("booster_undo" if undo else "booster_hint", "icon_undo" if undo else "icon_hint", ("되돌리기" if undo else "힌트") if ko else ("Undo" if undo else "Hint"), language, 12)
		button.show_state(boosters[index][0], boosters[index][1])
		if index == 4:
			button.set_highlight(true)
	y += 88.0
	caption(root, "주 버튼: 기본, 비활성 / 보조 버튼" if ko else "Primary: default, disabled / secondary", y)
	y += 22.0
	var buttons: Array = [["묶기" if ko else "Group", true, false], ["묶기" if ko else "Group", true, true], ["홈으로" if ko else "Home", false, false]]
	for index: int in buttons.size():
		var button := Button.new()
		button.text = buttons[index][0]
		if buttons[index][1]:
			button.theme_type_variation = &"PrimaryButton"
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_disabled_color", Color("f1f2fa"))
		button.disabled = buttons[index][2]
		button.add_theme_font_override("font", Fonts.display(700))
		button.add_theme_font_size_override("font_size", 22)
		button.position = Vector2(14 + index * 124, y)
		button.size = Vector2(114, 65)
		root.add_child(button)
	y += 78.0
	caption(root, "메달: 빈 원, 완성, 긴 이름 / 하트 / 토스트" if ko else "Medal: empty, done, long name / hearts / toasts", y)
	y += 26.0
	var medals: Array = [["", ""], ["weather", "날씨" if ko else "Weather"], ["wrapped_foods", "다리가 여덟 개 이상" if ko else "Wrapped and Stuffed Foods"]]
	for index: int in medals.size():
		var medal := MedalView.new()
		root.add_child(medal)
		medal.configure(58, Vector2(88.5, 30), language)
		medal.position = Vector2(24 + index * 92.5, y)
		if medals[index][0] != "":
			medal.complete(medals[index][0], medals[index][1], ["rainbow", "cloud_with_lightning", "snowflake", "tornado"], false)
	for index: int in 4:
		var heart: TextureRect = Art.picture(Art.play("heart_empty" if index < 2 else "heart_full"), Vector2(22, 22))
		heart.position = Vector2(292 + index * 23, y + 4)
		root.add_child(heart)
	y += 100.0
	var toasts: Array = [["info", "이미 해 본 조합이에요" if ko else "Already tried", Color.WHITE], ["yellow", "한 장만 달라요!" if ko else "One away!", Fonts.INK], ["red", "이대로는 풀 수 없어요" if ko else "No way through from here", Color.WHITE]]
	var x: float = 10.0
	for toast: Array in toasts:
		var plate: NinePatchRect = Art.plate(Art.play("toast_" + str(toast[0])), [18, 18, 18, 22])
		var label: Label = Fonts.text(toast[1], Fonts.display(700), 13, toast[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var width: float = Fonts.display(700).get_string_size(toast[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 26.0
		plate.size = Vector2(width, 40)
		label.size = Vector2(width, 36)
		plate.add_child(label)
		plate.position = Vector2(x, y)
		root.add_child(plate)
		x += width + 6.0
	return root


func caption(root: Control, text: String, y: float) -> void:
	var label: Label = Fonts.text(text, Fonts.body(600), 12)
	Fonts.shade(label)
	label.position = Vector2(14, y)
	root.add_child(label)
