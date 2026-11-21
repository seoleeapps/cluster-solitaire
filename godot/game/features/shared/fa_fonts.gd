extends RefCounted
## 제품 화면의 서체. 제목과 버튼, 숫자는 Fredoka(라틴)와 Jua(한글)를 함께 쓰고 본문은 Noto Sans KR이다.

const FREDOKA := "res://addons/seorilabs_game/fonts/Fredoka.ttf"
const JUA := "res://addons/seorilabs_game/fonts/Jua.ttf"
const NOTO := "res://addons/seorilabs_game/fonts/NotoSansKR.ttf"

## 한글 서체 Jua는 굵기가 하나뿐이다. 굵은 제목 자리(600 이상)에서는 획을 살짝 불려 시안의 굵기에 맞춘다.
## 값은 글자 크기의 1/24만큼 두꺼워지는 양이다(브라우저가 굵기 없는 서체를 굵게 그릴 때와 같다).
const HANGUL_EMBOLDEN := 0.66
const BOLD_FROM := 600

const INK := Color("3a3470")
## 배경 위 흰 글자의 그림자(남보라, 아래로 2).
const SHADE := Color(0.165, 0.125, 0.47, 0.4)

static var _cache: Dictionary = {}


## 제목, 버튼, 숫자. 라틴 문자와 숫자는 Fredoka의 굵기 weight로, 한글은 Jua로 그린다.
static func display(weight: int = 700) -> Font:
	var key: String = "display:%d" % weight
	if not _cache.has(key):
		var font: FontVariation = _weighted(FREDOKA, weight)
		var hangul := FontVariation.new()
		hangul.base_font = load(JUA)
		hangul.variation_embolden = HANGUL_EMBOLDEN if weight >= BOLD_FROM else 0.0
		font.fallbacks = [hangul, load(NOTO)]
		_cache[key] = font
	return _cache[key]


## 카드와 범주 이름. 한국어는 Jua, 그 밖의 언어는 Fredoka 600이다.
## stretch는 Fredoka의 글자 폭(75~125, 기본 100)이다. 한 낱말이 카드 폭을 넘는 긴 영어 이름에만 좁은 폭을 쓴다.
static func label(language: String, stretch: int = 100) -> Font:
	var key: String = "label:%s:%d" % [language, stretch]
	if not _cache.has(key):
		var font := FontVariation.new()
		if language == "ko":
			font.base_font = load(JUA)
			font.fallbacks = [_weighted(FREDOKA, 600), load(NOTO)]
		else:
			font = _weighted(FREDOKA, 600)
			var axes: Dictionary = font.variation_opentype
			axes[TextServerManager.get_primary_interface().name_to_tag("wdth")] = stretch
			font.variation_opentype = axes
			font.fallbacks = [load(JUA), load(NOTO)]
		_cache[key] = font
	return _cache[key]


## 본문.
static func body(weight: int = 550) -> Font:
	var key: String = "body:%d" % weight
	if not _cache.has(key):
		_cache[key] = _weighted(NOTO, weight)
	return _cache[key]


## 글자 표시 하나. 입력은 받지 않고 외곽선이 없다.
static func text(value: String, font: Font, size: int, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 글자 아래에 번지지 않는 그림자를 둔다(배경 위 흰 글자, 주 버튼의 글자).
static func shade(node: Control, color: Color = SHADE, offset: int = 2) -> void:
	node.add_theme_color_override("font_shadow_color", color)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", offset)
	node.add_theme_constant_override("shadow_outline_size", 0)


static func _weighted(path: String, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font
