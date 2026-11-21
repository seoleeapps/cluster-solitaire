extends Control
## 홈 가운데의 최소 구성: 다음에 풀 스테이지 번호와 모은 별. 시작은 바로 아래 공통 흐름의 주 버튼(play)이 맡는다.
## 스테이지 카드, 일일 도전, 도감·상점·출석 진입은 홈 화면 작업에서 채운다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")

var stage_number: int = 1
var total_stars: int = 0
var caption: String = "STAGE"


func _ready() -> void:
	name = "home_stage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var small: Label = Fonts.text(caption, Fonts.display(700), 20)
	Fonts.shade(small)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(small)
	var number: Label = Fonts.text(str(stage_number), Fonts.display(700), 96)
	number.name = "number"
	Fonts.shade(number, Color("4e54c8"), 5)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stars)
	var star: TextureRect = Art.picture(Art.play("star_full"), Vector2(26, 26))
	star.custom_minimum_size = Vector2(26, 26)
	stars.add_child(star)
	var count: Label = Fonts.text(str(total_stars), Fonts.display(700), 22)
	Fonts.shade(count)
	stars.add_child(count)
