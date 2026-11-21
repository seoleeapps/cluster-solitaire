extends Control
## 임시 칸이나 예비 카드 자리 하나.
## 상태: 빈 칸(empty), 놓을 수 있음(target: 초록 점선과 맥동), 잠김(locked: 금색 테, 자물쇠, 얻는 방법 꼬리표), 카드 있음(filled).
## 잠긴 칸의 꼬리표(tag)는 보유분(owned), 광고(ad), 코인 가격(coins) 가운데 하나다.

signal pressed(cell: Control)

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const EMPTY := "empty"
const TARGET := "target"
const LOCKED := "locked"
const FILLED := "filled"
const TAG_OWNED := "owned"
const TAG_AD := "ad"
const TAG_COINS := "coins"

const PLATE_MARGINS := [20, 20, 20, 20]
const TARGET_MARGINS := [22, 22, 22, 22]
const TAG_MARGINS := [10, 9, 10, 11]
const LOCK_SIZE := 28.0
const GAP := 4.0

var state: String = EMPTY
var tag: String = ""
var index: int = 0
## 누를 수 있는지 묻는 함수. 비어 있으면 늘 누를 수 있다.
var gate: Callable

var _plate: NinePatchRect
var _lock: VBoxContainer
var _caption: Label
var _tag_plate: NinePatchRect
var _tag_row: HBoxContainer
var _tag_icon: TextureRect
var _tag_label: Label
var _pulse: Tween
var _attention: Tween
var _tag_box: Control
var _pressing: bool = false


func _init() -> void:
	_plate = Art.plate(Art.play("cell_empty"), PLATE_MARGINS)
	add_child(_plate)
	_lock = VBoxContainer.new()
	_lock.alignment = BoxContainer.ALIGNMENT_CENTER
	_lock.add_theme_constant_override("separation", int(GAP))
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.visible = false
	add_child(_lock)
	var icon: TextureRect = Art.picture(Art.play("icon_lock"), Vector2.ONE * LOCK_SIZE)
	icon.custom_minimum_size = Vector2.ONE * LOCK_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lock.add_child(icon)
	_caption = Fonts.text("", Fonts.display(700), 11)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock.add_child(_caption)
	_tag_box = Control.new()
	_tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_box.custom_minimum_size = Vector2(0, 21)
	_lock.add_child(_tag_box)
	_tag_box.resized.connect(_arrange_tag)
	_tag_plate = Art.plate(Art.play("ad_tag"), TAG_MARGINS)
	_tag_box.add_child(_tag_plate)
	_tag_row = HBoxContainer.new()
	_tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tag_row.add_theme_constant_override("separation", 3)
	_tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_box.add_child(_tag_row)
	_tag_icon = Art.picture(Art.play("icon_play_ad"), Vector2(9, 9))
	_tag_icon.custom_minimum_size = Vector2(9, 9)
	_tag_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag_row.add_child(_tag_icon)
	_tag_label = Fonts.text("", Fonts.display(700), 10)
	_tag_row.add_child(_tag_label)
	resized.connect(_arrange)


func _ready() -> void:
	_arrange()


## 상태를 바꾼다. 놓을 수 있는 칸은 맥동한다.
func set_state(next: String) -> void:
	if state == next:
		return
	state = next
	_plate.texture = Art.play({TARGET: "cell_target", LOCKED: "cell_locked"}.get(next, "cell_empty"))
	var margins: Array = TARGET_MARGINS if next == TARGET else PLATE_MARGINS
	_plate.patch_margin_left = margins[0]
	_plate.patch_margin_top = margins[1]
	_plate.patch_margin_right = margins[2]
	_plate.patch_margin_bottom = margins[3]
	var tiled: int = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT if next == TARGET else NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_plate.axis_stretch_horizontal = tiled
	_plate.axis_stretch_vertical = tiled
	_lock.visible = next == LOCKED
	mouse_filter = Control.MOUSE_FILTER_IGNORE if next == FILLED else Control.MOUSE_FILTER_STOP
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_plate.modulate.a = 1.0
	if next == TARGET and not Juice.reduced_motion and is_inside_tree():
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_plate, "modulate:a", 0.6, 0.4).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_plate, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)


## 잠긴 칸의 문구와 꼬리표를 정한다. kind는 owned, ad, coins이고 text는 꼬리표에 쓸 글자(보유 수, 광고, 가격)다.
func set_lock(caption: String, kind: String, text: String, coin: Texture2D) -> void:
	tag = kind
	_caption.text = caption
	_tag_label.text = text
	_tag_plate.visible = kind == TAG_AD
	_tag_icon.visible = kind != TAG_OWNED
	_tag_icon.texture = Art.play("icon_play_ad") if kind == TAG_AD else coin
	var icon_size: float = 9.0 if kind == TAG_AD else 14.0
	_tag_icon.custom_minimum_size = Vector2.ONE * icon_size
	_tag_label.add_theme_font_size_override("font_size", 10 if kind == TAG_AD else 12)
	_arrange_tag.call_deferred()


## 막힌 길에서 눈에 띄게 맥동한다.
func set_attention(on: bool) -> void:
	if _attention != null and _attention.is_valid():
		if on:
			return
		_attention.kill()
		_attention = null
	scale = Vector2.ONE
	if on and not Juice.reduced_motion and is_inside_tree():
		pivot_offset = size / 2.0
		_attention = create_tween().set_loops()
		_attention.tween_property(self, "scale", Vector2.ONE * 1.04, 0.5).set_trans(Tween.TRANS_SINE)
		_attention.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## 카드가 놓일 때 한 번 눌린다.
func bump() -> void:
	Juice.press_punch(_plate, 0.94, 0.12)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_pressing = not gate.is_valid() or gate.call(self)
	elif _pressing:
		_pressing = false
		if Rect2(Vector2.ZERO, size).grow(8.0).has_point(event.position):
			pressed.emit(self)


func _arrange() -> void:
	_plate.size = size
	_plate.pivot_offset = size / 2.0
	_lock.size = size
	_lock.position = Vector2(0, -2)
	_arrange_tag()


## 꼬리표 판은 글자 줄에 좌우 7의 여백을 두고 가운데에 놓는다.
func _arrange_tag() -> void:
	var row: Vector2 = _tag_row.get_combined_minimum_size()
	var plate_size := Vector2(row.x + 14.0, 21.0)
	_tag_plate.size = plate_size
	_tag_plate.position = Vector2((_tag_box.size.x - plate_size.x) / 2.0, 0.0)
	_tag_row.size = Vector2(plate_size.x, 19.0)
	_tag_row.position = _tag_plate.position
