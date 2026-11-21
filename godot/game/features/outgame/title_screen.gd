extends Control
## 타이틀(SCR-001). 로고와 부제, 카드 네 장 부채꼴과 범주 이름표, 실제 준비 단계만큼 차는 막대, 상태 문구, 시작 버튼, 버전과 제작사.
## 준비 단계는 bootstrap이 정한다(host.title_progress()). 이 화면은 그 값을 그리기만 하고, 다시 그릴 때는 refresh()로 값만 바꾼다.
## 모션: 로고가 위에서 내려와 한 번 튀고, 카드가 준비되면 네 장이 차례로 펼쳐진다. 움직임 줄이기에서는 정지 상태로 바로 그린다.
## 배치 수치는 기준 그림(docs/game-design/ui/direction/b-title-*.png)과 그 원본(mock-source.html의 .title 규칙)에서 왔다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

## 기준 화면(390×844)에서 로고 위, 아래 블록(막대, 문구, 버튼, 표기)의 높이와 아래 여백.
const BASE_HEIGHT := 844.0
const LOGO_TOP := 110.0
const LOGO_SIZE := {"ko": 62, "en": 58}
const LOGO_SHADE := Color("4e54c8")
const SUB_GAP := 10.0
const SUB_SIZE := 16
const BOTTOM_PAD := 30.0
const BAR_WIDTH := 250.0
const BAR_HEIGHT := 18.0
const BAR_INSET := 3.0
const STATUS_GAP := 7.0
const STATUS_SIZE := 13
const BUTTON_GAP := 16.0
## 시작 버튼의 몸통(250×58). 그림은 몸통 바깥으로 흰 테 3과 아래 옆면 7을 더 그려서 노드는 그만큼 크다(플레이 화면의 묶기 버튼과 같다).
const BUTTON_BODY := Vector2(250, 58)
const BUTTON_SIZE := BUTTON_BODY + Vector2(6, 10)
const FOOT_GAP := 16.0
const FOOT_SIZE := 11
## 부채꼴: 330×250 상자 안에서 카드의 왼쪽 위치, 기울기, 아래로 내림. 뒷면 두 장은 양옆에 24도로 놓인다.
const FAN_SIZE := Vector2(330, 250)
const FAN_CARD := Vector2(90, 120)
const FAN_CARD_TOP := 44.0
const FAN_ICON := 52.0
const FAN_CARDS := [["banana", 14.0, -13.0, 16.0], ["lemon", 84.0, -4.0, 0.0], ["grapes", 156.0, 4.0, 0.0], ["strawberry", 226.0, 13.0, 16.0]]
const FAN_BACK := Vector2(86, 116)
const FAN_BACKS := [[26.0, -24.0], [218.0, 24.0]]
const FAN_BACK_TOP := 26.0
const FAN_CATEGORY := "fruits"
const RIBBON_HEIGHT := 47.0
const RIBBON_PAD := 22.0
const RIBBON_BOTTOM := 8.0
const RIBBON_SIZE := 17
## 모션 시간(초).
const LOGO_DROP := 0.55
const CARD_STAGGER := 0.08
const CARD_SPREAD := 0.32

var host: Control
## 지금 그린 준비 상태(save, cards, privacy, ready, error).
var stage: String = ""

var _logo: Label
var _sub: Label
var _fan: Control
var _fan_cards: Array[Control] = []
var _ribbon: NinePatchRect
var _ribbon_label: Label
var _track: NinePatchRect
var _fill: NinePatchRect
var _status: Label
var _start: Button
var _retry: Button
var _foot: Label
var _fill_ratio: float = 0.0
var _fill_tween: Tween
var _fan_shown: bool = false
var _language: String = ""


func _ready() -> void:
	name = "title_screen"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_logo = Fonts.text("", Fonts.display(700), LOGO_SIZE["en"])
	_logo.name = "logo"
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.shade(_logo, LOGO_SHADE, 5)
	add_child(_logo)
	_sub = Fonts.text("", Fonts.display(600), SUB_SIZE)
	_sub.name = "subtitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.shade(_sub)
	add_child(_sub)
	_fan = Control.new()
	_fan.name = "fan"
	_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fan.size = FAN_SIZE
	_fan.visible = false
	add_child(_fan)
	_track = Art.plate(Art.outgame("bar_track"), [9, 9, 9, 9])
	_track.name = "bar"
	add_child(_track)
	_fill = Art.plate(Art.outgame("bar_fill"), [6, 6, 6, 6])
	_fill.name = "fill"
	_track.add_child(_fill)
	_status = Fonts.text("", Fonts.display(600), STATUS_SIZE)
	_status.name = "status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.shade(_status)
	add_child(_status)
	_start = Ui.button("start", " ", true, func() -> void: host._start(), null, Vector2.ZERO, 210.0, [25, 22, 20], BUTTON_SIZE.y)
	_start.size_flags_horizontal = Control.SIZE_FILL
	add_child(_start)
	_retry = Ui.button("retry", " ", true, func() -> void: host._initialize(), null, Vector2.ZERO, 210.0, [22, 20, 18], BUTTON_SIZE.y)
	_retry.size_flags_horizontal = Control.SIZE_FILL
	add_child(_retry)
	_foot = Fonts.text("", Fonts.body(500), FOOT_SIZE, Color(1, 1, 1, 0.75))
	_foot.name = "version"
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_foot)
	resized.connect(_arrange)
	refresh()
	_drop_logo()


## 준비 상태와 언어를 다시 읽어 그린다.
func refresh() -> void:
	if host == null:
		return
	var progress: Dictionary = host.title_progress()
	var language: String = host.language()
	if language != _language:
		_language = language
		_logo.text = host.tr_text("Four Alike", "끼리끼리")
		_logo.add_theme_font_size_override("font_size", LOGO_SIZE["ko" if language == "ko" else "en"])
		_sub.text = host.tr_text("HIDDEN CATEGORY CARDS", "연상 카드 퍼즐")
		Ui.set_button_text(_start, host.tr_text("Play", "시작하기"))
		Ui.set_button_text(_retry, host.tr_text("Try again", "다시 시도"))
		_foot.text = "v%s · %s" % [str(ProjectSettings.get_setting("application/config/version", "1.0.0")), host.studio_name]
		if _fan_shown:
			_build_fan()
	stage = progress["stage"]
	_status.text = _status_text(progress)
	_status.add_theme_color_override("font_color", Color("fff1c8") if stage == "error" else Color.WHITE)
	_start.visible = stage == "ready"
	_retry.visible = stage == "error"
	_track.visible = stage != "error"
	_set_fill(float(progress["done"]) / float(progress["total"]))
	if progress["cards"] and not _fan_shown:
		_fan_shown = true
		_build_fan()
		_spread_fan()
	_arrange()


func _status_text(progress: Dictionary) -> String:
	match progress["stage"]:
		"save":
			return host.tr_text("Loading your save", "저장 불러오는 중")
		"cards":
			return host.tr_text("Preparing cards", "카드 준비 중")
		"privacy":
			return host.tr_text("Waiting for your privacy choice", "개인정보 선택을 기다리는 중")
		"error":
			return host.title_error_text()
	return host.tr_text("Ready", "준비 완료")


## 막대의 채움. 확인된 완료량까지만 짧게 따라간다(앞서지 않는다).
func _set_fill(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if is_equal_approx(ratio, _fill_ratio):
		return
	var from: float = _fill_ratio
	_fill_ratio = ratio
	if _fill_tween != null:
		_fill_tween.kill()
	if Juice.reduced_motion or from > ratio:
		_place_fill(ratio)
		return
	_fill_tween = create_tween()
	_fill_tween.tween_method(_place_fill, from, ratio, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _place_fill(ratio: float) -> void:
	var inner: Vector2 = Vector2(BAR_WIDTH, BAR_HEIGHT) - Vector2.ONE * BAR_INSET * 2.0
	_fill.visible = ratio > 0.0
	_fill.position = Vector2.ONE * BAR_INSET
	_fill.size = Vector2(maxf(inner.y, inner.x * ratio), inner.y)
	_fill.set_meta("ratio", ratio)


## 지금 채워진 막대의 비율(검수용).
func fill_ratio() -> float:
	return _fill_ratio


func _build_fan() -> void:
	for child: Node in _fan.get_children():
		_fan.remove_child(child)
		child.queue_free()
	_fan_cards.clear()
	for spec: Array in FAN_BACKS:
		var back: Control = CardView.new()
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fan.add_child(back)
		back.configure(FAN_BACK, FAN_ICON, _language, false)
		back.set_face_down(true)
		back.clip_back_to_shape()
		back.position = Vector2(spec[0], FAN_BACK_TOP)
		back.pivot_offset = FAN_BACK / 2.0
		back.rotation_degrees = spec[1]
		back.modulate.a = 0.9
		back.set_meta("rest", [back.position, back.rotation_degrees])
		_fan_cards.append(back)
	var catalog: RefCounted = host.session.catalog
	for spec: Array in FAN_CARDS:
		var card: Control = CardView.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fan.add_child(card)
		card.configure(FAN_CARD, FAN_ICON, _language, false)
		card.show_card(spec[0], catalog.item_icon(spec[0]), catalog.item_name(spec[0], _language))
		card.name = "fan_" + str(spec[0])
		card.position = Vector2(spec[1], FAN_CARD_TOP + spec[3])
		card.pivot_offset = FAN_CARD / 2.0
		card.rotation_degrees = spec[2]
		card.set_meta("rest", [card.position, card.rotation_degrees])
		_fan_cards.append(card)
	_ribbon = Art.plate(Art.outgame("ribbon"), [19, 19, 19, 21])
	_ribbon.name = "ribbon"
	_fan.add_child(_ribbon)
	_ribbon_label = Fonts.text(catalog.category_name(FAN_CATEGORY, _language), Fonts.display(700), RIBBON_SIZE)
	_ribbon_label.name = "ribbon_label"
	_ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Fonts.shade(_ribbon_label, Color(0.63, 0.16, 0.12, 0.45))
	_ribbon.add_child(_ribbon_label)
	var width: float = _ribbon_label.get_theme_font("font").get_string_size(_ribbon_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, RIBBON_SIZE).x + RIBBON_PAD * 2.0 + 6.0
	_ribbon.size = Vector2(width, RIBBON_HEIGHT)
	# 몸통의 아래 끝이 상자 아래에서 8 위에 오게 놓는다. 그림은 몸통 아래로 흰 테 3과 옆면 4를 더 그린다.
	_ribbon.position = Vector2((FAN_SIZE.x - width) / 2.0, FAN_SIZE.y - RIBBON_BOTTOM - RIBBON_HEIGHT + 7.0)
	_ribbon_label.position = Vector2(0, 2)
	_ribbon_label.size = Vector2(width, RIBBON_HEIGHT - 8.0)
	_fan.visible = true


## 카드 네 장이 가운데에서 차례로 펼쳐진다. 이름표는 마지막에 튀어나온다.
func _spread_fan() -> void:
	if Juice.reduced_motion:
		return
	var center: Vector2 = FAN_SIZE / 2.0
	for index: int in _fan_cards.size():
		var card: Control = _fan_cards[index]
		var rest: Array = card.get_meta("rest")
		card.position = center - card.size / 2.0 + Vector2(0, 30)
		card.rotation_degrees = 0.0
		card.modulate.a = 0.0
		var tween: Tween = card.create_tween().set_parallel(true)
		var delay: float = index * CARD_STAGGER
		tween.tween_property(card, "position", rest[0], CARD_SPREAD).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "rotation_degrees", rest[1], CARD_SPREAD).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "modulate:a", 0.9 if index < FAN_BACKS.size() else 1.0, CARD_SPREAD * 0.6).set_delay(delay)
	_ribbon.scale = Vector2.ZERO
	_ribbon.pivot_offset = _ribbon.size / 2.0
	var pop: Tween = _ribbon.create_tween()
	pop.tween_interval(_fan_cards.size() * CARD_STAGGER + CARD_SPREAD * 0.6)
	pop.tween_property(_ribbon, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## 로고가 위에서 내려와 한 번 튄다.
func _drop_logo() -> void:
	if Juice.reduced_motion:
		return
	_logo.set_meta("drop", -70.0)
	_logo.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(func(offset: float) -> void:
		_logo.set_meta("drop", offset)
		_arrange(), -70.0, 0.0, LOGO_DROP).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_logo, "modulate:a", 1.0, LOGO_DROP * 0.4)
	_sub.modulate.a = 0.0
	tween.tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(LOGO_DROP * 0.6)


## 자리를 잡는다. 아래 블록은 화면 아래(안전 영역 위)에 붙이고, 로고 위 여백은 화면 높이에 비례해 줄인다.
## 부채꼴은 부제와 아래 블록 사이 가운데에 놓고, 남는 높이가 모자라면 줄여 그린다.
func _arrange() -> void:
	if host == null:
		return
	var insets: Vector2 = host._safe_insets()
	var w: float = size.x
	var h: float = size.y
	var logo_size: int = LOGO_SIZE["ko" if _language == "ko" else "en"]
	var logo_top: float = insets.x + LOGO_TOP * clampf((h - insets.x - insets.y) / BASE_HEIGHT, 0.6, 1.0)
	var drop: float = float(_logo.get_meta("drop", 0.0))
	_logo.position = Vector2(0, logo_top + drop - logo_size * 0.12)
	_logo.size = Vector2(w, logo_size * 1.3)
	_sub.position = Vector2(0, logo_top + logo_size + SUB_GAP)
	_sub.size = Vector2(w, SUB_SIZE * 1.4)
	var sub_bottom: float = _sub.position.y + SUB_SIZE * 1.3

	var foot_h: float = FOOT_SIZE * 1.4
	var block: float = BAR_HEIGHT + STATUS_GAP + STATUS_SIZE * 1.3 + BUTTON_GAP + BUTTON_BODY.y + FOOT_GAP + foot_h
	var top: float = h - insets.y - BOTTOM_PAD - block
	_track.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_track.position = Vector2((w - BAR_WIDTH) / 2.0, top)
	_place_fill(float(_fill.get_meta("ratio", _fill_ratio)))
	_status.position = Vector2(0, top + BAR_HEIGHT + STATUS_GAP)
	_status.size = Vector2(w, STATUS_SIZE * 1.4)
	var button_top: float = _status.position.y + STATUS_SIZE * 1.3 + BUTTON_GAP
	for button: Button in [_start, _retry]:
		button.size = BUTTON_SIZE
		button.position = Vector2((w - BUTTON_SIZE.x) / 2.0, button_top - 3.0)
	_foot.position = Vector2(0, button_top + BUTTON_BODY.y + FOOT_GAP)
	_foot.size = Vector2(w, foot_h)

	var room: float = top - sub_bottom
	var scale_down: float = clampf(room / (FAN_SIZE.y + 24.0), 0.6, 1.0)
	_fan.scale = Vector2.ONE * scale_down
	_fan.position = Vector2((w - FAN_SIZE.x * scale_down) / 2.0, sub_bottom + (room - FAN_SIZE.y * scale_down) / 2.0)
