extends VBoxContainer
## 일일 도전 진입 화면(SCR-008). 이번 달 달력(성공은 초록 체크, 지난 미완료는 빈 원, 오늘은 노란 테), 연속 기록,
## 고른 날의 판 카드. 완료한 날은 결과(실수, 임시 칸 사용, 걸린 시간, 완성 순서)와 결과 복사, 풀 수 있는 날은 시작 버튼이다.
## 지난 날짜도 풀 수 있지만 연속 기록에는 들어가지 않는다고 알린다. 판은 host.launch_daily(date)가 띄운다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const WEEKDAYS := [["S", "일"], ["M", "월"], ["T", "화"], ["W", "수"], ["T", "목"], ["F", "금"], ["S", "토"]]
const GAP := 5.0
const CELL_MAX := 40.0
## 완료 체크는 칸의 오른쪽 위 모서리에 걸쳐 칸 밖으로 TICK_OVERHANG만큼 나간다. 달력 양옆에 같은 여백을 두어
## 맨 오른쪽 열(토요일)의 체크가 목록의 가장자리에서 잘리지 않게 한다.
const TICK_SIZE := Vector2(18, 19)
const TICK_OVERHANG := 5.0
const MUTED := Color("8a8db5")
## 공유 글의 범주 난도별 네모(난도 1~4).
const TIER_SQUARES := ["🟨", "🟩", "🟦", "🟪"]

var host: Control
## 고른 날짜. 처음에는 오늘이다.
var selected: String = ""

var _session: RefCounted
var _today: String = ""
var _calendar: GridContainer
var _detail: Control


func _ready() -> void:
	name = "daily_screen"
	_session = host.session
	_today = _session.services.clock.today()
	if selected.is_empty():
		selected = _today
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()


func _t(en: String, ko: String) -> String:
	return host.tr_text(en, ko)


func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.name = "daily_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(box)
	box.add_child(_month_header())
	var inset := MarginContainer.new()
	inset.name = "calendar_inset"
	inset.mouse_filter = Control.MOUSE_FILTER_PASS
	inset.add_theme_constant_override("margin_left", int(TICK_OVERHANG))
	inset.add_theme_constant_override("margin_right", int(TICK_OVERHANG))
	box.add_child(inset)
	var month := VBoxContainer.new()
	month.mouse_filter = Control.MOUSE_FILTER_PASS
	month.add_theme_constant_override("separation", 10)
	inset.add_child(month)
	month.add_child(_weekday_row())
	_calendar = _month_grid()
	month.add_child(_calendar)
	box.add_child(_streak_row())
	_detail = _day_card(selected)
	box.add_child(_detail)


func _month_header() -> Control:
	var label: Label = Ui.heading(host.month_text(_today), 20)
	label.name = "month"
	return label


func _weekday_row() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(GAP))
	for pair: Array in WEEKDAYS:
		var label: Label = Fonts.text(pair[1] if host.language() == "ko" else pair[0], Fonts.display(600), Ui.sized(12), MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	return row


func _month_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "calendar"
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	var first: String = _today.substr(0, 8) + "01"
	for blank: int in Daily.weekday(first):
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(spacer)
	var date: String = first
	while Daily.same_month(date, _today):
		grid.add_child(_day_cell(date))
		date = Daily.add_days(date, 1)
	return grid


## 날짜 칸. 누를 수 있는 날(오늘, 이번 달의 지난 날 가운데 열린 날)은 버튼이고 나머지는 흐린 칸이다.
func _day_cell(date: String) -> Control:
	var player: RefCounted = _session.player
	var number: int = date.substr(8, 2).to_int()
	var open: bool = Daily.challenge_number(date) > 0 and Daily.days_between(date, _today) >= 0
	var done: bool = not player.daily_result(date).is_empty()
	var cell := Button.new()
	cell.name = "day_" + date
	cell.focus_mode = Control.FOCUS_NONE
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, CELL_MAX + 4.0)
	var art: String = "day_dim"
	if open:
		art = "day_today" if date == _today else ("day_selected" if date == selected else "day_cell")
	var margins: Array = [12, 12, 12, 16] if open else [12, 12, 12, 12]
	var plate: StyleBoxTexture = Art.box(Art.outgame(art), margins, [0, 0, 0, 4])
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(style, plate)
	cell.disabled = not open
	cell.set_meta("state", "done" if done else ("open" if open else "closed"))
	var label: Label = Fonts.text(str(number), Fonts.display(700), Ui.sized(15), Fonts.INK if open else Color("b4b9d8"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -4
	cell.add_child(label)
	if done:
		var tick: TextureRect = Art.picture(Art.play("tick"), TICK_SIZE)
		tick.name = "tick"
		cell.add_child(tick)
		cell.resized.connect(func() -> void: tick.position = Vector2(cell.size.x - TICK_SIZE.x + TICK_OVERHANG, -6))
	elif open and date != _today:
		var ring: TextureRect = Art.picture(Art.outgame("ring"), Vector2(12, 12))
		ring.name = "ring"
		cell.add_child(ring)
		cell.resized.connect(func() -> void: ring.position = Vector2(cell.size.x - 12, -3))
	if open:
		cell.pressed.connect(_select.bind(date))
		cell.button_down.connect(Juice.press_punch.bind(cell, 0.92, 0.1))
	return cell


func _select(date: String) -> void:
	selected = date
	rebuild()


func _streak_row() -> Control:
	var player: RefCounted = _session.player
	var row := HBoxContainer.new()
	row.name = "streak"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var flame: TextureRect = Art.picture(Art.outgame("icon_flame"), Vector2(26, 26))
	flame.custom_minimum_size = Vector2(26, 26)
	row.add_child(flame)
	var streak: int = player.daily_streak(_today)
	var now: Label = Fonts.text(_t("%d-day streak", "%d일 연속") % streak, Fonts.display(700), Ui.sized(18), Fonts.INK)
	now.name = "streak_now"
	row.add_child(now)
	var best: Label = Fonts.text(_t("Best %d", "최고 %d일") % player.daily_best(), Fonts.body(600), Ui.sized(13), MUTED)
	best.name = "streak_best"
	row.add_child(best)
	return row


## 고른 날의 판 카드.
func _day_card(date: String) -> Control:
	var player: RefCounted = _session.player
	var card: PanelContainer = Ui.panel([14, 12, 14, 18])
	card.name = "day_card"
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var number: int = Daily.challenge_number(date)
	var title: Label = Ui.heading(_t("Daily #%d", "오늘의 도전 #%d") % number if date == _today else _t("Daily #%d", "일일 도전 #%d") % number, 20)
	title.name = "day_title"
	box.add_child(title)
	var when: Label = Ui.note(host.date_text(date), 13, MUTED)
	box.add_child(when)
	var result: Dictionary = player.daily_result(date)
	if not result.is_empty():
		box.add_child(_result_rows(result))
		var copy: Button = Ui.button("copy", _t("Copy result", "결과 복사"), true, _copy.bind(date), Art.outgame("icon_copy"), Vector2(22, 22))
		box.add_child(copy)
		return card
	if player.daily_best() == 0:
		var empty: Label = Ui.note(_t("No past results yet. Start with today's board.", "아직 푼 날이 없어요. 오늘의 판부터 시작해 보세요."), 13, MUTED)
		empty.name = "no_history"
		box.add_child(empty)
	var rule: Label = Ui.note(_t("No boosters", "부스터 없이 풉니다"), 14)
	rule.name = "rule"
	box.add_child(rule)
	if date != _today:
		var note: Label = Ui.note(_t("Past days don't count toward your streak.", "지난 날짜는 연속 기록에 들어가지 않아요."), 13, Color("d4463e"))
		note.name = "past_note"
		box.add_child(note)
	var resuming: bool = player.has_run() and player.run()["mode"] == RoundMode.DAILY and player.run()["date"] == date
	var label: String = _t("Continue", "이어 하기") if resuming else (_t("Play Today", "오늘의 도전") if date == _today else _t("Play this day", "이 날 풀기"))
	var play: Button = Ui.button("play_daily", label, true, func() -> void: host.launch_daily(date))
	box.add_child(play)
	Juice.idle_pulse(play, 1.02, 1.6)
	return card


func _result_rows(result: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "result"
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 6)
	var facts := HBoxContainer.new()
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	facts.add_theme_constant_override("separation", 14)
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(facts)
	for pair: Array in [[_t("Mistakes", "실수"), str(int(result["mistakes"]))], [_t("Holds", "임시 칸"), str(int(result["holds"]))],
			[_t("Time", "시간"), host.clock_text(int(result["seconds"]))]]:
		var fact := VBoxContainer.new()
		fact.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fact.custom_minimum_size.x = 64
		fact.add_theme_constant_override("separation", -2)
		var value: Label = Ui.heading(pair[1], 20)
		fact.add_child(value)
		var caption: Label = Fonts.text(pair[0], Fonts.body(600), Ui.sized(12), MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fact.add_child(caption)
		facts.add_child(fact)
	box.add_child(Ui.note(_t("Order you solved them", "완성 순서"), 12, MUTED))
	var order := HFlowContainer.new()
	order.name = "order"
	order.alignment = FlowContainer.ALIGNMENT_CENTER
	order.add_theme_constant_override("h_separation", 6)
	order.add_theme_constant_override("v_separation", 6)
	order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(order)
	for index: int in result["order"].size():
		var tag := PanelContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_stylebox_override("panel", Art.box(Art.play("name_tag"), [9, 9, 9, 11], [10, 2, 10, 5]))
		var name_label: Label = Fonts.text("%d %s" % [index + 1, _session.catalog.category_name(result["order"][index], host.language())],
			Fonts.label(host.language()), 13)
		tag.add_child(name_label)
		order.add_child(tag)
	return box


## 결과를 글자로 복사한다. 범주 이름 대신 난도 색 네모로 완성 순서를 보여 정답을 드러내지 않는다.
func _copy(date: String) -> void:
	var text: String = share_text(date)
	if host.copy_text(text):
		host.show_toast(_t("Result copied", "결과를 복사했어요"))
		_session.services.analytics.log_event("share", {"mode": RoundMode.DAILY, "level": Daily.challenge_number(date)})
	else:
		host.show_toast(_t("Could not copy. Try again.", "복사하지 못했어요. 다시 눌러 주세요."), "red")


## 공유 글: 제목과 번호, 날짜, 완성 순서의 난도 네모, 실수와 임시 칸과 시간.
func share_text(date: String) -> String:
	var result: Dictionary = _session.player.daily_result(date)
	var squares: PackedStringArray = []
	for category: String in result.get("order", []):
		squares.append(TIER_SQUARES[clampi(_session.catalog.category_tier(category), 1, 4) - 1])
	var lines: PackedStringArray = [
		_t("Four Alike Daily #%d", "끼리끼리 일일 도전 #%d") % Daily.challenge_number(date), date, "".join(squares),
		_t("Mistakes %d · Holds %d · %s", "실수 %d · 임시 칸 %d · %s") % [int(result.get("mistakes", 0)), int(result.get("holds", 0)), host.clock_text(int(result.get("seconds", 0)))],
	]
	return "\n".join(lines)
