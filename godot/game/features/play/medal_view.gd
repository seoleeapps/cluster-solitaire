extends Control
## 완성 묶음 메달. 빈 원(물음표)이거나, 완성하면 흰 원에 아이콘 네 개와 산호색 이름표가 된다.
## 범주 이름은 완성 전까지 보이지 않는다. 완성 순서는 메달의 위치로 보인다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const Burst := preload("res://addons/seorilabs_game/ui_kit/particles/burst.tscn")

const ICON_DIR := "res://game/assets/icons/"
## 기준 크기(원 58)에서의 수치. 원이 작아지면 같은 비율로 줄인다.
const BASE_DISC := 58.0
const RING := 4.0
const LIP := 5.0
const ICON := 22.0
const ICON_GAP := 2.0
const TAG_OFFSET := 8.0
const TAG_HEIGHT := 18.0
const TAG_LIP := 2.0
const TAG_PAD := 10.0
const TAG_MARGINS := [9, 9, 9, 11]
const NAME_SIZE := 13
const NAME_MIN := 10
const BURST_COLOR := Color("ff8f6b")
const BURST_AMOUNT := 12

## 완성한 범주 id. 비어 있으면 빈 메달이다.
var category: String = ""

var _empty: TextureRect
var _question: Label
var _done: TextureRect
var _icons: Array[TextureRect] = []
var _tag: NinePatchRect
var _tag_label: Label
var _burst: CPUParticles2D
var _tag_room: Vector2 = Vector2(84.5, 18.0)
var _language: String = "en"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty = Art.picture(Art.play("medal_empty"))
	add_child(_empty)
	_question = Fonts.text("?", Fonts.display(700), 22, Color(1, 1, 1, 0.85))
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_question)
	_done = Art.picture(Art.play("medal_done"))
	_done.visible = false
	add_child(_done)
	for index: int in 4:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		add_child(icon)
		_icons.append(icon)
	_tag = Art.plate(Art.play("name_tag"), TAG_MARGINS)
	_tag.visible = false
	add_child(_tag)
	_tag_label = Fonts.text("", Fonts.label("en"), NAME_SIZE)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_label.add_theme_constant_override("line_spacing", -3)
	_tag.add_child(_tag_label)
	_burst = Burst.instantiate()
	_burst.amount = BURST_AMOUNT
	_burst.color = BURST_COLOR
	_burst.lifetime = 0.5
	_burst.initial_velocity_min = 90.0
	_burst.initial_velocity_max = 190.0
	add_child(_burst)
	resized.connect(_arrange)


## 원의 크기(size)와 이름표가 쓸 수 있는 폭과 높이를 정한다.
func configure(disc: float, tag_room: Vector2, language: String) -> void:
	_tag_room = tag_room
	_language = language
	size = Vector2.ONE * disc
	_arrange()


## 완성한 범주를 보인다. icons는 그 묶음 카드 네 장의 아이콘 열쇠다. animate면 튀어나오며 입자가 터진다.
func complete(id: String, display_name: String, icons: Array, animate: bool) -> void:
	category = id
	_empty.visible = false
	_question.visible = false
	_done.visible = true
	for index: int in _icons.size():
		_icons[index].visible = index < icons.size()
		if index < icons.size():
			_icons[index].texture = load(ICON_DIR + str(icons[index]) + ".png")
	_tag.visible = true
	_fit_tag(display_name)
	if not animate or Juice.reduced_motion or not is_inside_tree():
		return
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.6
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_burst.position = size / 2.0
	_burst.restart()
	# 이름표는 위에서 내려온다.
	var rest: float = _tag.position.y
	_tag.position.y = rest - 10.0
	_tag.modulate.a = 0.0
	var drop: Tween = create_tween().set_parallel(true)
	drop.tween_property(_tag, "position:y", rest, 0.18).set_delay(0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	drop.tween_property(_tag, "modulate:a", 1.0, 0.12).set_delay(0.12)


func clear() -> void:
	category = ""
	_empty.visible = true
	_question.visible = true
	_done.visible = false
	_tag.visible = false
	for icon: TextureRect in _icons:
		icon.visible = false


func tag_text() -> String:
	return _tag_label.text


func _arrange() -> void:
	var ratio: float = size.x / BASE_DISC
	_empty.size = size
	_question.size = size
	_question.add_theme_font_size_override("font_size", roundi(22.0 * ratio))
	_done.position = -Vector2.ONE * RING * ratio
	_done.size = size + Vector2(RING * 2.0, RING * 2.0 + LIP) * ratio
	var icon: float = ICON * ratio
	var gap: float = ICON_GAP * ratio
	var origin: Vector2 = (size - Vector2.ONE * (icon * 2.0 + gap)) / 2.0
	for index: int in _icons.size():
		_icons[index].size = Vector2.ONE * icon
		_icons[index].position = origin + Vector2(index % 2, floori(index / 2.0)) * (icon + gap)
	_place_tag()


## 이름표를 원 아래 가운데에 둔다.
func _place_tag() -> void:
	_tag.position = Vector2((size.x - _tag.size.x) / 2.0, size.y + TAG_OFFSET)
	_tag_label.position = Vector2.ZERO
	_tag_label.size = _tag.size - Vector2(0.0, TAG_LIP)


## 이름을 한 줄에 넣고, 넘치면 글자를 줄이고, 그래도 넘치면 두 줄로 나눈다.
func _fit_tag(display_name: String) -> void:
	var font: Font = Fonts.label(_language)
	var room: float = _tag_room.x - TAG_PAD * 2.0
	_tag_label.add_theme_font_override("font", font)
	_tag_label.text = display_name
	_tag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font_size: int = NAME_SIZE
	var width: float = font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width > room and font_size > NAME_MIN + 1:
		font_size -= 1
		width = font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var height: float = TAG_HEIGHT
	if width > room:
		# 두 줄: 높이는 이름표가 쓸 수 있는 만큼만 쓴다.
		font_size = NAME_MIN + 1
		var paragraph := TextParagraph.new()
		paragraph.width = room
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		paragraph.add_string(display_name, font, font_size)
		if paragraph.get_line_count() > 2:
			font_size = NAME_MIN
		_tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		width = room
		height = minf(_tag_room.y, font.get_height(font_size) * 2.0 - 3.0 + 2.0)
	_tag_label.add_theme_font_size_override("font_size", font_size)
	_tag.size = Vector2(ceilf(width) + TAG_PAD * 2.0, height + TAG_LIP)
	_place_tag()
