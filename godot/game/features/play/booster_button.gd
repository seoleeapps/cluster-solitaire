extends TextureButton
## 부스터 버튼(힌트, 되돌리기): 원형 판과 아이콘, 오른쪽 위의 개수 배지, 아래 이름.
## 상태: ready(쓸 수 있음, 개수 배지), empty(0개, 배지 대신 더하기 표시), idle(지금은 쓸 데가 없음, 흐리게),
##   off(쓸 수 없음, 회색. 일일 도전과 튜토리얼). 강조하면 맥동한다.
## 누르는 영역은 버튼 전체(58×74)다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const READY := "ready"
const EMPTY := "empty"
const IDLE := "idle"
const OFF := "off"

const WIDTH := 58.0
const HEIGHT := 74.0
const DISC := 52.0
const RING := 3.0
const ICON := 28.0
const LABEL_TOP := 59.5
const BADGE := 20.0
const IDLE_ALPHA := 0.55

var count: int = 0
var state: String = READY

var _disc: TextureRect
var _icon: TextureRect
var _badge: TextureRect
var _badge_label: Label
var _plus: TextureRect
var _label: Label
var _plate_name: String = "booster_hint"
var _pulse: Tween
var _art: Control


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = Vector2(WIDTH, HEIGHT)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.size = Vector2(WIDTH, DISC + RING * 2.0)
	_art.pivot_offset = Vector2(WIDTH / 2.0, DISC / 2.0)
	add_child(_art)
	_disc = Art.picture(Art.play("booster_hint"))
	_disc.position = Vector2(0.0, -RING)
	_art.add_child(_disc)
	_icon = Art.picture(Art.play("icon_hint"), Vector2.ONE * ICON)
	_icon.position = Vector2((WIDTH - ICON) / 2.0, (DISC - ICON) / 2.0)
	_art.add_child(_icon)
	_badge = Art.picture(Art.play("badge"))
	_badge.position = Vector2(WIDTH + 1.0 - BADGE - 2.0, -4.0 - 2.0)
	_art.add_child(_badge)
	_badge_label = Fonts.text("0", Fonts.display(700), 12)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.size = _badge.size
	_badge.add_child(_badge_label)
	_plus = Art.picture(Art.play("plus_button"))
	_plus.position = _badge.position
	_plus.visible = false
	_art.add_child(_plus)
	_label = Fonts.text("", Fonts.label("en"), 12)
	Fonts.shade(_label)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-20.0, LABEL_TOP)
	_label.size = Vector2(WIDTH + 40.0, maxf(18.0, HEIGHT - LABEL_TOP))
	add_child(_label)
	button_down.connect(func() -> void: Juice.press_punch(_art, 0.92, 0.12))


## 판(booster_hint, booster_undo)과 아이콘, 이름을 정한다.
func configure(plate: String, icon: String, text: String, language: String, text_size: int) -> void:
	_plate_name = plate
	_icon.texture = Art.play(icon)
	_label.text = text
	_label.add_theme_font_override("font", Fonts.label(language))
	_label.add_theme_font_size_override("font_size", text_size)
	_refresh()


## 보유 수와 상태를 보인다.
func show_state(next: String, owned: int) -> void:
	state = next
	count = owned
	_refresh()


func label_text() -> String:
	return _label.text


## 막힌 길에서 눈에 띄게 맥동한다(2초 주기로 4% 커졌다 돌아온다).
func set_highlight(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
		_pulse = null
	_art.scale = Vector2.ONE
	if on and not Juice.reduced_motion and is_inside_tree():
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_art, "scale", Vector2.ONE * 1.08, 0.5).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_art, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func highlighted() -> bool:
	return _pulse != null and _pulse.is_valid()


## 쓸 데가 없을 때 누르면 고개를 젓는다.
func refuse() -> void:
	Juice.shake(_art, 4.0, 0.18)


func _refresh() -> void:
	_disc.texture = Art.play("booster_disabled" if state == OFF else _plate_name)
	_badge.visible = state != OFF and count > 0
	_badge_label.text = str(mini(count, 99))
	_plus.visible = state != OFF and count <= 0
	modulate.a = IDLE_ALPHA if state == IDLE else 1.0
	_label.modulate.a = 0.7 if state == OFF else 1.0
