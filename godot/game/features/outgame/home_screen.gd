extends MarginContainer
## 홈(SCR-002). 위: 설정과 알림함(왼쪽), 코인 칩(오른쪽). 가운데: 스테이지 카드(번호, 등급, 모은 별, 다음 판의 뒷면 네 장)와 주 버튼.
## 그 아래 일일 도전 카드(날짜, 상태, 연속 기록), 아래 줄은 도감, 상점, 출석의 원형 버튼. 받을 것이 있는 버튼은 2초 주기로 맥동한다.
## 문구와 상태는 bootstrap(host)과 실행 상태(host.session)에서 읽고, 누르면 host의 경로를 연다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const SIDE := 18
const TOP := 10
const BOTTOM := 14
const STAGE_TITLE := 34
const BACK_CARD := Vector2(54, 74)
const BACK_TILT: Array[float] = [-7.0, -2.5, 2.5, 7.0]
## 주 버튼: 몸통 250×58에 흰 테 3과 옆면 7을 더한 크기.
const PRIMARY_SIZE := Vector2(256, 68)
const DAILY_HEIGHT := 80
const PULSE_PERIOD := 2.0
const PULSE_SCALE := 1.07
## 등급 이름(GDD 진행 절).
const TIERS := {1: ["Easy", "쉬움"], 2: ["Normal", "보통"], 3: ["Tricky", "도전"], 4: ["Hard", "어려움"], 5: ["Expert", "고수"]}

var host: Control
## 홈 가운데 스테이지 카드가 보이는 스테이지 번호(검수용).
var stage_number: int = 0
## 받을 것이 있어 맥동하는 버튼 이름(검수용).
var pulsing: Array[String] = []

var _session: RefCounted


func _ready() -> void:
	name = "home_screen"
	_session = host.session
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var insets: Vector2 = host._safe_insets()
	add_theme_constant_override("margin_left", SIDE)
	add_theme_constant_override("margin_right", SIDE)
	add_theme_constant_override("margin_top", TOP + int(insets.x))
	add_theme_constant_override("margin_bottom", BOTTOM + int(insets.y))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_top_bar())
	column.add_child(_space(1.0))
	column.add_child(_stage_card())
	column.add_child(_gap(14))
	column.add_child(_primary())
	column.add_child(_gap(18))
	column.add_child(_daily_card())
	column.add_child(_space(1.2))
	column.add_child(_menu_row())


func _t(en: String, ko: String) -> String:
	return host.tr_text(en, ko)


func _space(ratio: float) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_stretch_ratio = ratio
	node.custom_minimum_size.y = 8
	return node


func _gap(height: float) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size.y = height
	return node


# ---- 위 줄 ----

func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.name = "top_bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 8)
	bar.custom_minimum_size.y = 48
	var settings: TextureButton = Ui.hud_button("settings", Art.outgame("icon_settings"), func() -> void: host._open("settings"))
	settings.tooltip_text = _t("Settings", "설정")
	bar.add_child(settings)
	var inbox: TextureButton = Ui.hud_button("inbox", Art.outgame("icon_inbox"), func() -> void: host._open("inbox"))
	inbox.tooltip_text = _t("Inbox", "알림함")
	var waiting: int = host.inbox_waiting()
	if waiting > 0:
		var badge: Control = Ui.badge(str(waiting))
		badge.position = Vector2(32, -6)
		inbox.add_child(badge)
	bar.add_child(inbox)
	var filler := Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(filler)
	var chip: PanelContainer = Ui.coin_chip("coins", true)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.set_value(_session.player.coins(), false)
	chip.add_pressed.connect(func() -> void: host._open("shop"))
	bar.add_child(chip)
	return bar


# ---- 스테이지 카드와 주 버튼 ----

func _stage_card() -> Control:
	var player: RefCounted = _session.player
	stage_number = player.stage()
	var card: PanelContainer = Ui.panel([16, 14, 16, 22])
	card.name = "home_stage"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var title: Label = Ui.heading(_t("Stage %d", "스테이지 %d") % stage_number, STAGE_TITLE)
	title.name = "stage_title"
	box.add_child(title)
	var facts := HBoxContainer.new()
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	facts.add_theme_constant_override("separation", 12)
	box.add_child(facts)
	var tier: Array = TIERS.get(Difficulty.journey_tier(stage_number), TIERS[1])
	var pill := PanelContainer.new()
	pill.name = "tier"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", Art.box(Art.play("name_tag"), [9, 9, 9, 11], [12, 2, 12, 5]))
	var tier_label: Label = Fonts.text(tier[1] if host.language() == "ko" else tier[0], Fonts.display(700), Ui.sized(15))
	Fonts.shade(tier_label, Color(0.63, 0.16, 0.12, 0.45), 1)
	pill.add_child(tier_label)
	facts.add_child(pill)
	var stars := HBoxContainer.new()
	stars.name = "stars"
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_theme_constant_override("separation", 4)
	var star: TextureRect = Art.picture(Art.play("star_full"), Vector2(24, 24))
	star.custom_minimum_size = Vector2(24, 24)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.add_child(star)
	var count: Label = Fonts.text(str(player.total_stars()), Fonts.display(700), Ui.sized(18), Fonts.INK)
	count.name = "star_count"
	stars.add_child(count)
	facts.add_child(stars)
	# 다음 판: 뒤집힌 카드 네 장(고른 카드 뒷면).
	var backs := Control.new()
	backs.name = "next_backs"
	backs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backs.custom_minimum_size = Vector2(0, BACK_CARD.y + 14)
	box.add_child(backs)
	var views: Array[Control] = []
	for index: int in BACK_TILT.size():
		var view: Control = CardView.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backs.add_child(view)
		view.configure(BACK_CARD, 30.0, host.language(), false)
		view.set_face_down(true)
		view.clip_back_to_shape()
		view.pivot_offset = BACK_CARD / 2.0
		view.rotation_degrees = BACK_TILT[index]
		views.append(view)
	backs.resized.connect(func() -> void:
		var pitch: float = BACK_CARD.x + 10.0
		var left: float = (backs.size.x - pitch * views.size() + 10.0) / 2.0
		for index: int in views.size():
			views[index].position = Vector2(left + pitch * index, 4.0 + absf(BACK_TILT[index]) * 0.6))
	return card


func _primary() -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text: String = _t("Continue", "이어 하기") if _session.player.has_run() else _t("Play Stage %d", "스테이지 %d 시작") % stage_number
	var play: Button = Ui.button("play", text, true, func() -> void: host._open("play"), null, Vector2.ZERO, 214.0, [25, 22, 20], PRIMARY_SIZE.y)
	play.custom_minimum_size = PRIMARY_SIZE
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(play)
	# 상시 모션: 주 행동이 숨 쉬고 밝은 띠가 지나간다. 트리에 들어간 뒤에 건다.
	play.ready.connect(func() -> void:
		Juice.idle_pulse(play)
		Juice.shine(play), CONNECT_ONE_SHOT)
	return holder


# ---- 일일 도전 카드 ----

func _daily_card() -> Control:
	var player: RefCounted = _session.player
	var today: String = _session.services.clock.today()
	var done: Dictionary = player.daily_result(today)
	var button := Button.new()
	button.name = "daily"
	button.focus_mode = Control.FOCUS_NONE
	# 세 줄 글(제목, 날짜, 상태)이 큰 글자에서도 판 안에 들어가는 높이.
	button.custom_minimum_size.y = DAILY_HEIGHT + Ui.text_bonus * 3
	var plate: StyleBoxTexture = Art.box(Art.skin("ui_panel"), Ui.PANEL_MARGINS, [0, 0, 0, 0])
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, plate)
	button.pressed.connect(func() -> void: host._open("daily"))
	button.button_down.connect(Juice.press_punch.bind(button, 0.97, 0.1))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)
	var icon: TextureRect = Art.picture(Art.outgame("round_daily"), Vector2(46, 48))
	icon.custom_minimum_size = Vector2(46, 48)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var title: Label = Fonts.text(_t("Daily Challenge", "일일 도전"), Fonts.display(700), Ui.sized(18), Fonts.INK)
	text.add_child(title)
	var date: Label = Fonts.text(host.date_text(today), Fonts.body(500), Ui.sized(13), Color("6a6a9a"))
	date.name = "daily_date"
	text.add_child(date)
	var status: String
	if not done.is_empty():
		status = _t("Done · %d mistakes · %s", "완료 · 실수 %d · %s") % [int(done["mistakes"]), host.clock_text(int(done["seconds"]))]
	elif player.has_run() and player.run()["mode"] == "daily":
		status = _t("In progress", "푸는 중")
	else:
		status = _t("Today's board is waiting", "오늘의 판이 기다려요")
	var state: Label = Fonts.text(status, Fonts.body(600), Ui.sized(13), Color("2f9a4c") if not done.is_empty() else Fonts.INK)
	state.name = "daily_status"
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(state)
	var streak := VBoxContainer.new()
	streak.name = "streak"
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak.alignment = BoxContainer.ALIGNMENT_CENTER
	streak.add_theme_constant_override("separation", -2)
	row.add_child(streak)
	var flame: TextureRect = Art.picture(Art.outgame("icon_flame"), Vector2(26, 26))
	flame.custom_minimum_size = Vector2(26, 26)
	flame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	streak.add_child(flame)
	var days: Label = Fonts.text(str(player.daily_streak(today)), Fonts.display(700), Ui.sized(16), Fonts.INK)
	days.name = "streak_days"
	days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak.add_child(days)
	# 미완료는 빨간 점, 완료는 초록 체크.
	var mark: TextureRect
	if done.is_empty():
		mark = Ui.badge()
		mark.name = "daily_dot"
		mark.position = Vector2(-4, -4)
	else:
		mark = Art.picture(Art.play("tick"), Vector2(24, 26))
		mark.name = "daily_tick"
		mark.position = Vector2(-6, -6)
	button.add_child(mark)
	return button


# ---- 아래 줄 ----

func _menu_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "menu_row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var album: TextureButton = Ui.round_button("album", Art.outgame("round_album"), _t("Album", "도감"), func() -> void: host._open("album"))
	row.add_child(album)
	var shop: TextureButton = Ui.round_button("shop", Art.outgame("round_shop"), _t("Shop", "상점"), func() -> void: host._open("shop"))
	row.add_child(shop)
	var attendance: TextureButton = Ui.round_button("attendance", Art.outgame("round_attendance"), _t("Check-in", "출석"), func() -> void: host.open_attendance())
	row.add_child(attendance)
	if host.attendance_waiting():
		_attention(attendance)
	return row


## 받을 것이 있는 버튼: 배지를 달고 2초 주기로 살짝 커졌다 돌아온다.
func _attention(button: TextureButton) -> void:
	var badge: Control = Ui.badge("!")
	badge.position = Vector2(62, -4)
	button.add_child(badge)
	pulsing.append(str(button.name))
	Juice.idle_pulse(button.get_node("disc"), PULSE_SCALE, PULSE_PERIOD)
