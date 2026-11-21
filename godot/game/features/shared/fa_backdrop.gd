extends Control
## 캔디 팝 배경: 하늘색에서 파랑, 보라로 내려가는 세로 그라데이션과 천천히 떠다니는 흰 원 네 개.
## 움직임 줄이기에서는 원이 멈춘다. 입력은 받지 않는다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const TOP := Color("58c4ff")
const MIDDLE := Color("6e8cff")
const BOTTOM := Color("a56bff")
const MIDDLE_AT := 0.46
## 원: 화면 비율 위치(x, y), 반지름, 불투명도, 떠다니는 주기(초)와 움직이는 거리.
const BUBBLES: Array[Dictionary] = [
	{"at": Vector2(0.12, 0.18), "radius": 70.0, "alpha": 0.22, "period": 24.0, "drift": Vector2(10, 14)},
	{"at": Vector2(0.92, 0.30), "radius": 100.0, "alpha": 0.16, "period": 30.0, "drift": Vector2(-12, 10)},
	{"at": Vector2(0.20, 0.82), "radius": 120.0, "alpha": 0.13, "period": 27.0, "drift": Vector2(14, -10)},
	{"at": Vector2(0.85, 0.92), "radius": 60.0, "alpha": 0.18, "period": 21.0, "drift": Vector2(-8, -12)},
]

var _bubbles: Array[TextureRect] = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, MIDDLE_AT, 1.0])
	gradient.colors = PackedColorArray([TOP, MIDDLE, BOTTOM])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 512
	var sky := TextureRect.new()
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	for spec: Dictionary in BUBBLES:
		var bubble: TextureRect = Art.picture(Art.play("bubble"), Vector2.ONE * spec["radius"] * 2.0)
		bubble.modulate.a = spec["alpha"]
		add_child(bubble)
		_bubbles.append(bubble)
	resized.connect(_place)
	_place()


func _process(delta: float) -> void:
	if Juice.reduced_motion:
		return
	_time += delta
	_place()


func _place() -> void:
	for index: int in _bubbles.size():
		var spec: Dictionary = BUBBLES[index]
		var phase: float = _time / float(spec["period"]) * TAU
		var offset: Vector2 = Vector2(sin(phase), cos(phase * 0.8)) * (spec["drift"] as Vector2)
		_bubbles[index].position = Vector2(spec["at"]) * size - Vector2.ONE * float(spec["radius"]) + offset
