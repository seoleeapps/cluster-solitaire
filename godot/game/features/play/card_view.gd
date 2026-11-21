extends Control
## 카드 한 장. 카드 전체가 누르는 영역이다.
## 상태: 기본, 눌림(1.06배 뒤 복귀), 선택(노란 테, 7 들림, 체크 배지), 힌트(하늘색 테와 맥동), 흔들림, 뒤집힘(뒷면), 끄는 중.
## 누르기와 끌기를 구분해 알리기만 하고, 무엇을 할지는 화면이 정한다.

signal tapped(view: Control)
signal drag_started(view: Control)
signal drag_moved(view: Control, at: Vector2)
signal drag_ended(view: Control, at: Vector2)

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const ICON_DIR := "res://game/assets/icons/"
## 선택한 카드가 들리는 높이와, 끌기로 보기 시작하는 이동 거리.
const LIFT := 7.0
const DRAG_START := 12.0
## 카드 판: 흰 몸통 아래로 옆면 6과 그림자 3이 더 그려진다. 선택과 힌트 판은 테 4가 사방으로 더 나간다.
const FACE_MARGINS := [20, 20, 20, 29]
const FACE_BELOW := 9.0
const RING_MARGINS := [24, 24, 24, 30]
const RING := 4.0
const RING_BELOW := 10.0
## 떠 있는 카드의 번진 그림자: 아래로 16, 번짐 14.
const SHADOW_DROP := 16.0
const SHADOW_BLUR := 14.0
const SHADOW_MARGINS := [34, 34, 34, 34]
## 뒷면의 흰 안쪽 테.
const BACK_EDGE := 4.0
## 카드 안쪽 여백(위, 옆, 아래)과 아이콘과 이름 사이.
const PAD_TOP := 6.0
const PAD_SIDE := 3.0
const PAD_BOTTOM := 7.0
const ICON_GAP := 5.0
## 이름 글자 크기: 언어별 기본값과 줄일 수 있는 최소. 큰 글자 설정은 한 단계만 키운다.
const NAME_SIZE := {"ko": 15, "en": 14}
const NAME_MIN := 13
## 긴 영어 낱말에 차례로 써 보는 서체 폭(100이 기본).
const NAME_STRETCHES: Array[int] = [100, 90, 80, 75]
const NAME_STRETCH_FIXED: Array[int] = [100]
const NAME_LINES := 2
## 이름의 줄 높이는 글자 크기의 이 배수다(시안의 값).
const NAME_LINE_RATIO := 1.1
const PRESS_SCALE := 1.06
const FLIP_SECONDS := 0.16
const MOVE_Z := 80
const SELECTED_Z := 2

var card_id: String = ""
var selected: bool = false
var hinted: bool = false
var face_down: bool = false
## 이름이 두 줄 안에 잘리지 않고 들어갔는지.
var name_fits: bool = true
var name_label: Label
## 누를 수 있는지 묻는 함수(연출 중과 안내 단계 밖이면 false). 비어 있으면 늘 누를 수 있다.
var gate: Callable
## 끌어서 옮길 수 있는 카드인지(열 맨 앞 카드).
var draggable: Callable

var _body: Control
var _shadow: NinePatchRect
var _plate: NinePatchRect
var _back: NinePatchRect
var _dots_clip: Control
var _icon: TextureRect
var _tick: TextureRect
var _icon_size: float = 54.0
var _language: String = "en"
var _large_text: bool = false
var _display_name: String = ""
## 이름 칸: 배치에 쓰는 높이(글자 크기의 1.1배씩), 글꼴의 줄 상자가 그보다 높아서 위로 당기는 양, Label의 실제 높이.
var _name_height: float = 16.0
var _name_trim: float = 0.0
var _label_height: float = 16.0
var _pressing: bool = false
var _dragging: bool = false
var _press_at: Vector2
var _lift_tween: Tween
var _hint_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_shadow = Art.plate(Art.play("soft_shadow"), SHADOW_MARGINS)
	_shadow.visible = false
	_body.add_child(_shadow)
	_back = Art.plate(Art.play("card_back"), FACE_MARGINS)
	_body.add_child(_back)
	_dots_clip = Control.new()
	_dots_clip.clip_contents = true
	_dots_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_dots_clip)
	var dots: TextureRect = Art.picture(Art.play("card_back_dots"))
	dots.position = -Vector2.ONE * BACK_EDGE
	_dots_clip.add_child(dots)
	_plate = Art.plate(Art.play("card_face"), FACE_MARGINS)
	_body.add_child(_plate)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_icon)
	name_label = Fonts.text("", Fonts.label("en"), NAME_SIZE["en"], Fonts.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.max_lines_visible = NAME_LINES
	_body.add_child(name_label)
	_tick = Art.picture(Art.play("tick"))
	_tick.visible = false
	_body.add_child(_tick)
	resized.connect(_arrange)


## 카드의 크기와 아이콘 크기, 글자 설정을 정한다.
func configure(card_size: Vector2, icon_size: float, language: String, large_text: bool) -> void:
	_icon_size = icon_size
	_language = language
	_large_text = large_text
	size = card_size
	_arrange()


## 앞면의 카드를 정한다. 이름은 화면이 콘텐츠에서 언어에 맞게 가져온 것이다.
func show_card(id: String, icon_key: String, display_name: String) -> void:
	card_id = id
	name = "card_" + id
	_display_name = display_name
	_icon.texture = load(ICON_DIR + icon_key + ".png")
	_fit_name()


func set_face_down(value: bool) -> void:
	face_down = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	_refresh()


func set_selected(value: bool, animate: bool = true) -> void:
	if selected == value:
		return
	selected = value
	z_index = SELECTED_Z if value else 0
	_refresh()
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	var target: float = -LIFT if value else 0.0
	if not animate or Juice.reduced_motion or not is_inside_tree():
		_body.position.y = target
		_tick.scale = Vector2.ONE
		return
	_lift_tween = create_tween().set_parallel(true)
	_lift_tween.tween_property(_body, "position:y", target, 0.1 if value else 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if value:
		_tick.pivot_offset = _tick.size / 2.0
		_tick.scale = Vector2.ONE * 0.3
		_lift_tween.tween_property(_tick, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func set_hinted(value: bool) -> void:
	if hinted == value:
		return
	hinted = value
	_refresh()
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	# 테가 커졌다 줄며 맥동한다. 판을 흐리게 하면 뒤의 카드가 비쳐 보이므로 크기만 바꾼다.
	_plate.scale = Vector2.ONE
	if value and not Juice.reduced_motion and is_inside_tree():
		_plate.pivot_offset = _plate.size / 2.0
		_hint_tween = create_tween().set_loops()
		_hint_tween.tween_property(_plate, "scale", Vector2.ONE * 1.05, 0.45).set_trans(Tween.TRANS_SINE)
		_hint_tween.tween_property(_plate, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


## 뒤집는다. 가로로 접혔다가 반대 면으로 펴진다.
func flip(to_face_down: bool) -> void:
	if Juice.reduced_motion or not is_inside_tree():
		set_face_down(to_face_down)
		return
	_body.pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(_body, "scale:x", 0.0, FLIP_SECONDS / 2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(set_face_down.bind(to_face_down))
	tween.tween_property(_body, "scale:x", 1.0, FLIP_SECONDS / 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished


## 좌우로 4씩 세 번 흔든다(오답, 다섯 번째 선택, 옮길 수 없는 카드).
func shake() -> void:
	if Juice.reduced_motion or not is_inside_tree():
		return
	var tween: Tween = create_tween()
	for swing: int in 3:
		tween.tween_property(_body, "position:x", 4.0, 0.03)
		tween.tween_property(_body, "position:x", -4.0, 0.03)
	tween.tween_property(_body, "position:x", 0.0, 0.03)


## 다른 카드 위로 띄우거나(옮기는 중, 끄는 중) 제자리로 돌린다.
func set_floating(value: bool) -> void:
	z_index = MOVE_Z if value else (SELECTED_Z if selected else 0)
	_shadow.visible = value or selected


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if gate.is_valid() and not gate.call(self):
				return
			_pressing = true
			_dragging = false
			_press_at = event.global_position
			_punch()
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				drag_ended.emit(self, event.global_position)
			elif Rect2(Vector2.ZERO, size).grow(8.0).has_point(event.position):
				tapped.emit(self)
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_at) >= DRAG_START \
				and draggable.is_valid() and draggable.call(self):
			_dragging = true
			drag_started.emit(self)
		if _dragging:
			drag_moved.emit(self, event.global_position)


func _punch() -> void:
	if Juice.reduced_motion:
		return
	_body.pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(_body, "scale", Vector2.ONE * PRESS_SCALE, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, "scale", Vector2.ONE, 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _refresh() -> void:
	var ringed: bool = selected or hinted
	_back.visible = face_down
	_dots_clip.visible = face_down
	_plate.visible = not face_down
	_icon.visible = not face_down
	name_label.visible = not face_down
	_tick.visible = selected and not face_down
	_shadow.visible = selected and not face_down
	_plate.texture = Art.play("card_selected" if selected else ("card_hint" if hinted else "card_face"))
	var margins: Array = RING_MARGINS if ringed else FACE_MARGINS
	_plate.patch_margin_left = margins[0]
	_plate.patch_margin_top = margins[1]
	_plate.patch_margin_right = margins[2]
	_plate.patch_margin_bottom = margins[3]
	_arrange()


func _arrange() -> void:
	_body.size = size
	var ringed: bool = selected or hinted
	if ringed:
		_plate.position = -Vector2.ONE * RING
		_plate.size = size + Vector2(RING * 2.0, RING + RING_BELOW)
	else:
		_plate.position = Vector2.ZERO
		_plate.size = size + Vector2(0.0, FACE_BELOW)
	_back.position = Vector2.ZERO
	_back.size = size + Vector2(0.0, FACE_BELOW)
	_dots_clip.position = Vector2.ONE * BACK_EDGE
	_dots_clip.size = size - Vector2.ONE * BACK_EDGE * 2.0
	_shadow.position = Vector2(-SHADOW_BLUR, SHADOW_DROP - SHADOW_BLUR)
	_shadow.size = size + Vector2.ONE * SHADOW_BLUR * 2.0
	_tick.position = Vector2(size.x - 19.0, -10.0)
	var block: float = _icon_size + ICON_GAP + _name_height
	var top: float = PAD_TOP + maxf(0.0, (size.y - PAD_TOP - PAD_BOTTOM - block) / 2.0)
	_icon.position = Vector2((size.x - _icon_size) / 2.0, top)
	_icon.size = Vector2.ONE * _icon_size
	name_label.position = Vector2(PAD_SIDE, top + _icon_size + ICON_GAP - _name_trim)
	name_label.size = Vector2(size.x - PAD_SIDE * 2.0, _label_height)


## 이름을 폭 width의 카드에 넣는 방법을 정한다: 한 줄에, 안 되면 두 줄에 넣는다. 한 줄로는 글자를 한 단계만 줄여 보고,
## 두 줄로도 넘치면 한 단계씩 더 줄인다. 그래도 한 낱말이 폭을 넘으면 한국어는 낱말 중간에서 줄을 바꾸고,
## 영어는 서체의 폭을 한 단계씩 좁힌다(Fredoka의 폭 축).
## 결과는 {fits, size, lines, mode, stretch}다. fits가 false면 가장 작은 글자로 두 줄까지만 보이고 나머지는 잘린다.
static func fit_name(display_name: String, language: String, width: float, large_text: bool) -> Dictionary:
	var base: int = int(NAME_SIZE.get(language, NAME_SIZE["en"])) + (1 if large_text else 0)
	var stretches: Array[int] = NAME_STRETCH_FIXED if language == "ko" else NAME_STRETCHES
	for stretch: int in stretches:
		var font: Font = Fonts.label(language, stretch)
		for lines: int in [1, NAME_LINES]:
			# 한 줄로는 한 단계만 줄여 본다. 더 줄이기보다 두 줄이 읽기 쉽다.
			var smallest: int = maxi(NAME_MIN, base - 1) if lines == 1 else NAME_MIN
			for font_size: int in range(base, smallest - 1, -1):
				var modes: Array[int] = [TextServer.AUTOWRAP_WORD]
				if lines > 1 and language == "ko":
					modes.append(TextServer.AUTOWRAP_ARBITRARY)
				for mode: int in modes:
					var measured: Dictionary = _measure(display_name, font, font_size, width, mode)
					if measured["lines"] <= lines and measured["width"] <= width + 0.5:
						return {"fits": true, "size": font_size, "lines": measured["lines"], "mode": mode, "stretch": stretch}
	return {"fits": false, "size": NAME_MIN, "lines": NAME_LINES, "mode": TextServer.AUTOWRAP_ARBITRARY, "stretch": stretches.back()}


func _fit_name() -> void:
	var width: float = size.x - PAD_SIDE * 2.0
	var chosen: Dictionary = fit_name(_display_name, _language, width, _large_text)
	var font: Font = Fonts.label(_language, chosen["stretch"])
	name_fits = chosen["fits"]
	# 글꼴의 줄 상자는 글자 크기의 1.1배보다 높다. 배치는 1.1배로 하고 Label은 그 차이의 절반만큼 위로 당겨 놓는다.
	var font_size: int = chosen["size"]
	var lines: int = chosen["lines"]
	var line_box: float = font.get_height(font_size)
	var pitch: float = roundf(font_size * NAME_LINE_RATIO)
	_name_height = pitch * lines
	_name_trim = (line_box - pitch) / 2.0
	_label_height = line_box + pitch * (lines - 1)
	name_label.size.x = width
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", font_size)
	name_label.add_theme_constant_override("line_spacing", roundi(pitch - line_box))
	name_label.autowrap_mode = chosen["mode"]
	name_label.text = _display_name
	_arrange()


## 글자 크기와 줄바꿈 방식으로 이름을 놓았을 때의 줄 수와 가장 긴 줄의 폭.
static func _measure(display_name: String, font: Font, font_size: int, width: float, mode: int) -> Dictionary:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if mode == TextServer.AUTOWRAP_ARBITRARY else TextServer.BREAK_WORD_BOUND)
	paragraph.add_string(display_name, font, font_size)
	var widest: float = 0.0
	for line: int in paragraph.get_line_count():
		widest = maxf(widest, paragraph.get_line_width(line))
	return {"lines": paragraph.get_line_count(), "width": widest}
